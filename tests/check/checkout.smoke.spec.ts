import { test, expect } from '@playwright/test';
import { AttendancePage } from '../../automation/pages/AttendancePage';
import { waitForAttendanceReady, fullPageScreenshotStable } from '../../automation/utils/stableScreenshot';

test('簽退頁可見(不點)', { tag: '@smoke' }, async ({ page }, testInfo) => {
    const attendance = new AttendancePage(page);

    await test.step('導航至出勤打卡頁面', async () => {
        await attendance.goto();
    });

    await test.step('驗證簽退按鈕可操作', async () => {
        const outBtn = page.getByRole('button', { name: '簽退' });
        await expect(outBtn).toBeVisible();
        await expect(outBtn).toBeEnabled();
    });

    await test.step('等待頁面渲染完成', async () => {
        await waitForAttendanceReady(page);
    });

    const filename = 'checkout-smoke-fullpage.png';
    await test.step('撷取完整頁面截圖', async () => {
        await fullPageScreenshotStable(page, testInfo, filename);
    });
});
