import { test, expect } from '@playwright/test';
import { AttendancePage } from '../automation/pages/AttendancePage';

test('簽到頁可見(不點)', { tag: '@no-click' }, async ({ page }) => {
    const attendance = new AttendancePage(page); // 放在步驟外，閱讀更直覺

    await test.step('到首頁並進入出勤打卡', async () => {
        await attendance.goto(); // 內部已 page.goto('/') 並點進「出勤打卡」
    });

    await test.step('觀察簽到按鈕', async step => {
        const inBtn = page.getByRole('button', { name: '簽到' });

        await expect(inBtn).toBeVisible();
        await expect(inBtn).toBeEnabled();
    });
});
