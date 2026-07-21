import { expect, test } from '@playwright/test';
import type { FullResult, TestCase, TestResult } from '@playwright/test/reporter';
import {
    SmokeNotifyReporter,
    type SmokeNotifyDependencies,
} from '../../automation/reporters/smokeNotifyReporter';
import type { NotifyOpts } from '../../automation/notify/types';

function passedSmokeResult(attachments: TestResult['attachments']): {
    testCase: TestCase;
    result: TestResult;
} {
    return {
        testCase: {
            id: 'smoke-test',
            tags: ['@smoke'],
        } as TestCase,
        result: {
            status: 'passed',
            attachments,
        } as TestResult,
    };
}

test('Smoke 摘要會把 attachment 圖片送至 Discord 並沿用於 LINE', { tag: '@result' }, async () => {
    const screenshot = Buffer.from('fake-png');
    const readPaths: string[] = [];
    const uploads: Array<{
        webhookUrl: string;
        imageBuffer: Buffer;
        filename: string;
        content: string;
    }> = [];
    const lineNotifications: NotifyOpts[] = [];

    const dependencies: SmokeNotifyDependencies = {
        getConfig: () => ({
            discordWebhookUrl: 'https://discord.example.invalid/webhook',
            lineEnabled: true,
            locale: 'zh-TW',
            timezoneId: 'Asia/Taipei',
        }),
        readScreenshot: async path => {
            readPaths.push(path);
            return screenshot;
        },
        uploadScreenshot: async (webhookUrl, imageBuffer, filename, content) => {
            uploads.push({ webhookUrl, imageBuffer, filename, content });
            return 'https://cdn.example.invalid/smoke.png';
        },
        sendLine: async options => {
            lineNotifications.push(options);
        },
    };

    const reporter = new SmokeNotifyReporter(dependencies);
    const smoke = passedSmokeResult([{
        name: 'checkin-smoke-fullpage.png',
        contentType: 'image/png',
        path: '/tmp/checkin-smoke-fullpage.png',
    }]);

    reporter.onTestEnd(smoke.testCase, smoke.result);
    const outcome = await reporter.onEnd({ status: 'passed' } as FullResult);

    expect(outcome).toBeUndefined();
    expect(readPaths).toEqual(['/tmp/checkin-smoke-fullpage.png']);
    expect(uploads).toHaveLength(1);
    expect(uploads[0].webhookUrl).toBe('https://discord.example.invalid/webhook');
    expect(uploads[0].imageBuffer).toEqual(screenshot);
    expect(uploads[0].filename).toBe('checkin-smoke-fullpage.png');
    expect(uploads[0].content).toContain('✅ Smoke 測試成功');
    expect(uploads[0].content).toContain('🖼️ 截圖：checkin-smoke-fullpage.png');
    expect(lineNotifications).toEqual([{
        message: uploads[0].content,
        imageUrl: 'https://cdn.example.invalid/smoke.png',
        failOnError: true,
    }]);
});

test('Smoke 通過但沒有 PNG attachment 時通知驗收失敗', { tag: '@result' }, async () => {
    let uploadCalled = false;
    const dependencies: SmokeNotifyDependencies = {
        getConfig: () => ({
            discordWebhookUrl: 'https://discord.example.invalid/webhook',
            lineEnabled: false,
            locale: 'zh-TW',
            timezoneId: 'Asia/Taipei',
        }),
        readScreenshot: async () => Buffer.from('unused'),
        uploadScreenshot: async () => {
            uploadCalled = true;
            return 'https://cdn.example.invalid/unused.png';
        },
        sendLine: async () => {},
    };

    const reporter = new SmokeNotifyReporter(dependencies);
    const smoke = passedSmokeResult([]);

    reporter.onTestEnd(smoke.testCase, smoke.result);
    const outcome = await reporter.onEnd({ status: 'passed' } as FullResult);

    expect(outcome).toEqual({ status: 'failed' });
    expect(uploadCalled).toBe(false);
});
