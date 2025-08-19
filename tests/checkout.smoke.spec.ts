import { test, expect } from '@playwright/test';
import { AttendancePage } from '../automation/pages/AttendancePage';

test('簽退頁可見(不點)', { tag: '@no-click' }, async ({ page }) => {
    const attendance = new AttendancePage(page);
    await attendance.goto();

    const outBtn = page.getByRole('button', { name: '簽退' });

    await expect(outBtn).toBeVisible();
    await expect(outBtn).toBeEnabled();
});
