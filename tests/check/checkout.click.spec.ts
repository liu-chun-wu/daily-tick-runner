import { test, expect } from '@playwright/test';
import { AttendancePage } from '../../automation/pages/AttendancePage';
import { waitForAttendanceReady, captureFullPageScreenshot } from '../../automation/utils/stableScreenshot';
import { notifyDiscord } from '../../automation/notify/discord';
import { notifyLine } from '../../automation/notify/line';
import { env } from '../../config/env';
import { getEnvLocationName } from '../../automation/utils/location';

test('簽退(真的點)', { tag: '@click' }, async ({ page }, testInfo) => {
    const attendance = new AttendancePage(page);

    await test.step('導航至出勤打卡頁面', async () => {
        await attendance.goto();
    });

    await test.step('執行簽退操作', async () => {
        await attendance.checkOut();
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

    const filename = 'checkout-click-fullpage.png';
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
        const message = `✅ 檢查完畢，已成功簽退\n🕒 ${nowTW}\n${location}`;

        await Promise.all([
            notifyDiscord({ message, screenshotBuffer, filename, screenshotPath }),
            notifyLine({ message, screenshotBuffer, filename, screenshotPath }),
        ]);
    });
});