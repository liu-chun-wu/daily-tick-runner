import { test, expect } from '@playwright/test';
import { AttendancePage } from '../../automation/pages/AttendancePage';
import { waitForAttendanceReady, fullPageScreenshotStable } from '../../automation/utils/stableScreenshot';
import { notifyDiscord } from '../../automation/notify/discord';
import { notifyLinePush } from '../../automation/notify/line';
import { env } from '../../config/env';
import { getEnvLocationName } from '../../automation/utils/location';

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
    let screenshotBuffer: Buffer | undefined;
    let screenshotPath: string | undefined;

    await test.step('撷取完整頁面截圖', async () => {
        const result = await fullPageScreenshotStable(page, testInfo, filename);
        screenshotBuffer = result.screenshotBuffer;
        screenshotPath = result.outPath;
    });

    await test.step('發送測試結果通知', async () => {
        const nowTW = new Date().toLocaleString('zh-TW', { timeZone: 'Asia/Taipei' });
        const location = `📍 ${getEnvLocationName(env)}`;
        const message = `✅ 簽退頁面可正常存取\n🕒 ${nowTW}\n${location}`;

        await Promise.all([
            notifyDiscord({ message, screenshotBuffer, filename, screenshotPath }),
            // notifyLinePush({ message, screenshotBuffer, filename, screenshotPath }),
        ]);
    });
});
