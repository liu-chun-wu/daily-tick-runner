import { test, expect } from '@playwright/test';
import { AttendancePage } from '../../automation/pages/AttendancePage';
import { waitForAttendanceReady, fullPageScreenshotStable } from '../../automation/utils/stableScreenshot';

test('簽到頁可見(不點)', { tag: '@smoke' }, async ({ page }, testInfo) => {
    const attendance = new AttendancePage(page); // 放在步驟外，閱讀更直覺

    await test.step('導航至出勤打卡頁面', async () => {
        await attendance.goto();
    });

    await test.step('驗證簽到按鈕可操作', async () => {
        const inBtn = page.getByRole('button', { name: '簽到' });
        await expect(inBtn).toBeVisible();
        await expect(inBtn).toBeEnabled();
    });

    await test.step('等待頁面渲染完成', async () => {
        await waitForAttendanceReady(page);
    });

    const filename = 'checkin-smoke-fullpage.png';
    await test.step('撷取完整頁面截圖', async () => {
        await fullPageScreenshotStable(page, testInfo, filename);
    });
});
