import { test } from '@playwright/test';
import { runAttendance } from './runAttendance';

test('簽到（真實操作，只點擊一次）', { tag: '@click' }, async ({ page }, testInfo) => {
    await runAttendance('checkin', page, testInfo);
});
