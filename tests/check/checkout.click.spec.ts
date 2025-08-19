import { test, expect } from '@playwright/test';
import { AttendancePage } from '../../automation/pages/AttendancePage';
import { notifyDiscord } from '../../automation/notify/discord';
import { notifyLinePush } from '../../automation/notify/line';

test('簽退(真的點)', { tag: '@click' }, async ({ page }, testInfo) => {
    const attendance = new AttendancePage(page);

    await test.step('到首頁並進入出勤打卡', async () => {
        await attendance.goto(); // 內部已 page.goto('/') 並點進「出勤打卡」
    });

    await test.step('點擊簽退按鈕', async step => {
        await attendance.checkOut();
    });

    await test.step('截整頁並存證（也附到報表）', async () => {
        // 你的彈窗 DOM（Ionic Alert）
        const alert = page.locator('.alert-wrapper');
        await expect(alert).toBeVisible();
        await expect(page.locator('.alert-title')).toHaveText('打卡成功');
        await expect(page.locator('.alert-sub-title')).toHaveText(/\d{1,2}:\d{2}:\d{2}/);

        // ⇩ 產生該測試專屬的輸出路徑並截整頁
        const outPath = testInfo.outputPath('checkout-success-fullpage.png'); // 官方建議用法
        await page.screenshot({ path: outPath, fullPage: true });           // 整頁截圖
        await testInfo.attach('checkin-fullpage.png', { path: outPath, contentType: 'image/png' });

        // 關閉彈窗
        await page.getByRole('button', { name: '確定' }).click();
        await expect(alert).toBeHidden();
    });

    // await test.step('發送通知（Discord / LINE）', async () => {
    //     const nowTW = new Date().toLocaleString('zh-TW', { timeZone: 'Asia/Taipei' });
    //     const msg = `✅ 簽退成功 ${nowTW}`;
    //     if (process.env.DISCORD_WEBHOOK_URL) await notifyDiscord(page.request, msg, testInfo.outputPath('checkin-fullpage.png'));
    //     if (process.env.LINE_CHANNEL_ACCESS_TOKEN && process.env.LINE_USER_ID) await notifyLinePush(page.request, msg);
    // });
});
