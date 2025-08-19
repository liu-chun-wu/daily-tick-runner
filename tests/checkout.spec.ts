import { test } from '@playwright/test';
import { AttendancePage } from '../automation/pages/AttendancePage';

test('簽退（18:00）', async ({ page, context }) => {
    const attendance = new AttendancePage(page);
    await attendance.goto();
    await attendance.checkOut();
});
