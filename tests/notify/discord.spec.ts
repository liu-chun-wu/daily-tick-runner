import { test, expect } from '@playwright/test';
import fs from 'node:fs/promises';

test.describe('Discord webhook smoke @notify', () => {
    test.skip(!process.env.DISCORD_WEBHOOK_URL, 'Set DISCORD_WEBHOOK_URL');

    test('text-only webhook message', async ({ request }) => {
        const base = process.env.DISCORD_WEBHOOK_URL!;
        const url = base.includes('?') ? `${base}&wait=true` : `${base}?wait=true`; // 拿到 200 + message 物件
        const content = `🧪 Discord 通知測試 ${new Date().toLocaleString('zh-TW', { timeZone: 'Asia/Taipei' })}`;

        const res = await test.step('POST JSON to webhook', async () => {
            return request.post(url, {
                headers: { 'Content-Type': 'application/json' },
                data: { content }
            });
        });

        await test.step('expect 2xx', async () => {
            expect(res.ok()).toBeTruthy(); // wait=true 時一般為 200；未加 wait 會是 204 也屬成功
        });
    });

    test('optional: webhook with image (multipart)', async ({ request }) => {
        test.skip(!process.env.NOTIFY_TEST_IMAGE, 'Set NOTIFY_TEST_IMAGE to send a file');
        const base = process.env.DISCORD_WEBHOOK_URL!;
        const url = base.includes('?') ? `${base}&wait=true` : `${base}?wait=true`;
        const buffer = await fs.readFile(process.env.NOTIFY_TEST_IMAGE!);
        const content = `🧪 Discord 附圖測試 ${new Date().toLocaleString('zh-TW', { timeZone: 'Asia/Taipei' })}`;

        const res = await test.step('POST multipart (payload_json + files[0])', async () => {
            return request.post(url, {
                multipart: {
                    payload_json: JSON.stringify({ content }),
                    'files[0]': { name: 'test.png', mimeType: 'image/png', buffer }
                }
            });
        });

        await test.step('expect 2xx', async () => {
            expect(res.ok()).toBeTruthy();
        });
    });
});
