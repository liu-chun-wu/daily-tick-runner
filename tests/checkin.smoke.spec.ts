import { test, expect } from '@playwright/test';
import { AttendancePage } from '../automation/pages/AttendancePage';

test('簽到頁可見(不點)', { tag: '@no-click' }, async ({ page }) => {
    const attendance = new AttendancePage(page);
    await attendance.goto();

    const inBtn = page.getByRole('button', { name: '簽到' });

    await expect(inBtn).toBeVisible();
    await expect(inBtn).toBeEnabled();
});
