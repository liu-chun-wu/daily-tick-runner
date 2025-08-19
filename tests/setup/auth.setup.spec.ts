import { test } from '@playwright/test';
import { LoginPage } from '../../automation/pages/LoginPage';
import { env } from '../../config/env';
import fs from 'node:fs/promises';

const authFile = 'playwright/.auth/state.json';

test('authenticate and save storageState', async ({ page, context }) => {
    // 先確保目錄存在
    await fs.mkdir('playwright/.auth', { recursive: true }); // 等同 mkdir -p

    // ...執行登入流程（填公司代號/帳號/密碼 → 登入）
    const login = new LoginPage(page);
    await page.goto(env.baseURL);
    await login.login({
        companyCode: env.companyCode,
        username: env.username,
        password: env.password,
    });

    // 填公司代號/帳號/密碼 → 按登入 ...
    // 等待首頁（URL 片段或關鍵元素二選一）
    await Promise.race([
        page.waitForURL('**/home**', { timeout: 15000 }),                 // 若有固定首頁 URL
        page.locator('ion-col:has-text("出勤打卡")').waitFor({ timeout: 15000 }) // 或用首頁元素
    ]);

    // ✅ 確認真的登入成功後，再寫 storageState（含 IndexedDB）
    await context.storageState({ path: authFile, indexedDB: true });
});
