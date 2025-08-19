import type { APIRequestContext } from '@playwright/test';
import fs from 'node:fs/promises';

/** Discord: 純文字或夾帶圖片（multipart/form-data） */
export async function notifyDiscord(
    request: APIRequestContext,
    content: string,
    screenshotPath?: string
) {
    const url = process.env.DISCORD_WEBHOOK_URL;
    if (!url) return;

    if (screenshotPath) {
        const buffer = await fs.readFile(screenshotPath);
        await request.post(url, {
            multipart: {
                // Discord 要用 payload_json + files[n]
                payload_json: JSON.stringify({ content }),
                'files[0]': { name: 'checkin.png', mimeType: 'image/png', buffer }
            }
        });
    } else {
        await request.post(url, {
            headers: { 'Content-Type': 'application/json' },
            data: { content }
        });
    }
}