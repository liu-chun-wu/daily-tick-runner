# 🤖 Daily Tick Runner - 自動化打卡系統

![Playwright](https://img.shields.io/badge/Playwright-45ba4b?style=for-the-badge&logo=playwright&logoColor=white)
![TypeScript](https://img.shields.io/badge/TypeScript-007ACC?style=for-the-badge&logo=typescript&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?style=for-the-badge&logo=github-actions&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=node.js&logoColor=white)

一個基於 Playwright 的自動化打卡系統，透過 GitHub Actions 實現定時自動簽到簽退，支援 Discord 和 LINE 通知。

## 📋 目錄

- [專案簡介](#-專案簡介)
- [系統架構](#-系統架構)
- [快速開始](#-快速開始)
- [環境變數](#-環境變數)
- [使用方式](#-使用方式)
- [專案結構](#-專案結構)
- [測試說明](#-測試說明)
- [GitHub Actions](#-github-actions)
- [通知系統](#-通知系統)
- [開發指南](#-開發指南)
- [疑難排解](#-疑難排解)
- [安全注意事項](#-安全注意事項)

## 🎯 專案簡介

### 核心功能

- ✅ **自動化打卡**：自動執行每日簽到簽退作業
- 🕐 **智慧排程**：支援工作日自動執行（週一至週五）
- 📸 **截圖存證**：自動擷取打卡成功畫面
- 💬 **即時通知**：支援 Discord 和 LINE 雙平台通知
- 🔍 **完整日誌**：詳細的執行日誌與錯誤追蹤
- 🌏 **時區支援**：正確處理台北時區
- 📍 **位置驗證**：支援 GPS 座標設定

### 技術特色

- 使用 Playwright 進行 E2E 自動化測試
- Page Object Model 設計模式
- TypeScript 強型別支援
- GitHub Actions CI/CD 整合
- 環境變數安全管理
- 完整的錯誤處理機制

## 🏗️ 系統架構

```
┌─────────────────────────────────────────────────────┐
│                   GitHub Actions                    │
│  ┌──────────────┐            ┌──────────────┐       │
│  │ Test Schedule│            │ Production   │       │
│  │ (每5分鐘)     │            │ Schedule     │       │
│  └──────┬───────┘            └──────┬───────┘       │
└─────────┼───────────────────────────┼───────────────┘
          │                           │
          ▼                           ▼
    ┌────────────────────────────────────────┐
    │         Playwright Test Runner         │
    └────────────────┬───────────────────────┘
                     │
         ┌───────────┼───────────┐
         ▼           ▼           ▼
    ┌─────────┐ ┌─────────┐ ┌─────────┐
    │  Setup  │ │  Smoke  │ │  Click  │
    │  Tests  │ │  Tests  │ │  Tests  │
    └─────────┘ └─────────┘ └────┬────┘
                                 │
                    ┌────────────┼────────────┐
                    ▼                         ▼
               ┌──────────┐             ┌──────────┐
               │ Discord  │             │   LINE   │
               │ Webhook  │             │   API    │
               └──────────┘             └──────────┘
```

## 🚀 快速開始

### 前置需求

- Node.js 18+ 
- npm 或 yarn
- Git
- AOA 系統帳號
- (選用) Discord Webhook URL
- (選用) LINE Messaging API Token

### 安裝步驟

1. **Fork 專案**
   ```bash
   # Fork 此專案到你的 GitHub 帳號
   ```

2. **Clone 專案**
   ```bash
   git clone https://github.com/YOUR_USERNAME/daily-tick-runner.git
   cd daily-tick-runner
   ```

3. **安裝依賴**
   ```bash
   npm install
   ```

4. **安裝 Playwright**
   ```bash
   npx playwright install chromium
   ```

5. **設定環境變數**
   ```bash
   cp .env.example .env
   # 編輯 .env 檔案，填入你的設定
   ```

## 🔧 環境變數

### 必要變數

| 變數名稱 | 說明 | 範例 |
|---------|------|------|
| `BASE_URL` | AOA 系統網址 | `https://erpline.aoacloud.com.tw/` |
| `COMPANY_CODE` | 公司代碼 | `CYBERBIZ` |
| `AOA_USERNAME` | 登入帳號 | `your.email@company.com` |
| `AOA_PASSWORD` | 登入密碼 | `your_password` |
| `AOA_LAT` | GPS 緯度 | `25.080869` |
| `AOA_LON` | GPS 經度 | `121.569862` |

### 選用變數

| 變數名稱 | 說明 | 預設值 |
|---------|------|--------|
| `TZ` | 時區設定 | `Asia/Taipei` |
| `LOCALE` | 語言設定 | `zh-TW` |
| `LOG_LEVEL` | 日誌等級 | `INFO` |
| `DISCORD_WEBHOOK_URL` | Discord 通知網址 | - |
| `LINE_CHANNEL_ACCESS_TOKEN` | LINE 頻道 Token | - |
| `LINE_USER_ID` | LINE 使用者 ID | - |

### 範例 .env 檔案

```env
# 系統設定
BASE_URL=https://erpline.aoacloud.com.tw/
COMPANY_CODE=CYBERBIZ

# 登入資訊
AOA_USERNAME=user@example.com
AOA_PASSWORD=your_secure_password

# 位置資訊
AOA_LAT=25.080869
AOA_LON=121.569862

# 時區與語言
TZ=Asia/Taipei
LOCALE=zh-TW

# 日誌
LOG_LEVEL=INFO

# 通知服務（選用）
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
LINE_CHANNEL_ACCESS_TOKEN=your_line_token
LINE_USER_ID=your_line_user_id
```

## 💻 使用方式

### 本地測試

```bash
# 環境檢查
npm run test:setup

# 執行 Smoke 測試（不實際點擊）
npm run test:smoke

# 執行實際打卡（簽到）
npx playwright test tests/check/checkin.click.spec.ts --project=chromium-click

# 執行實際打卡（簽退）
npx playwright test tests/check/checkout.click.spec.ts --project=chromium-click

# 測試通知功能
npm run test:notify

# 執行所有測試
npm run test:all

# UI 模式（互動式測試）
npm run test:ui
```

### GitHub Actions 部署

1. **設定 GitHub Secrets**
   
   進入專案的 Settings → Secrets and variables → Actions，新增以下 Secrets：
   
   - `AOA_USERNAME`
   - `AOA_PASSWORD`
   - `DISCORD_WEBHOOK_URL` (選用)
   - `LINE_CHANNEL_ACCESS_TOKEN` (選用)
   - `LINE_USER_ID` (選用)

2. **設定 GitHub Variables**
   
   進入專案的 Settings → Secrets and variables → Actions → Variables，新增：
   
   - `BASE_URL`
   - `COMPANY_CODE`
   - `AOA_LAT`
   - `AOA_LON`

3. **啟用排程**
   
   - 測試排程：編輯 `.github/workflows/test-schedule.yml`，取消 schedule 註解
   - 正式排程：編輯 `.github/workflows/production-schedule.yml`，啟用 schedule

## 📁 專案結構

```
daily-tick-runner/
├── 📂 .github/workflows/        # GitHub Actions 工作流程
│   ├── test-schedule.yml        # 測試排程（每5分鐘）
│   └── production-schedule.yml  # 正式排程（8:30/18:00）
│
├── 📂 automation/               # 自動化核心程式碼
│   ├── 📂 notify/              # 通知服務
│   │   ├── discord.ts          # Discord 整合
│   │   ├── line.ts             # LINE 整合
│   │   └── types.ts            # 型別定義
│   ├── 📂 pages/               # Page Objects
│   │   ├── AttendancePage.ts   # 打卡頁面
│   │   └── LoginPage.ts        # 登入頁面
│   └── 📂 utils/               # 工具函式
│       ├── location.ts         # 位置處理
│       ├── logger.ts           # 日誌系統
│       └── stableScreenshot.ts # 截圖工具
│
├── 📂 config/                   # 設定檔
│   └── env.ts                   # 環境變數管理
│
├── 📂 tests/                    # 測試檔案
│   ├── 📂 check/               # 打卡測試
│   │   ├── checkin.click.spec.ts   # 簽到（實際點擊）
│   │   ├── checkin.smoke.spec.ts   # 簽到（驗證）
│   │   ├── checkout.click.spec.ts  # 簽退（實際點擊）
│   │   └── checkout.smoke.spec.ts  # 簽退（驗證）
│   ├── 📂 notify/              # 通知測試
│   └── 📂 setup/               # 設定測試
│
├── 📄 playwright.config.ts      # Playwright 設定
├── 📄 package.json             # 專案設定
└── 📄 README.md                # 本文件
```

## 🧪 測試說明

### 測試類型

| 標籤 | 類型 | 說明 |
|------|------|------|
| `@setup` | 設定測試 | 環境驗證與登入設定 |
| `@smoke` | Smoke 測試 | UI 元素驗證，不執行實際操作 |
| `@click` | Click 測試 | 實際執行打卡操作 |
| `@notify` | 通知測試 | 測試通知發送功能 |

### 執行順序

1. **Setup** → 驗證環境變數，建立登入 session
2. **Smoke** → 確認頁面元素正常顯示
3. **Click** → 執行實際打卡動作
4. **Notify** → 發送結果通知

## 🔄 GitHub Actions

### 測試排程 (test-schedule.yml)

- **觸發時機**：每 5 分鐘（測試用）
- **功能**：
  - 環境檢查
  - 執行簽到測試
  - 失敗時上傳截圖
  - Discord 通知

### 正式排程 (production-schedule.yml)

- **觸發時機**：
  - 簽到：週一至週五 08:30
  - 簽退：週一至週五 18:00
- **功能**：
  - 自動判斷簽到/簽退
  - 完整的錯誤處理
  - 成功/失敗通知
  - 14 天日誌保留

### 手動觸發

兩個工作流程都支援手動觸發：

1. 進入 Actions 頁面
2. 選擇工作流程
3. 點擊 "Run workflow"
4. 選擇參數並執行

## 💬 通知系統

### Discord 設定

1. 建立 Discord Webhook：
   - 伺服器設定 → 整合 → Webhook
   - 建立 Webhook 並複製 URL
   - 設定為 GitHub Secret

2. 通知內容：
   - ✅ 打卡成功通知
   - ❌ 打卡失敗警告
   - 📸  包含截圖證明

### LINE 設定

1. 建立 LINE Messaging API Channel：
   - 前往 [LINE Developers](https://developers.line.biz/)
   - 建立 Provider 和 Channel
   - 取得 Channel Access Token

2. 取得 User ID：
   - 使用 LINE Official Account Manager
   - 或透過 Webhook 事件取得

3. 通知內容：
   - 文字訊息
   - 圖片訊息（透過 Discord CDN）

## 👨‍💻 開發指南

### 開發環境設定

```bash
# 安裝開發依賴
npm install

# 執行型別檢查
npx tsc --noEmit

# 執行 Playwright 程式碼產生器
npx playwright codegen https://erpline.aoacloud.com.tw/

# 查看測試報告
npx playwright show-report
```

### 新增測試

1. 在 `tests/` 目錄建立新的 spec 檔案
2. 使用適當的標籤（@smoke, @click 等）
3. 遵循 Page Object Model 模式
4. 加入適當的等待和驗證

### 除錯技巧

```bash
# 開啟 headed 模式
npx playwright test --headed

# 開啟除錯模式
npx playwright test --debug

# 指定單一測試
npx playwright test -g "簽到"

# 保留測試追蹤
npx playwright test --trace on
```

## 🔍 疑難排解

### 常見問題

**Q: 登入失敗**
- 檢查帳號密碼是否正確
- 確認公司代碼無誤
- 檢查網路連線

**Q: 打卡按鈕無法點擊**
- 可能已經打過卡
- 檢查時間是否在允許範圍內
- 確認 GPS 座標設定

**Q: 通知未收到**
- 檢查 Webhook URL 或 Token 是否正確
- 查看 GitHub Actions 日誌
- 確認通知服務正常運作

**Q: 截圖中文字亂碼**
- GitHub Actions 已自動安裝中文字體
- 本地測試需安裝 Noto CJK 字體

### 查看日誌

1. **GitHub Actions 日誌**：
   - Actions → 選擇執行 → 查看詳細日誌

2. **本地日誌**：
   - 設定 `LOG_LEVEL=DEBUG`
   - 查看 console 輸出

3. **Playwright Trace**：
   - 下載 trace.zip
   - 使用 `npx playwright show-trace trace.zip`

## 🔒 安全注意事項

### Secrets 管理

- ⚠️ **絕不**將密碼提交到程式碼庫
- 使用 GitHub Secrets 管理敏感資訊
- 定期更換密碼和 Token
- 限制 Repository 存取權限

### 最佳實踐

1. 使用強密碼
2. 啟用 GitHub 兩步驟驗證
3. 定期檢查 Actions 執行紀錄
4. 監控異常登入活動

## 📝 授權

MIT License

## 🙏 致謝

- [Playwright](https://playwright.dev/) - 自動化測試框架
- [GitHub Actions](https://github.com/features/actions) - CI/CD 平台
- 所有貢獻者與使用者

---

<div align="center">
  
**Made with ❤️ by Daily Tick Runner Team**

[問題回報](https://github.com/liu-chun-wu/daily-tick-runner/issues) | [功能建議](https://github.com/liu-chun-wu/daily-tick-runner/issues) | [參與貢獻](https://github.com/liu-chun-wu/daily-tick-runner/pulls)

</div>
