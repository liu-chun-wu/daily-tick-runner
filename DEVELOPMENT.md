# 開發指南

本文檔涵蓋專案的開發環境設定、測試撰寫、除錯技巧和最佳實踐。

## 📋 目錄

- [開發環境設定](#開發環境設定)
- [專案結構](#專案結構)
- [測試開發](#測試開發)
- [Playwright CLI 指令](#playwright-cli-指令)
- [Page Object Model](#page-object-model)
- [選擇器策略](#選擇器策略)
- [等待與重試機制](#等待與重試機制)
- [除錯技巧](#除錯技巧)
- [最佳實踐](#最佳實踐)

## 開發環境設定

### 前置需求

- Node.js 18+
- npm 或 yarn
- Git
- VS Code (建議)

### 初始設定

```bash
# Clone 專案
git clone https://github.com/YOUR_USERNAME/daily-tick-runner.git
cd daily-tick-runner

# 安裝依賴
npm install

# 安裝 Playwright 瀏覽器
npx playwright install chromium

# 設定環境變數
cp .env.example .env
# 編輯 .env 填入必要資訊
```

### TypeScript 設定

專案使用 TypeScript 提供型別安全：

```bash
# 型別檢查
npx tsc --noEmit

# 監聽模式
npx tsc --watch --noEmit
```

## 專案結構

```
daily-tick-runner/
├── automation/              # 自動化核心
│   ├── pages/              # Page Objects
│   │   ├── LoginPage.ts   # 登入頁面
│   │   └── AttendancePage.ts # 打卡頁面
│   ├── notify/             # 通知服務
│   │   ├── discord.ts     # Discord 整合
│   │   ├── line.ts        # LINE 整合
│   │   └── types.ts       # 型別定義
│   └── utils/              # 工具函式
│       ├── location.ts    # 位置處理
│       ├── logger.ts      # 日誌系統
│       └── stableScreenshot.ts # 截圖工具
├── config/                 # 設定檔
│   └── env.ts             # 環境變數管理
├── tests/                  # 測試檔案
│   ├── check/             # 打卡測試
│   ├── notify/            # 通知測試
│   └── setup/             # 設定測試
└── playwright.config.ts   # Playwright 設定
```

## 測試開發

### 測試類型與標籤

| 標籤 | 類型 | 說明 | 使用時機 |
|------|------|------|----------|
| `@setup` | 設定測試 | 環境驗證與登入設定 | 初始化 |
| `@smoke` | Smoke 測試 | UI 元素驗證，不執行實際操作 | 快速驗證 |
| `@click` | Click 測試 | 實際執行打卡操作 | 生產執行 |
| `@notify` | 通知測試 | 測試通知發送功能 | 通知驗證 |

### 撰寫測試

```typescript
import { test, expect } from '@playwright/test';
import { LoginPage } from '../../automation/pages/LoginPage';
import { AttendancePage } from '../../automation/pages/AttendancePage';

test('簽到頁可見 @smoke', async ({ page }) => {
  const loginPage = new LoginPage(page);
  const attendancePage = new AttendancePage(page);
  
  // 使用 Page Object
  await loginPage.login();
  await attendancePage.navigateToAttendance();
  
  // 驗證元素
  await expect(attendancePage.checkinButton).toBeVisible();
});

test('執行簽到 @click', async ({ page }) => {
  // 跳過 CI 環境
  test.skip(!!process.env.CI, '只在本地執行');
  
  // 實際打卡邏輯
  await attendancePage.performCheckin();
});
```

## Playwright CLI 指令

### 基本執行

```bash
# 執行所有測試
npx playwright test

# 執行特定檔案
npx playwright test tests/check/checkin.smoke.spec.ts

# 執行特定資料夾
npx playwright test tests/check/

# 依標籤執行
npx playwright test --grep "@smoke"
npx playwright test --grep-invert "@click"  # 排除

# 指定專案
npx playwright test --project=chromium-smoke
npx playwright test --project=chromium-click
```

### 進階選項

```bash
# 開啟瀏覽器視窗
npx playwright test --headed

# 單一 worker (穩定除錯)
npx playwright test --workers=1

# 開啟追蹤
npx playwright test --trace on

# 除錯模式
npx playwright test --debug
PWDEBUG=1 npx playwright test

# UI 模式
npx playwright test --ui

# 列出測試但不執行
npx playwright test --list

# 指定行號執行
npx playwright test tests/checkin.click.spec.ts:12
```

### 報告與追蹤

```bash
# 查看測試報告
npx playwright show-report

# 查看追蹤檔案
npx playwright show-trace test-results/**/trace.zip

# 產生程式碼
npx playwright codegen https://erpline.aoacloud.com.tw/
```

### NPM Scripts

```json
{
  "scripts": {
    "test": "playwright test",
    "test:setup": "playwright test tests/setup",
    "test:smoke": "playwright test --grep @smoke",
    "test:click": "playwright test --grep @click --headed",
    "test:ui": "playwright test --ui",
    "test:debug": "PWDEBUG=1 playwright test",
    "test:all": "npm run test:setup && npm run test:smoke"
  }
}
```

## Page Object Model

### 基本結構

```typescript
// automation/pages/BasePage.ts
export abstract class BasePage {
  constructor(protected page: Page) {}
  
  abstract navigate(): Promise<void>;
  
  protected async waitForLoadComplete() {
    await this.page.waitForLoadState('networkidle');
  }
}

// automation/pages/LoginPage.ts
export class LoginPage extends BasePage {
  // 定義選擇器
  private readonly companyCodeInput = this.page.getByTestId('company-code');
  private readonly usernameInput = this.page.getByLabel('使用者名稱');
  private readonly passwordInput = this.page.getByLabel('密碼');
  private readonly loginButton = this.page.getByRole('button', { name: '登入' });
  
  async navigate() {
    await this.page.goto('/login');
    await this.waitForLoadComplete();
  }
  
  async login(username?: string, password?: string) {
    await this.companyCodeInput.fill(process.env.COMPANY_CODE!);
    await this.usernameInput.fill(username || process.env.AOA_USERNAME!);
    await this.passwordInput.fill(password || process.env.AOA_PASSWORD!);
    await this.loginButton.click();
    
    // 等待登入完成
    await this.page.waitForURL('**/dashboard');
  }
}
```

## 選擇器策略

### 優先順序

1. **可存取性選擇器** (最優先)
   ```typescript
   page.getByRole('button', { name: '簽到' })
   page.getByLabel('使用者名稱')
   page.getByText('確認')
   ```

2. **Test ID** (推薦)
   ```typescript
   page.getByTestId('submit-button')
   // 需在 playwright.config.ts 設定:
   // testIdAttribute: 'data-pw'
   ```

3. **穩定的 CSS 選擇器**
   ```typescript
   page.locator('.login-form input[type="email"]')
   ```

4. **避免使用**
   - 動態生成的 ID
   - 複雜的 XPath
   - 基於索引的選擇器

### 最佳實踐

```typescript
// ✅ 好的做法
const submitButton = page.getByRole('button', { name: '提交' });
const emailInput = page.getByLabel('電子郵件');
const mainHeading = page.getByRole('heading', { level: 1 });

// ❌ 避免的做法
const submitButton = page.locator('div > form > button:nth-child(3)');
const emailInput = page.locator('#input_1234567890');
const mainHeading = page.locator('//h1[contains(@class, "title")]');
```

## 等待與重試機制

### Playwright 自動等待

Playwright 內建 auto-waiting，會自動等待元素：
- 出現在 DOM
- 可見
- 穩定（停止移動）
- 可互動（未被遮擋）

```typescript
// 自動等待元素可點擊
await page.getByRole('button').click();

// 自動重試直到條件滿足
await expect(page.getByText('成功')).toBeVisible();
```

### 自訂等待

```typescript
// 等待特定條件
await page.waitForSelector('.loading', { state: 'hidden' });
await page.waitForURL('**/dashboard');
await page.waitForLoadState('networkidle');

// 等待函式回傳 true
await page.waitForFunction(() => document.readyState === 'complete');
```

### 重試配置

```typescript
// playwright.config.ts
export default defineConfig({
  // 測試層級重試
  retries: process.env.CI ? 2 : 1,
  
  use: {
    // 動作超時
    actionTimeout: 10000,
    // 導航超時
    navigationTimeout: 30000,
  },
  
  expect: {
    // 斷言超時
    timeout: 5000,
  },
});
```

### 避免固定延遲

```typescript
// ❌ 避免
await page.waitForTimeout(5000);

// ✅ 改用條件等待
await page.waitForSelector('.content', { state: 'visible' });
await expect(page.locator('.spinner')).toBeHidden();
```

## 除錯技巧

### 1. 使用 Debug 模式

```bash
# Playwright Inspector
npx playwright test --debug

# 環境變數方式
PWDEBUG=1 npx playwright test
```

### 2. 開啟 Headed 模式

```bash
npx playwright test --headed --workers=1
```

### 3. 使用 page.pause()

```typescript
test('除錯測試', async ({ page }) => {
  await page.goto('/');
  await page.pause(); // 暫停執行
  await page.click('button');
});
```

### 4. 截圖與追蹤

```typescript
// 手動截圖
await page.screenshot({ path: 'debug.png', fullPage: true });

// 設定追蹤
await context.tracing.start({ screenshots: true, snapshots: true });
// ... 測試邏輯
await context.tracing.stop({ path: 'trace.zip' });
```

### 5. 詳細日誌

```typescript
// 啟用詳細日誌
DEBUG=pw:api npx playwright test

// 自訂日誌
console.log('Current URL:', page.url());
console.log('Page title:', await page.title());
```

### 6. VS Code 整合

安裝 Playwright Test for VSCode 擴充套件：
- 在編輯器中執行測試
- 設定中斷點
- 查看測試結果

## 最佳實踐

### 1. 測試隔離

每個測試應該獨立，不依賴其他測試的狀態：

```typescript
test.beforeEach(async ({ page }) => {
  // 每個測試前重置狀態
  await page.goto('/');
});
```

### 2. 使用 Fixtures

```typescript
// fixtures/auth.ts
export const test = base.extend({
  authenticatedPage: async ({ page }, use) => {
    await loginAsUser(page);
    await use(page);
  },
});
```

### 3. 環境變數管理

```typescript
// config/env.ts
export const config = {
  baseUrl: process.env.BASE_URL || 'http://localhost:3000',
  username: process.env.AOA_USERNAME!,
  password: process.env.AOA_PASSWORD!,
};

// 使用時驗證
if (!config.username || !config.password) {
  throw new Error('Missing required environment variables');
}
```

### 4. 錯誤處理

```typescript
test('處理錯誤', async ({ page }) => {
  try {
    await page.goto('/protected');
  } catch (error) {
    // 記錄錯誤但繼續測試
    console.error('Navigation failed:', error);
    await page.screenshot({ path: 'error.png' });
  }
});
```

### 5. 效能優化

```typescript
// 重用認證狀態
test.use({ storageState: 'playwright/.auth/user.json' });

// 平行執行
test.describe.parallel('平行測試組', () => {
  test('測試 1', async ({ page }) => {});
  test('測試 2', async ({ page }) => {});
});
```

### 6. 資料驅動測試

```typescript
const testData = [
  { username: 'user1', expected: 'Welcome User 1' },
  { username: 'user2', expected: 'Welcome User 2' },
];

testData.forEach(({ username, expected }) => {
  test(`登入測試 - ${username}`, async ({ page }) => {
    await loginAs(page, username);
    await expect(page.getByText(expected)).toBeVisible();
  });
});
```

## 持續改進

### 監控測試穩定性

1. 追蹤測試失敗率
2. 分析 flaky tests
3. 優化選擇器和等待策略

### 更新相依套件

```bash
# 檢查過時套件
npm outdated

# 更新 Playwright
npm update @playwright/test

# 更新瀏覽器
npx playwright install
```

### 程式碼品質

```bash
# ESLint
npm run lint

# Prettier
npm run format

# TypeScript 檢查
npm run type-check
```

## 相關文件

- [架構設計](./ARCHITECTURE.md) - 系統架構與設計原則
- [部署指南](./DEPLOYMENT.md) - GitHub Actions 部署
- [本地排程器](./LOCAL-SCHEDULER.md) - macOS 本地排程設定
- [Playwright 官方文檔](https://playwright.dev)