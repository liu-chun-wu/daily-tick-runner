import { defineConfig, devices } from '@playwright/test';
import { env } from './config/env';

export default defineConfig({
    testDir: './tests',
    // 全域 use：這裡放 baseURL、時區、語系、地理權限等
    use: {
        baseURL: env.baseURL,                  // ← 讓 page.goto('/') 有效
        timezoneId: env.timezoneId,
        locale: env.locale,
        permissions: ['geolocation'],
        geolocation: { latitude: env.lat, longitude: env.lon },
        trace: 'on-first-retry',
        screenshot: 'only-on-failure',
        video: 'retain-on-failure',
    },
    projects: [
        // 1) setup：登入產出 storageState，不要讀取 storageState
        { name: 'setup', testDir: './tests/setup', use: { storageState: undefined } },

        // 2) 實際測試：依賴 setup，這裡才讀取 storageState
        {
            name: 'chromium',
            use: {
                ...devices['Desktop Chrome'],
                storageState: 'playwright/.auth/state.json',
            },
            dependencies: ['setup'],
        },
    ],
    // 其餘通用設定（timezoneId/locale/geolocation 等）放全域 use 沒問題
});
