# GitHub Actions 部署指南

本專案使用 GitHub Actions 實現完整的 CI/CD 流程，包含持續整合測試、自動打卡排程，以及容器化部署。

## 🚀 部署步驟

### 1. Repository Secrets 設定

進入 GitHub 專案的 `Settings` > `Secrets and variables` > `Actions`，設定以下 **Secrets**：

| 名稱 | 說明 | 範例 |
|------|------|------|
| `AOA_USERNAME` | AOA 系統使用者名稱 | `your_username` |
| `AOA_PASSWORD` | AOA 系統密碼 | `your_password` |
| `DISCORD_WEBHOOK_URL` | Discord Webhook URL（可選） | `https://discord.com/api/webhooks/...` |
| `LINE_CHANNEL_ACCESS_TOKEN` | LINE Messaging API Token（可選） | `YOUR_CHANNEL_ACCESS_TOKEN` |
| `LINE_USER_ID` | LINE 使用者 ID（可選） | `U1234567890abcdef...` |

### 2. Repository Variables 設定

在 `Variables` 頁籤設定以下環境變數：

| 名稱 | 說明 | 預設值 | 範例 |
|------|------|--------|------|
| `BASE_URL` | AOA 系統網址 | `https://erpline.aoacloud.com.tw/` | `https://erpline.aoacloud.com.tw/` |
| `COMPANY_CODE` | 公司代碼 | 無 | `your_company_code` |
| `AOA_LAT` | 打卡地點緯度 | `25.0330` | `25.0330` |
| `AOA_LON` | 打卡地點經度 | `121.5654` | `121.5654` |
| `TZ` | 時區設定 | `Asia/Taipei` | `Asia/Taipei` |
| `LOCALE` | 語系設定 | `zh-TW` | `zh-TW` |

## 🔄 CI/CD Workflows

### 持續整合 (ci.yml)

- **觸發條件**：Pull Request 和推送到 main 分支
- **執行環境**：自有容器映像 `ghcr.io/liu-chun-wu/daily-tick-runner/runner:latest`
- **測試流程**：
  1. 環境設置與登入 (setup project)
  2. 通知功能測試 (notify project)
  3. Smoke 測試 (chromium-smoke project)
- **特色功能**：
  - 自動重試機制（每個測試最多 3 次）
  - 失敗時自動上傳測試報告和 traces
  - Discord 失敗通知
  - 使用預裝中文字型的容器確保測試穩定

### 容器映像建置 (build-image.yml)

- **功能**：建置並推送容器映像到 GitHub Container Registry
- **映像位置**：`ghcr.io/liu-chun-wu/daily-tick-runner/runner:latest`
- **包含內容**：
  - Playwright v1.49.0 及瀏覽器
  - 中文字型支援 (fonts-noto-cjk)
  - 時區設定 (Asia/Taipei)
  - 所有專案依賴

## 🔄 排程模式

### 測試排程（test-schedule.yml）

- **執行頻率**：預設關閉（可手動觸發）
- **執行環境**：自有容器映像
- **功能**：測試真實打卡操作
- **手動觸發參數**：
  - `test_type`：smoke（不點擊）或 click（真實點擊）
  - `action_type`：checkin（簽到）或 checkout（簽退）
  - `log_level`：DEBUG/INFO/WARN/ERROR
- **用途**：測試自動化流程是否正常

**注意**：選擇 click 模式會進行真實打卡！

### 正式排程（production-schedule.yml）

- **執行時間**：
  - 簽到：週一至週五 08:30 (台北時間)
  - 簽退：週一至週五 17:30 (台北時間)
- **功能**：智慧判斷打卡時機
- **狀態**：預設停用

## ⚙️ 啟用正式排程

1. **停用測試排程**：
   ```yaml
   # 在 .github/workflows/test-schedule.yml 中註解掉 schedule
   on:
     # schedule:
     #   - cron: '*/5 * * * *'
   ```

2. **啟用正式排程**：
   ```yaml
   # 在 .github/workflows/production-schedule.yml 中啟用 schedule
   on:
     schedule:
       # 週一到週五 早上 8:30 (UTC 23:30)
       - cron: '30 23 * * 1-5'
       # 週一到週五 下午 17:30 (UTC 08:30)  
       - cron: '30 8 * * 1-5'
   ```

## 🎯 手動執行

兩個 workflow 都支援手動觸發：

### 測試排程手動執行
- 進入 `Actions` > `測試排程 - 自動打卡`
- 點選 `Run workflow`
- 可選擇日誌等級（DEBUG/INFO/WARN/ERROR）

### 正式排程手動執行  
- 進入 `Actions` > `正式排程 - 自動打卡`
- 點選 `Run workflow`
- 選擇執行類型：
  - `checkin`：僅執行簽到
  - `checkout`：僅執行簽退  
  - `both`：執行簽到+簽退（間隔30秒）

## 📊 監控與除錯

### 執行結果通知

成功或失敗時會透過 Discord 發送通知（如果有設定 `DISCORD_WEBHOOK_URL`）：

- ✅ **成功通知**：顯示執行時間和類型
- ❌ **失敗通知**：包含 GitHub Actions 執行連結

### 查看執行記錄

1. 進入 GitHub 專案的 `Actions` 頁籤
2. 選擇對應的 workflow
3. 點選具體的執行記錄查看詳細日誌

### 下載執行結果（失敗時）

失敗時會自動上傳以下檔案：
- `test-results/`：測試結果和截圖
- `playwright-report/`：Playwright 報告
- `traces/`：執行軌跡檔案（可用 Playwright Trace Viewer 查看）

保存期限：
- 測試結果：7 天
- 軌跡檔案：3 天

## 🛠️ 本地測試

在部署到 GitHub Actions 前，建議先在本機測試：

```bash
# 安裝相依套件
npm install

# 執行登入設置
npm run test:setup

# 測試簽到（不會真的打卡）
npm run test:smoke

# 真實打卡測試（會真的打卡！）
npm run test:click
```

## ⚠️ 注意事項

1. **測試排程會進行真實打卡**，請在適當時間進行測試
2. **Secrets 設定錯誤會導致執行失敗**，請仔細檢查拼字和內容
3. **時區設定很重要**，確保 `TZ` 設定為 `Asia/Taipei`
4. **地理位置**：`AOA_LAT` 和 `AOA_LON` 需要符合公司打卡地點要求
5. **通知設定為可選**，沒有設定 Discord/LINE 不會影響打卡功能

## 🔧 故障排除

### 常見問題

**Q: 執行失敗，顯示登入錯誤**
- 檢查 `AOA_USERNAME` 和 `AOA_PASSWORD` 是否正確
- 確認 `COMPANY_CODE` 是否填寫正確

**Q: 地理位置驗證失敗**  
- 檢查 `AOA_LAT` 和 `AOA_LON` 座標是否正確
- 確認座標格式為小數點格式（如 `25.0330`）

**Q: 通知沒有收到**
- 檢查 `DISCORD_WEBHOOK_URL` 是否有效
- 確認 LINE Token 和 User ID 設定正確

**Q: 時間不對**
- 確認 `TZ` 設定為 `Asia/Taipei`
- GitHub Actions 使用 UTC 時間，workflow 會自動轉換

### 除錯步驟

1. 手動執行 workflow，選擇 `DEBUG` 日誌等級
2. 查看詳細執行日誌
3. 下載失敗時的截圖和軌跡檔案
4. 使用 `playwright show-trace test-results/**/*.zip` 分析執行過程

## 📈 效能調整

- **timeout-minutes**：測試排程 10 分鐘，正式排程 15 分鐘
- **workers**：設定為 1 避免並行衝突
- **trace**：設定為 `on` 記錄執行軌跡便於除錯
- **retention-days**：測試結果保存 7 天，軌跡檔案 3 天