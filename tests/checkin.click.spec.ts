import { test } from '@playwright/test';
import { AttendancePage } from '../automation/pages/AttendancePage';

test('簽到(真的點)', { tag: '@click' }, async ({ page }) => {
    const attendance = new AttendancePage(page);
    await attendance.goto();
    await attendance.checkIn();
});
