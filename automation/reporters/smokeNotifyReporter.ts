import type {
    FullResult,
    Reporter,
    TestCase,
    TestResult,
} from '@playwright/test/reporter';
import { env } from '../../config/env';
import { notifyDiscord } from '../notify/discord';
import { notifyLine } from '../notify/line';

class SmokeNotifyReporter implements Reporter {
    private readonly smokeResults = new Map<string, TestResult['status']>();

    printsToStdio() {
        return false;
    }

    onTestEnd(test: TestCase, result: TestResult) {
        if (test.tags.includes('@smoke')) {
            this.smokeResults.set(test.id, result.status);
        }
    }

    async onEnd(result: FullResult) {
        if (result.status !== 'passed') {
            console.log('[SmokeNotify] Smoke 未通過，不發送成功通知。');
            return;
        }

        const passed = [...this.smokeResults.values()].filter(status => status === 'passed').length;
        const total = this.smokeResults.size;
        if (total === 0) {
            console.error('[SmokeNotify] 本次沒有執行任何 @smoke 測試，不發送通知。');
            return { status: 'failed' as const };
        }

        const discordEnabled = Boolean(env.discordWebhookUrl);
        const lineEnabled = Boolean(env.lineChannelAccessToken && env.lineUserId);

        if (!discordEnabled && !lineEnabled) {
            console.error('[SmokeNotify] 未設定 Discord 或 LINE 通知，無法發送 Smoke 摘要。');
            return { status: 'failed' as const };
        }

        const now = new Date().toLocaleString(env.locale, { timeZone: env.timezoneId });
        const message = [
            '✅ Smoke 測試成功',
            '🔐 登入完成',
            '🧪 簽到／簽退頁面可正常存取（未點擊）',
            `📊 ${passed}/${total} 項 Smoke 通過`,
            `🕒 ${now}`,
        ].join('\n');

        const notifications: Promise<void>[] = [];
        if (discordEnabled) notifications.push(notifyDiscord({ message }));
        if (lineEnabled) notifications.push(notifyLine({ message }));
        await Promise.all(notifications);

        console.log('[SmokeNotify] Smoke 成功摘要已要求發送。');
    }
}

export default SmokeNotifyReporter;
