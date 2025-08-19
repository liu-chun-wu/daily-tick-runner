import type { APIRequestContext } from '@playwright/test';
import fs from 'node:fs/promises';

/** LINE Messaging API: 推送文字訊息（最穩） */
export async function notifyLinePush(request: APIRequestContext, content: string) {
    const token = process.env.LINE_CHANNEL_ACCESS_TOKEN;
    const to = process.env.LINE_USER_ID; // 也可放 groupId/roomId
    if (!token || !to) return;

    await request.post('https://api.line.me/v2/bot/message/push', {
        headers: {
            Authorization: `Bearer ${token}`,
            'Content-Type': 'application/json'
        },
        data: {
            to,
            messages: [{ type: 'text', text: content }]
        }
    });
}
