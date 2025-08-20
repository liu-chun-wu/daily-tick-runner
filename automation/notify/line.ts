// automation/notify/line.ts
import fs from 'node:fs/promises';
import { env } from '../../config/env';
import { uploadToDiscordAndGetUrl } from './discord';
import type { NotifyOpts } from './types';

/**
 * LINE Messaging API: 發送推送訊息（支援文字和圖片）
 * 使用 Discord 作為圖片的臨時儲存空間
 */
export async function notifyLine(opts: NotifyOpts) {
    const token = env.lineChannelAccessToken;
    const to = env.lineUserId;
    if (!token || !to) return;

    const url = 'https://api.line.me/v2/bot/message/push';

    try {
        // 1) 先送文字訊息（就算圖片失敗至少有訊息）
        await fetch(url, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                to,
                messages: [{
                    type: 'text',
                    text: opts.message
                }]
            })
        });

        // 2) 處理圖片上傳（如果有圖片）
        const hasBuffer = !!opts.screenshotBuffer;
        const hasPath = !!opts.screenshotPath;

        if ((hasBuffer || hasPath) && env.discordWebhookUrl) {
            let imageBuffer: Buffer | null = null;
            
            if (hasBuffer) {
                imageBuffer = opts.screenshotBuffer!;
            } else if (hasPath) {
                try {
                    imageBuffer = await fs.readFile(opts.screenshotPath!);
                } catch (e) {
                    console.warn('[notifyLine] readFile failed:', (e as Error).message);
                }
            }

            if (imageBuffer) {
                try {
                    console.log('[notifyLine] 正在上傳圖片到 Discord...');
                    // 3) 上傳到 Discord 取得 CDN 連結
                    const imageUrl = await uploadToDiscordAndGetUrl(
                        env.discordWebhookUrl,
                        imageBuffer,
                        opts.filename || 'screenshot.png',
                        opts.message
                    );
                    
                    console.log('[notifyLine] 圖片上傳成功，正在發送 LINE 圖片訊息...');
                    // 4) 用 LINE 發 image（兩個 URL 都要是 HTTPS）
                    await fetch(url, {
                        method: 'POST',
                        headers: {
                            'Authorization': `Bearer ${token}`,
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({
                            to,
                            messages: [{
                                type: 'image',
                                originalContentUrl: imageUrl,
                                previewImageUrl: imageUrl
                            }]
                        })
                    });
                    
                    console.log('[notifyLine] LINE 圖片訊息發送成功');
                } catch (e) {
                    console.warn('[notifyLine] 圖片上傳或發送失敗，僅發送文字訊息:', (e as Error).message);
                }
            }
        } else if (hasBuffer || hasPath) {
            console.warn('[notifyLine] 需要 Discord Webhook URL 才能發送圖片');
        }

        console.log('[notifyLine] 文字訊息發送成功');
    } catch (err) {
        // 外部整合失敗不應讓測試掛掉
        console.warn('[notifyLine] message push failed (non-blocking):', (err as Error).message);
    }
}

/**
 * 相容舊版函數名稱
 * @deprecated 請使用 notifyLine
 */
export const notifyLinePush = notifyLine;