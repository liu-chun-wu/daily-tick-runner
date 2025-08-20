// automation/notify/discord.ts
import fs from 'node:fs/promises';
import path from 'node:path';
import https from 'node:https';
import { URL } from 'node:url';
import { env } from '../../config/env';
import { log } from '../utils/logger';
import type { NotifyOpts } from './types';

/**
 * Helper function to make HTTP requests using Node.js built-in modules
 */
function makeRequest(url: string, options: {
    method: string;
    headers?: Record<string, string>;
    body?: Buffer | string
}): Promise<{ status: number; data: any }> {
    return new Promise((resolve, reject) => {
        const urlObj = new URL(url);
        const requestOptions = {
            hostname: urlObj.hostname,
            port: urlObj.port || 443,
            path: urlObj.pathname + urlObj.search,
            method: options.method,
            headers: options.headers || {},
        };

        const req = https.request(requestOptions, (res) => {
            let data = '';
            res.on('data', (chunk) => {
                data += chunk;
            });
            res.on('end', () => {
                try {
                    const jsonData = res.headers['content-type']?.includes('application/json')
                        ? JSON.parse(data)
                        : data;
                    resolve({ status: res.statusCode || 0, data: jsonData });
                } catch (err) {
                    resolve({ status: res.statusCode || 0, data });
                }
            });
        });

        req.on('error', (err) => {
            reject(err);
        });

        if (options.body) {
            req.write(options.body);
        }
        req.end();
    });
}

/**
 * 純圖片上傳到 Discord，不發送訊息內容，僅返回 CDN URL
 * 專用於其他通知服務（如 LINE）需要圖片 URL 的場景
 */
export async function uploadImageToDiscord(
    webhookUrl: string,
    imageBuffer: Buffer,
    filename = 'screenshot.png'
): Promise<string> {
    const url = webhookUrl.includes('?') ? `${webhookUrl}&wait=true` : `${webhookUrl}?wait=true`;
    const boundary = `----formdata-undici-${Math.random().toString(16)}`;

    // 只上傳圖片，不包含任何訊息內容
    const chunks: string[] = [];
    chunks.push(`--${boundary}\r\n`);
    chunks.push(`Content-Disposition: form-data; name="files[0]"; filename="${filename}"\r\n`);
    chunks.push('Content-Type: image/png\r\n\r\n');

    const formData = Buffer.concat([
        Buffer.from(chunks.join('')),
        imageBuffer,
        Buffer.from(`\r\n--${boundary}--\r\n`)
    ]);

    const res = await makeRequest(url, {
        method: 'POST',
        headers: {
            'Content-Type': `multipart/form-data; boundary=${boundary}`,
        },
        body: formData,
    });

    if (res.status !== 200) {
        throw new Error(`Discord image upload failed: ${res.status}`);
    }
    const msg = res.data as {
        attachments?: Array<{ url: string }>;
    };

    const cdnUrl = msg.attachments?.[0]?.url;
    if (!cdnUrl) throw new Error('No attachment url returned from Discord');
    return cdnUrl;
}

/**
 * 上傳圖片到 Discord 並取得 CDN URL（約 24小時有效）
 * 包含訊息內容的完整上傳功能
 */
export async function uploadToDiscordAndGetUrl(
    webhookUrl: string,
    imageBuffer: Buffer,
    filename = 'screenshot.png',
    content = 'Smoke 截圖'
): Promise<string> {
    const url = webhookUrl.includes('?') ? `${webhookUrl}&wait=true` : `${webhookUrl}?wait=true`;

    const boundary = `----formdata-undici-${Math.random().toString(16)}`;
    const payload = JSON.stringify({
        content,
        attachments: [{ id: 0, filename }],
    });

    // Build multipart form data manually
    const chunks: string[] = [];
    chunks.push(`--${boundary}\r\n`);
    chunks.push('Content-Disposition: form-data; name="payload_json"\r\n\r\n');
    chunks.push(payload);
    chunks.push('\r\n');

    chunks.push(`--${boundary}\r\n`);
    chunks.push(`Content-Disposition: form-data; name="files[0]"; filename="${filename}"\r\n`);
    chunks.push('Content-Type: image/png\r\n\r\n');

    const formData = Buffer.concat([
        Buffer.from(chunks.join('')),
        imageBuffer,
        Buffer.from(`\r\n--${boundary}--\r\n`)
    ]);

    const res = await makeRequest(url, {
        method: 'POST',
        headers: {
            'Content-Type': `multipart/form-data; boundary=${boundary}`,
        },
        body: formData,
    });

    if (res.status !== 200) {
        throw new Error(`Discord upload failed: ${res.status}`);
    }
    const msg = res.data as {
        attachments?: Array<{ url: string }>;
    };

    const cdnUrl = msg.attachments?.[0]?.url;
    if (!cdnUrl) throw new Error('No attachment url returned from Discord');
    return cdnUrl;
}

export async function notifyDiscord(opts: NotifyOpts) {
    const url = env.discordWebhookUrl;
    if (!url) {
        log.warn('Discord', 'Discord Webhook URL 未設定，跳過通知');
        return;
    }

    // 如果已有圖片 URL，直接在訊息中包含連結
    const message = opts.imageUrl
        ? `${opts.message}\n${opts.imageUrl}`
        : opts.message;

    const payload = { content: message };
    const hasImage = !!(opts.imageUrl || opts.screenshotBuffer || opts.screenshotPath);
    log.notifyStart('Discord', 'Discord', hasImage);

    try {
        // 如果已有 imageUrl，只發送文字訊息（包含圖片連結）
        if (opts.imageUrl) {
            await makeRequest(url, {
                method: 'POST',
                headers: { 'content-type': 'application/json' },
                body: JSON.stringify(payload),
            });
            log.notifySuccess('Discord', 'Discord');
            return;
        }

        // 以下是原有的邏輯（當沒有 imageUrl 時）
        const hasBuffer = !!opts.screenshotBuffer;
        const hasPath = !!opts.screenshotPath;

        if (hasBuffer || hasPath) {
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
                const boundary = `----formdata-undici-${Math.random().toString(16)}`;

                // Build multipart form data manually
                const chunks: string[] = [];
                chunks.push(`--${boundary}\r\n`);
                chunks.push('Content-Disposition: form-data; name="payload_json"\r\n\r\n');
                chunks.push(JSON.stringify(payload));
                chunks.push('\r\n');

                chunks.push(`--${boundary}\r\n`);
                chunks.push(`Content-Disposition: form-data; name="files[0]"; filename="${name}"\r\n`);
                chunks.push('Content-Type: image/png\r\n\r\n');

                const formData = Buffer.concat([
                    Buffer.from(chunks.join('')),
                    data,
                    Buffer.from(`\r\n--${boundary}--\r\n`)
                ]);

                await makeRequest(url, {
                    method: 'POST',
                    headers: {
                        'Content-Type': `multipart/form-data; boundary=${boundary}`,
                    },
                    body: formData,
                });
                log.notifySuccess('Discord', 'Discord');
                return; // 成功送出就結束
            }
        }

        // 沒圖或讀檔失敗 → 純文字，不阻斷 smoke
        await makeRequest(url, {
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