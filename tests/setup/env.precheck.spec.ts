// tests/setup/env.precheck.spec.ts
import { test, expect } from '@playwright/test';
import { env } from '../../config/env';

test.describe('環境變數前置檢查', () => {
    test('必填變數存在且格式正確', () => {
        // 檢查必要的環境變數
        expect(env.baseURL, '缺少環境變數: BASE_URL').toBeTruthy();
        expect(env.companyCode, '缺少環境變數: COMPANY_CODE').toBeTruthy();
        expect(env.username, '缺少環境變數: AOA_USERNAME').toBeTruthy();
        expect(env.password, '缺少環境變數: AOA_PASSWORD').toBeTruthy();
        expect(env.timezoneId, '缺少環境變數: TZ').toBeTruthy();
        expect(env.locale, '缺少環境變數: LOCALE').toBeTruthy();
        
        // 檢查數字格式
        expect(Number.isFinite(env.lat), 'AOA_LAT 必須是有效數字').toBeTruthy();
        expect(Number.isFinite(env.lon), 'AOA_LON 必須是有效數字').toBeTruthy();
        
        // 檢查可選的通知設定（只警告，不失敗）
        if (!env.discordWebhookUrl) {
            console.warn('⚠️ 未設定 DISCORD_WEBHOOK_URL，Discord 通知將被禁用');
        }
        if (!env.lineChannelAccessToken || !env.lineUserId) {
            console.warn('⚠️ 未設定 LINE 相關環境變數，LINE 通知將被禁用');
        }
    });
});
