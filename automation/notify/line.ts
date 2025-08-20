// automation/notify/line.ts
import { request } from 'undici';
import { env } from '../../config/env';
import type { NotifyOpts } from './types';

/**
 * LINE Messaging API: 發送推送訊息（支援文字和圖片）
 * 使用 Push Message API 發送訊息給特定用戶
 */
export async function notifyLine(opts: NotifyOpts) {
    const token = env.lineChannelAccessToken;
    const to = env.lineUserId;
    if (!token || !to) return;

    const url = 'https://api.line.me/v2/bot/message/push';

    try {
        const messages: any[] = [];
        
        // 加入文字訊息
        messages.push({
            type: 'text',
            text: opts.message
        });

        // 如果有圖片，加入圖片訊息
        const hasBuffer = !!opts.screenshotBuffer;
        const hasPath = !!opts.screenshotPath;

        if (hasBuffer || hasPath) {
            // LINE Messaging API 需要圖片的公開 URL
            // 這裡可以選擇：
            // 1. 上傳到圖床服務獲得 URL
            // 2. 使用 LINE Upload API（需要額外實作）
            // 3. 暫時只發送文字訊息
            
            console.warn('[notifyLine] LINE Messaging API 需要圖片 URL，目前暫不支援直接發送圖片 Buffer');
            // 未來可實作上傳圖片到 LINE 的功能
        }

        // 發送訊息
        await request(url, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                to,
                messages
            })
        });
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