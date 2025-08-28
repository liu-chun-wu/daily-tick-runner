import { test, expect } from '@playwright/test';
import { env } from '../../config/env';

test.describe('LINE Messaging API push @notify', () => {
    const missing = !env.lineChannelAccessToken || !env.lineUserId;
    test.skip(missing, 'Set LINE_CHANNEL_ACCESS_TOKEN and LINE_USER_ID');

    test('push text message', async ({ request }) => {
        const token = env.lineChannelAccessToken!;
        const to = env.lineUserId!;
        const text = `🧪 LINE 通知測試 ${new Date().toLocaleString('zh-TW', { timeZone: 'Asia/Taipei' })}`;

        const res = await test.step('POST /v2/bot/message/push', async () => {
            return request.post('https://api.line.me/v2/bot/message/push', {
                headers: {
                    Authorization: `Bearer ${token}`,
                    'Content-Type': 'application/json'
                },
                data: { to, messages: [{ type: 'text', text }] }
            });
        });

        await test.step('validate response', async () => {
            const responseText = await res.text();
            const status = res.status();
            
            // 處理月額度用完的情況
            if (status === 429) {
                console.warn('⚠️ LINE API monthly limit reached:', responseText);
                
                // 發送通知到 Discord
                if (env.discordWebhookUrl) {
                    const alertMessage = [
                        '⚠️ **LINE API 月額度已用完**',
                        `時間: ${new Date().toLocaleString('zh-TW', { timeZone: 'Asia/Taipei' })}`,
                        '錯誤訊息: ' + responseText,
                        '請檢查 LINE Developer Console 或等待下個月額度重置'
                    ].join('\n');
                    
                    try {
                        await request.post(env.discordWebhookUrl, {
                            data: { content: alertMessage }
                        });
                        console.log('✅ Discord notification sent for LINE quota exceeded');
                    } catch (e) {
                        console.error('Failed to send Discord notification:', e);
                    }
                }
                
                // 跳過測試而不是失敗
                test.skip(true, 'LINE API monthly quota exceeded - skipping test');
                return;
            }
            
            // 正常情況期待 200
            expect(status, responseText).toBe(200);
        });
    });
});
