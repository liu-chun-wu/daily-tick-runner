import { expect, type Page, type TestInfo } from '@playwright/test';
import {
    AttendancePage,
    type AttendanceAction,
    type AttendanceResult,
} from '../../automation/pages/AttendancePage';
import { notifyDiscord } from '../../automation/notify/discord';
import { notifyLine } from '../../automation/notify/line';
import { env } from '../../config/env';
import { getEnvLocationName } from '../../automation/utils/location';

async function captureEvidence(page: Page, testInfo: TestInfo, filename: string) {
    const screenshotPath = testInfo.outputPath(filename);
    const screenshotBuffer = await page.screenshot({ path: screenshotPath, fullPage: true });
    await testInfo.attach(filename, { path: screenshotPath, contentType: 'image/png' });
    return { screenshotBuffer, screenshotPath };
}

export async function runAttendance(action: AttendanceAction, page: Page, testInfo: TestInfo) {
    const attendance = new AttendancePage(page);
    const actionLabel = action === 'checkin' ? '簽到' : '簽退';
    const actionMethod = action === 'checkin'
        ? () => attendance.checkIn()
        : () => attendance.checkOut();

    await attendance.goto();

    let result: AttendanceResult;
    try {
        result = await actionMethod();
    } catch (error) {
        await captureEvidence(page, testInfo, `${action}-unexpected-result.png`);
        throw error;
    }

    const filename = `${action}-${result.status}.png`;
    const { screenshotBuffer, screenshotPath } = await captureEvidence(page, testInfo, filename);

    if (result.status === 'failure') {
        throw new Error(`${actionLabel}失敗：${result.detail || '目標系統未提供錯誤說明'}`);
    }

    await expect(page.locator('.alert-title')).toHaveText('打卡成功');
    await page.getByRole('button', { name: '確定' }).click();
    await expect(page.locator('.alert-wrapper')).toBeHidden();

    const now = new Date().toLocaleString(env.locale, { timeZone: env.timezoneId });
    const message = `✅ 已成功${actionLabel}\n🕒 ${now}\n📍 ${getEnvLocationName(env)}`;

    await Promise.all([
        notifyDiscord({ message, screenshotBuffer, filename, screenshotPath }),
        notifyLine({ message, screenshotBuffer, filename, screenshotPath }),
    ]);
}
