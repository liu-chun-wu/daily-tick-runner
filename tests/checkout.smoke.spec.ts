import { test, expect } from '@playwright/test';
import { AttendancePage } from '../automation/pages/AttendancePage';

test('簽退頁可見(不點)', { tag: '@no-click' }, async ({ page }) => {
    const attendance = new AttendancePage(page);

    await test.step('到首頁並進入出勤打卡', async () => {
        await attendance.goto(); // 內部已 page.goto('/') 並點進「出勤打卡」
    });

    await test.step('觀察簽退按鈕', async step => {
        const outBtn = page.getByRole('button', { name: '簽退' });

        await expect(outBtn).toBeVisible();
        await expect(outBtn).toBeEnabled();
    });
});
