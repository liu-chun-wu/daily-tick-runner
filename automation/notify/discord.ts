// automation/notify/discord.ts
import fs from 'node:fs/promises';
import path from 'node:path';
import { request, FormData } from 'undici';
import { env } from '../../config/env';

type NotifyOpts = {
    message: string;
    filename?: string;
    screenshotBuffer?: Buffer;
    screenshotPath?: string; // 後備：從檔案讀
};

export async function notifyDiscord(opts: NotifyOpts) {
    const url = env.discordWebhookUrl;
    if (!url) return;

    const payload = { content: opts.message };

    try {
        const hasBuffer = !!opts.screenshotBuffer;
        const hasPath = !!opts.screenshotPath;

        if (hasBuffer || hasPath) {
            const form = new FormData();
            form.append('payload_json', JSON.stringify(payload));

            const name =
                opts.filename ??
                (hasPath ? path.basename(opts.screenshotPath!) : 'screenshot.png');

            let data: Buffer | null = null;
            if (hasBuffer) {
                data = opts.screenshotBuffer!;
            } else if (hasPath) {
                try {
                    data = await fs.readFile(opts.screenshotPath!);
                } catch (e) {
                    console.warn('[notifyDiscord] readFile failed; fallback to text-only:', (e as Error).message);
                }
            }

            if (data) {
                // 使用 Blob 替代 File (Node.js 18+ 內建支援)
                // 將 Buffer 轉換為 Uint8Array 以符合 BlobPart 類型
                const blob = new Blob([new Uint8Array(data)], { type: 'image/png' });
                form.append('files[0]', blob, name);
                await request(url, { method: 'POST', body: form });
                return; // 成功送出就結束
            }
        }

        // 沒圖或讀檔失敗 → 純文字，不阻斷 smoke
        await request(url, {
            method: 'POST',
            headers: { 'content-type': 'application/json' },
            body: JSON.stringify(payload),
        });
    } catch (err) {
        // 外部整合失敗不應讓 smoke 掛掉
        console.warn('[notifyDiscord] webhook send failed (non-blocking):', (err as Error).message);
    }
}
