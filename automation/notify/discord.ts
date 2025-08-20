// automation/notify/discord.ts
import fs from 'node:fs/promises';
import path from 'node:path';
import { request, FormData } from 'undici';
import { env } from '../../config/env';
import { log } from '../utils/logger';
import type { NotifyOpts } from './types';

/**
 * 上傳圖片到 Discord 並取得 CDN URL（約 24小時有效）
 */
export async function uploadToDiscordAndGetUrl(
    webhookUrl: string,
    imageBuffer: Buffer,
    filename = 'screenshot.png',
    content = 'Smoke 截圖'
): Promise<string> {
    const url = webhookUrl.includes('?') ? `${webhookUrl}&wait=true` : `${webhookUrl}?wait=true`;

    const form = new FormData();
    // payload_json 可同時帶文字等欄位
    form.append(
        'payload_json',
        JSON.stringify({
            content,
            // 附件宣告（對應 files[0]）
            attachments: [{ id: 0, filename }],
        })
    );
    // 對應上面 attachments.id
    const blob = new Blob([new Uint8Array(imageBuffer)], { type: 'image/png' });
    // 參數名稱慣例：files[0]
    form.append('files[0]', blob, filename);

    const res = await request(url, { method: 'POST', body: form });
    if (res.statusCode !== 200) {
        throw new Error(`Discord upload failed: ${res.statusCode}`);
    }
    const msg = await res.body.json() as {
        attachments?: Array<{ url: string }>;
    };

    const cdnUrl = msg.attachments?.[0]?.url;
    if (!cdnUrl) throw new Error('No attachment url returned from Discord');
    return cdnUrl; // 這是簽名 CDN 連結（~24h 有效）
}

export async function notifyDiscord(opts: NotifyOpts) {
    const url = env.discordWebhookUrl;
    if (!url) {
        log.warn('Discord', 'Discord Webhook URL 未設定，跳過通知');
        return;
    }

    const payload = { content: opts.message };
    const hasImage = !!(opts.screenshotBuffer || opts.screenshotPath);
    log.notifyStart('Discord', 'Discord', hasImage);

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
                    log.warn('Discord', 'readFile failed; fallback to text-only', e);
                }
            }

            if (data) {
                // 使用 Blob 替代 File (Node.js 18+ 內建支援)
                // 將 Buffer 轉換為 Uint8Array 以符合 BlobPart 類型
                const blob = new Blob([new Uint8Array(data)], { type: 'image/png' });
                form.append('files[0]', blob, name);
                await request(url, { method: 'POST', body: form });
                log.notifySuccess('Discord', 'Discord');
                return; // 成功送出就結束
            }
        }

        // 沒圖或讀檔失敗 → 純文字，不阻斷 smoke
        await request(url, {
            method: 'POST',
            headers: { 'content-type': 'application/json' },
            body: JSON.stringify(payload),
        });
        log.notifySuccess('Discord', 'Discord');
    } catch (err) {
        // 外部整合失敗不應讓 smoke 掛掉
        log.notifyFailed('Discord', 'Discord', err as Error);
    }
}