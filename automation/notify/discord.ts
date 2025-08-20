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
 * 上傳圖片到 Discord 並取得 CDN URL（約 24小時有效）
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

    const payload = { content: opts.message };
    const hasImage = !!(opts.screenshotBuffer || opts.screenshotPath);
    log.notifyStart('Discord', 'Discord', hasImage);

    try {
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