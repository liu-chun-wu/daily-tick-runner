// automation/notify/line.ts
import fs from 'node:fs/promises';
import { env } from '../../config/env';
import { uploadImageToDiscord } from './discord';
import { log } from '../utils/logger';
import type { NotifyOpts } from './types';

/**
 * LINE Messaging API: 發送推送訊息（支援文字和圖片）
 * 使用 Discord 作為圖片的臨時儲存空間
 */
export async function notifyLine(opts: NotifyOpts) {
    const token = env.lineChannelAccessToken;
    const to = env.lineUserId;
    if (!token || !to) {
        log.warn('LINE', 'LINE 相關環境變數未設定，跳過通知');
        return;
    }

    const url = 'https://api.line.me/v2/bot/message/push';
    const hasImage = !!(opts.screenshotBuffer || opts.screenshotPath);
    log.notifyStart('LINE', 'LINE', hasImage);

    try {
        // 1) 先送文字訊息（就算圖片失敗至少有訊息）
        const response = await fetch(url, {
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

        // 檢查是否月額度已用完
        if (response.status === 429) {
            const errorText = await response.text();
            log.warn('LINE', `LINE API 月額度已用完: ${errorText}`);
            
            // Fallback 到 Discord
            if (env.discordWebhookUrl) {
                log.info('LINE', 'Fallback 到 Discord 通知...');
                
                // 準備 Discord 訊息
                const discordMessage = [
                    '⚠️ **LINE API 月額度已用完，訊息轉發至 Discord**',
                    '',
                    '📨 原始訊息:',
                    opts.message,
                    '',
                    `⏰ 時間: ${new Date().toLocaleString('zh-TW', { timeZone: 'Asia/Taipei' })}`,
                    '💡 提示: 請檢查 LINE Developer Console 或等待下個月額度重置'
                ].join('\n');
                
                // 使用 Discord 發送
                const { notifyDiscord } = await import('./discord');
                await notifyDiscord({
                    ...opts,
                    message: discordMessage
                });
                
                log.info('LINE', '已透過 Discord 發送通知');
            } else {
                log.warn('LINE', 'Discord Webhook 未設定，無法進行 fallback');
            }
            
            // 不拋出錯誤，讓流程繼續
            return;
        }

        // 檢查其他錯誤
        if (!response.ok) {
            const errorText = await response.text();
            log.warn('LINE', `LINE API 錯誤 (${response.status}): ${errorText}`);
        }

        // 2) 如果已有圖片 URL，直接使用
        if (opts.imageUrl) {
            log.info('LINE', '使用已有的圖片 URL，正在發送 LINE 圖片訊息...');
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
                        originalContentUrl: opts.imageUrl,
                        previewImageUrl: opts.imageUrl
                    }]
                })
            });
            log.info('LINE', 'LINE 圖片訊息發送成功');
            log.notifySuccess('LINE', 'LINE');
            return;
        }

        // 3) 處理圖片上傳（如果有圖片但沒有 URL）
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
                    log.warn('LINE', 'readFile failed', e);
                }
            }

            if (imageBuffer) {
                try {
                    log.info('LINE', '正在上傳圖片到 Discord...');
                    // 上傳到 Discord 取得 CDN 連結（純上傳，不發送訊息）
                    const imageUrl = await uploadImageToDiscord(
                        env.discordWebhookUrl,
                        imageBuffer,
                        opts.filename || 'screenshot.png'
                    );
                    
                    log.info('LINE', '圖片上傳成功，正在發送 LINE 圖片訊息...');
                    // 用 LINE 發 image（兩個 URL 都要是 HTTPS）
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
                    
                    log.info('LINE', 'LINE 圖片訊息發送成功');
                } catch (e) {
                    log.warn('LINE', '圖片上傳或發送失敗，僅發送文字訊息', e);
                }
            }
        } else if (hasBuffer || hasPath) {
            log.warn('LINE', '需要 Discord Webhook URL 才能發送圖片');
        }

        log.notifySuccess('LINE', 'LINE');
    } catch (err) {
        // 外部整合失敗不應讓測試掛掉
        log.notifyFailed('LINE', 'LINE', err as Error);
    }
}

/**
 * 相容舊版函數名稱
 * @deprecated 請使用 notifyLine
 */
export const notifyLinePush = notifyLine;