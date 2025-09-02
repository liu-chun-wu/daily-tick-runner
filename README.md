# 🤖 Daily Tick Runner - 自動化打卡系統

![CI](https://github.com/liu-chun-wu/daily-tick-runner/actions/workflows/ci.yml/badge.svg)
![Playwright](https://img.shields.io/badge/Playwright-45ba4b?style=for-the-badge&logo=playwright&logoColor=white)
![TypeScript](https://img.shields.io/badge/TypeScript-007ACC?style=for-the-badge&logo=typescript&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?style=for-the-badge&logo=github-actions&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=node.js&logoColor=white)

一個基於 Playwright 的自動化打卡系統，透過 GitHub Actions 實現定時自動簽到簽退，支援 Discord 和 LINE 通知。

## 📋 目錄

- [專案簡介](#-專案簡介)
- [核心功能](#-核心功能)
- [快速開始](#-快速開始)
- [環境變數](#-環境變數)
- [使用方式](#-使用方式)
- [相關文檔](#-相關文檔)

## 🎯 專案簡介

一個基於 Playwright 的自動化打卡系統，透過 GitHub Actions 或本地排程器實現定時自動簽到簽退。

## 🚀 核心功能

- ✅ **自動化打卡** - 自動執行每日簽到簽退
- 🕐 **智慧排程** - 支援工作日自動執行
- 🔄 **多層重試** - 確保執行穩定性
- 📸 **截圖存證** - 自動保存執行結果
- 💬 **即時通知** - Discord/LINE 雙平台支援
- 🌏 **時區支援** - 正確處理台北時區

## ⚡ 快速開始

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

### 本地開發測試

```bash
# 環境檢查與登入設置
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

### CI/CD 自動化測試

專案已配置完整的 CI/CD 流程：

- **CI 測試**：每次 Pull Request 和推送到 main 分支時自動執行
  - 自動登入設置
  - 執行通知測試（notify）
  - 執行 smoke 測試（chromium-smoke）
  - 包含重試機制和失敗通知

- **使用自有容器映像**：`ghcr.io/liu-chun-wu/daily-tick-runner/runner:latest`
  - 預裝 Playwright 瀏覽器
  - 包含中文字型支援
  - 確保環境一致性

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

3. **CI/CD Workflows**
   
   專案包含以下自動化 workflows：
   
   - **ci.yml**：Pull Request 和 main 分支的持續整合測試
   - **test-schedule.yml**：測試用排程（可手動觸發）
   - **production-schedule.yml**：正式排程（每日簽到簽退）
   - **build-image.yml**：建置並推送容器映像到 GHCR

4. **啟用排程**
   
   - 測試排程：編輯 `.github/workflows/test-schedule.yml`，取消 schedule 註解
   - 正式排程：編輯 `.github/workflows/production-schedule.yml`，啟用 schedule

### 部署選項

#### 方式一：GitHub Actions（推薦）
詳見 [部署指南](./DEPLOYMENT.md)

#### 方式二：本地排程器 (macOS)
詳見 [本地排程器指南](./LOCAL-SCHEDULER.md)








## 📚 相關文檔

### 核心文檔
- [🛠 開發指南](./DEVELOPMENT.md) - 本地開發、測試撰寫、除錯技巧
- [📦 部署指南](./DEPLOYMENT.md) - GitHub Actions 設定與部署
- [🏗 架構設計](./ARCHITECTURE.md) - 系統架構與設計原則
- [⏰ 本地排程器](./LOCAL-SCHEDULER.md) - macOS 本地排程設定

### 進階文檔
- [🔍 疑難排解](./docs/TROUBLESHOOTING.md) - 常見問題與解決方案
- [🔒 安全指南](./docs/SECURITY.md) - 安全最佳實踐

### 外部資源
- [Playwright 官方文檔](https://playwright.dev)
- [GitHub Actions 文檔](https://docs.github.com/actions)

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

1