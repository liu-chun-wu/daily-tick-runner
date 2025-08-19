import { test, expect } from '@playwright/test';
import { AttendancePage } from '../../automation/pages/AttendancePage';
import { waitForAttendanceReady, fullPageScreenshotStable } from '../../automation/utils/stableScreenshot';

test('簽到頁可見(不點)', { tag: '@smoke' }, async ({ page }, testInfo) => {
    const attendance = new AttendancePage(page); // 放在步驟外，閱讀更直覺

    await test.step('到首頁並進入出勤打卡', async () => {
        await attendance.goto(); // 內部已 page.goto('/') 並點進「出勤打卡」
    });

    await test.step('觀察簽到按鈕並截整頁圖到輸出目錄', async step => {
        const inBtn = page.getByRole('button', { name: '簽到' });

        await expect(inBtn).toBeVisible();
        await expect(inBtn).toBeEnabled();
    });

    await test.step('等待畫面穩定', async () => {
        await waitForAttendanceReady(page);
    });

    await test.step('整頁截圖存證', async () => {
        await fullPageScreenshotStable(page, testInfo, 'checkin-success-fullpage.png');
    });
});
