import { test, expect } from '@playwright/test';
import { AttendancePage } from '../../automation/pages/AttendancePage';
import { waitForAttendanceReady, captureFullPageScreenshot } from '../../automation/utils/stableScreenshot';
import { notifyDiscord, uploadImageToDiscord } from '../../automation/notify/discord';
import { notifyLine } from '../../automation/notify/line';
import { env } from '../../config/env';
import { getEnvLocationName } from '../../automation/utils/location';

test('簽到(真的點)', { tag: '@click' }, async ({ page }, testInfo) => {
    const attendance = new AttendancePage(page);

    await test.step('導航至出勤打卡頁面', async () => {
        await attendance.goto();
    });

    await test.step('執行簽到操作', async () => {
        await attendance.checkIn();
    });

    await test.step('等待頁面渲染完成', async () => {
        await waitForAttendanceReady(page);
    });

    await test.step('驗證打卡成功彈窗', async () => {
        const alert = page.locator('.alert-wrapper');
        await expect(alert).toBeVisible();
        await expect(page.locator('.alert-title')).toHaveText('打卡成功');
        await expect(page.locator('.alert-sub-title')).toHaveText(/\d{1,2}:\d{2}:\d{2}/);
    });

    const filename = 'checkin-click-fullpage.png';
    let screenshotBuffer: Buffer | undefined;
    let screenshotPath: string | undefined;

    await test.step('撷取成功狀態截圖', async () => {
        screenshotBuffer = await captureFullPageScreenshot(page);
        screenshotPath = testInfo.outputPath(filename);
        await page.screenshot({ path: screenshotPath, fullPage: true });
        await testInfo.attach(filename, { path: screenshotPath, contentType: 'image/png' });
    });

    await test.step('關閉成功彈窗', async () => {
        await page.getByRole('button', { name: '確定' }).click();
        await expect(page.locator('.alert-wrapper')).toBeHidden();
    });

    await test.step('發送成功通知', async () => {
        const nowTW = new Date().toLocaleString('zh-TW', { timeZone: 'Asia/Taipei' });
        const location = `📍 ${getEnvLocationName(env)}`;
        const message = `✅ 檢查完畢，已成功簽到\n🕒 ${nowTW}\n${location}`;

        // 先上傳圖片到 Discord 獲取 URL
        let imageUrl: string | undefined;
        if (screenshotBuffer && env.discordWebhookUrl) {
            try {
                imageUrl = await uploadImageToDiscord(
                    env.discordWebhookUrl,
                    screenshotBuffer,
                    filename
                );
            } catch (error) {
                console.warn('Failed to upload image to Discord:', error);
            }
        }

        // 使用相同的圖片 URL 發送通知
        await Promise.all([
            notifyDiscord({ message, imageUrl }),
            notifyLine({ message, imageUrl, screenshotBuffer, filename, screenshotPath }),
        ]);
    });
});
