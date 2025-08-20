import { defineConfig, devices } from '@playwright/test';
import { env } from './config/env';

export default defineConfig({
    testDir: './tests',
    
    // 重試設定：CI 環境重試更多次
    retries: process.env.CI ? 2 : 1,
    
    // 超時設定：給網路不穩更多時間
    timeout: 60 * 1000,        // 單個測試 60 秒
    expect: {
        timeout: 15 * 1000,    // expect 等待 15 秒
    },
    
    // 全域 use：這裡放 baseURL、時區、語系、地理權限等
    use: {
        baseURL: env.baseURL,                  // ← 讓 page.goto('/') 有效
        timezoneId: env.timezoneId,
        locale: env.locale,
        permissions: ['geolocation'],
        geolocation: { latitude: env.lat, longitude: env.lon },
        
        // 增強的除錯和追蹤設定
        trace: 'on-first-retry',
        screenshot: 'only-on-failure',
        video: 'retain-on-failure',
        
        // 增加動作間隔，提高穩定性
        actionTimeout: 10 * 1000,  // 單個動作 10 秒
        navigationTimeout: 30 * 1000,  // 頁面導航 30 秒
    },
    projects: [
        // setup：登入產出 storageState，不要讀取 storageState
        { name: 'setup', testDir: './tests/setup', use: { storageState: undefined } },

        // 只跑 "不點擊" 測試（預設專案；給 CI/排程）
        {
            name: 'chromium-smoke',
            use: { ...devices['Desktop Chrome'], storageState: 'playwright/.auth/state.json' },
            dependencies: ['setup'],
            grep: /@smoke/,              // 只跑標了 @no-click 的測試
        },

        // 真的點擊（本機手動要跑時才指定）
        {
            name: 'chromium-click',
            use: { ...devices['Desktop Chrome'], storageState: 'playwright/.auth/state.json' },
            dependencies: ['setup'],
            grep: /@click/,
        },

        // 傳送通知（Discord/LINE）
        {
            name: 'notify',
            grep: /@notify/,
            use: { ...devices['Desktop Chrome'] }
        },
    ],
    // 其餘通用設定（timezoneId/locale/geolocation 等）放全域 use 沒問題
});
