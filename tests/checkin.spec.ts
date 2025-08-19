import { test } from '@playwright/test';
import { AttendancePage } from '../automation/pages/AttendancePage';

test('簽到（08:40）', async ({ page, context }) => {
    const attendance = new AttendancePage(page);
    await attendance.goto();
    await attendance.checkIn();
});
