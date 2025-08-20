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

        await test.step('expect 200', async () => {
            expect(res.status(), await res.text()).toBe(200);
        });
    });
});
