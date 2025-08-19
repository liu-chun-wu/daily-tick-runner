import { test, expect } from '@playwright/test';

test.describe('LINE Messaging API push @notify', () => {
    const missing = !process.env.LINE_CHANNEL_ACCESS_TOKEN || !process.env.LINE_USER_ID;
    test.skip(missing, 'Set LINE_CHANNEL_ACCESS_TOKEN and LINE_USER_ID');

    test('push text message', async ({ request }) => {
        const token = process.env.LINE_CHANNEL_ACCESS_TOKEN!;
        const to = process.env.LINE_USER_ID!;
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

        await test.step('expect 200', async () => {
            expect(res.status(), await res.text()).toBe(200);
        });
    });
});
