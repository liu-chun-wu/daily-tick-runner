import { readFile } from 'node:fs/promises';
import type {
    FullResult,
    Reporter,
    TestCase,
    TestResult,
} from '@playwright/test/reporter';
import { env } from '../../config/env';
import { uploadToDiscordAndGetUrl } from '../notify/discord';
import { notifyLine } from '../notify/line';
import type { NotifyOpts } from '../notify/types';

type SmokeScreenshot = Pick<
    TestResult['attachments'][number],
    'body' | 'contentType' | 'name' | 'path'
>;

export interface SmokeNotifyDependencies {
    getConfig: () => {
        discordWebhookUrl?: string;
        lineEnabled: boolean;
        locale: string;
        timezoneId: string;
    };
    readScreenshot: (path: string) => Promise<Buffer>;
    uploadScreenshot: (
        webhookUrl: string,
        imageBuffer: Buffer,
        filename: string,
        content: string
    ) => Promise<string>;
    sendLine: (options: NotifyOpts) => Promise<void>;
}

const defaultDependencies: SmokeNotifyDependencies = {
    getConfig: () => ({
        discordWebhookUrl: env.discordWebhookUrl,
        lineEnabled: Boolean(env.lineChannelAccessToken && env.lineUserId),
        locale: env.locale,
        timezoneId: env.timezoneId,
    }),
    readScreenshot: path => readFile(path),
    uploadScreenshot: uploadToDiscordAndGetUrl,
    sendLine: notifyLine,
};

export class SmokeNotifyReporter implements Reporter {
    private readonly smokeResults = new Map<string, TestResult['status']>();
    private readonly smokeScreenshots = new Map<string, SmokeScreenshot>();

    constructor(private readonly dependencies = defaultDependencies) {}

    printsToStdio() {
        return false;
    }

    onTestEnd(test: TestCase, result: TestResult) {
        if (test.tags.includes('@smoke')) {
            this.smokeResults.set(test.id, result.status);

            const screenshot = result.attachments.find(attachment =>
                attachment.contentType === 'image/png'
                && attachment.name.includes('smoke')
                && Boolean(attachment.body || attachment.path)
            );

            if (result.status === 'passed' && screenshot) {
                this.smokeScreenshots.set(test.id, screenshot);
            }
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

        const { discordWebhookUrl, lineEnabled, locale, timezoneId }
            = this.dependencies.getConfig();

        if (!discordWebhookUrl) {
            console.error('[SmokeNotify] 發送 Smoke 截圖需要 DISCORD_WEBHOOK_URL；LINE 圖片也使用 Discord CDN 暫存。');
            return { status: 'failed' as const };
        }

        const screenshot = [...this.smokeScreenshots.values()]
            .sort((left, right) => left.name.localeCompare(right.name))[0];
        if (!screenshot) {
            console.error('[SmokeNotify] Smoke 通過但找不到 PNG 截圖，不發送不完整的通知。');
            return { status: 'failed' as const };
        }

        let screenshotBuffer: Buffer;
        try {
            screenshotBuffer = screenshot.body ?? await this.dependencies.readScreenshot(screenshot.path!);
        } catch (error) {
            const detail = error instanceof Error ? error.message : String(error);
            console.error(`[SmokeNotify] 無法讀取 Smoke 截圖：${detail}`);
            return { status: 'failed' as const };
        }

        const now = new Date().toLocaleString(locale, { timeZone: timezoneId });
        const message = [
            '✅ Smoke 測試成功',
            '🔐 登入完成',
            '🧪 簽到／簽退頁面可正常存取（未點擊）',
            `📊 ${passed}/${total} 項 Smoke 通過`,
            `🖼️ 截圖：${screenshot.name}`,
            `🕒 ${now}`,
        ].join('\n');

        try {
            const imageUrl = await this.dependencies.uploadScreenshot(
                discordWebhookUrl,
                screenshotBuffer,
                screenshot.name,
                message
            );

            if (lineEnabled) {
                await this.dependencies.sendLine({ message, imageUrl, failOnError: true });
            }
        } catch (error) {
            const detail = error instanceof Error ? error.message : String(error);
            console.error(`[SmokeNotify] Smoke 通知驗證失敗：${detail}`);
            return { status: 'failed' as const };
        }

        console.log('[SmokeNotify] Smoke 成功摘要與截圖已發送。');
    }
}

export default SmokeNotifyReporter;
