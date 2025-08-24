# 疑難排解指南

本文檔整理了使用 Daily Tick Runner 時常見的問題和解決方案。

## 📋 目錄

- [登入問題](#登入問題)
- [打卡問題](#打卡問題)
- [通知問題](#通知問題)
- [排程問題](#排程問題)
- [環境問題](#環境問題)
- [網路問題](#網路問題)
- [日誌除錯](#日誌除錯)

## 登入問題

### 登入失敗

**症狀**：測試執行時顯示登入失敗錯誤

**可能原因與解決方案**：

1. **帳號密碼錯誤**
   - 檢查 `AOA_USERNAME` 和 `AOA_PASSWORD` 是否正確
   - 確認沒有多餘的空格或特殊字元
   - 密碼中如有特殊字元，確保正確轉義

2. **公司代碼錯誤**
   - 確認 `COMPANY_CODE` 設定正確
   - 注意大小寫敏感

3. **Session 過期**
   ```bash
   # 清除舊的認證狀態
   rm -rf playwright/.auth
   # 重新執行設定測試
   npm run test:setup
   ```

4. **系統維護**
   - 檢查 AOA 系統是否在維護中
   - 嘗試手動登入確認系統狀態

### 多重驗證問題

**症狀**：需要輸入驗證碼或其他二次驗證

**解決方案**：
- 聯繫 IT 部門設定自動化帳號豁免
- 使用專用的服務帳號
- 考慮使用 API 而非網頁自動化

## 打卡問題

### 打卡按鈕無法點擊

**症狀**：找到按鈕但無法執行點擊動作

**可能原因與解決方案**：

1. **已經打過卡**
   - 系統會顯示「已簽到」或「已簽退」
   - 這是正常行為，不需處理

2. **時間限制**
   - 檢查是否在允許的打卡時間範圍內
   - 確認系統時區設定（應為 Asia/Taipei）

3. **地理位置驗證失敗**
   ```bash
   # 檢查座標設定
   echo "LAT: $AOA_LAT"
   echo "LON: $AOA_LON"
   ```
   - 確認座標格式為小數點格式（如 25.0330）
   - 座標需在公司允許的範圍內

4. **元素被遮擋**
   - 可能有彈出視窗或通知遮擋
   - 增加等待時間或處理彈出視窗

### 打卡後無反應

**症狀**：點擊打卡按鈕後頁面無變化

**解決方案**：
```typescript
// 增加等待時間
await page.waitForTimeout(3000);
// 檢查是否有錯誤訊息
const error = await page.locator('.error-message').textContent();
```

## 通知問題

### Discord 通知未收到

**症狀**：打卡成功但沒收到 Discord 通知

**檢查步驟**：

1. **Webhook URL 設定**
   ```bash
   # 測試 Webhook
   curl -X POST $DISCORD_WEBHOOK_URL \
     -H "Content-Type: application/json" \
     -d '{"content":"Test message"}'
   ```

2. **檢查 GitHub Actions 日誌**
   - 查看是否有發送通知的日誌
   - 確認沒有網路錯誤

3. **Discord 伺服器設定**
   - 確認 Webhook 沒有被刪除
   - 檢查頻道權限設定

### LINE 通知未收到

**症狀**：打卡成功但沒收到 LINE 通知

**檢查步驟**：

1. **Token 有效性**
   ```bash
   # 測試 LINE API
   curl -X POST https://api.line.me/v2/bot/message/push \
     -H "Authorization: Bearer $LINE_CHANNEL_ACCESS_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "to": "'$LINE_USER_ID'",
       "messages": [{"type": "text", "text": "Test"}]
     }'
   ```

2. **User ID 正確性**
   - 確認 User ID 格式正確（U開頭的字串）
   - 確認該用戶已加入官方帳號為好友

## 排程問題

### GitHub Actions 排程未執行

**症狀**：到了設定時間但 workflow 沒有觸發

**可能原因**：

1. **GitHub Actions 延遲**
   - 免費版可能會有 5-15 分鐘延遲
   - 高峰時段延遲更明顯
   - 解決方案：使用本地排程器

2. **時區設定錯誤**
   ```yaml
   # 檢查 cron 時間（UTC）
   # 台北 8:30 = UTC 0:30
   - cron: '30 0 * * 1-5'
   ```

3. **Workflow 被停用**
   - 60天未活動的 repo 會自動停用排程
   - 手動執行一次以重新啟用

### 本地排程器未執行

**症狀**：macOS 本地排程沒有在預定時間執行

**檢查步驟**：

1. **檢查 launchd 狀態**
   ```bash
   launchctl list | grep daily-tick-runner
   ```

2. **檢查系統日誌**
   ```bash
   log show --predicate 'subsystem == "com.apple.xpc.launchd"' --last 1h
   ```

3. **權限問題**
   - 系統偏好設定 → 安全性與隱私 → 完全磁碟存取
   - 確保 Terminal 有權限

4. **電腦休眠**
   - 確保電腦不會自動休眠
   - 系統偏好設定 → 節能 → 防止電腦自動進入睡眠

## 環境問題

### Playwright 安裝失敗

**症狀**：無法安裝或執行 Playwright

**解決方案**：

```bash
# 清理並重新安裝
rm -rf node_modules
npm cache clean --force
npm install
npx playwright install chromium
```

### 中文顯示亂碼

**症狀**：截圖中的中文字顯示為方塊或亂碼

**解決方案**：

1. **本地環境**
   ```bash
   # macOS
   brew install font-noto-cjk
   
   # Linux
   sudo apt-get install fonts-noto-cjk
   ```

2. **Docker/CI 環境**
   - 已在 Dockerfile 中包含中文字體
   - 確認使用正確的基礎映像

### TypeScript 錯誤

**症狀**：型別檢查失敗

**解決方案**：
```bash
# 更新型別定義
npm install --save-dev @types/node@latest
npx tsc --noEmit
```

## 網路問題

### 連線逾時

**症狀**：頁面載入超時或請求失敗

**解決方案**：

1. **增加超時時間**
   ```typescript
   // playwright.config.ts
   use: {
     navigationTimeout: 60000,  // 60秒
     actionTimeout: 30000,      // 30秒
   }
   ```

2. **使用重試機制**
   ```typescript
   // 已內建三層重試
   retries: process.env.CI ? 2 : 1
   ```

3. **檢查代理設定**
   ```bash
   # 如果在公司網路需要代理
   export HTTP_PROXY=http://proxy.company.com:8080
   export HTTPS_PROXY=http://proxy.company.com:8080
   ```

### SSL 憑證錯誤

**症狀**：SSL certificate verify failed

**解決方案**（僅開發環境）：
```typescript
// playwright.config.ts
use: {
  ignoreHTTPSErrors: true,  // 僅在測試環境使用
}
```

## 日誌除錯

### 啟用詳細日誌

```bash
# Playwright debug 模式
DEBUG=pw:api npx playwright test

# 設定日誌等級
LOG_LEVEL=DEBUG npm run test

# GitHub Actions 日誌
# 在 workflow 中設定
env:
  LOG_LEVEL: DEBUG
```

### 查看執行追蹤

```bash
# 產生追蹤檔案
npx playwright test --trace on

# 查看追蹤
npx playwright show-trace test-results/**/trace.zip
```

### 本地排程器日誌

```bash
# 查看最新日誌
./manage logs latest

# 搜尋錯誤
./manage logs search ERROR

# 即時監控
./manage logs monitor
```

### GitHub Actions 日誌

1. 進入 Actions 頁面
2. 選擇失敗的執行
3. 展開步驟查看詳細日誌
4. 下載 artifacts 查看截圖和追蹤

## 常見錯誤代碼

| 錯誤代碼 | 說明 | 解決方案 |
|---------|------|----------|
| `ETIMEDOUT` | 連線逾時 | 增加超時時間或檢查網路 |
| `ECONNREFUSED` | 連線被拒絕 | 檢查目標服務是否正常 |
| `ERR_NAME_NOT_RESOLVED` | DNS 解析失敗 | 檢查網址是否正確 |
| `NS_ERROR_NET_RESET` | 網路重置 | 重試或檢查防火牆設定 |
| `TARGET_CLOSED` | 頁面被關閉 | 檢查頁面生命週期管理 |

## 效能優化建議

### 加快執行速度

1. **重用認證狀態**
   ```typescript
   test.use({ storageState: 'playwright/.auth/user.json' });
   ```

2. **停用不必要的資源**
   ```typescript
   await route.abort();  // 阻擋圖片、字體等
   ```

3. **平行執行測試**
   ```typescript
   workers: process.env.CI ? 2 : 4
   ```

### 減少失敗率

1. **使用穩定的選擇器**
   - 優先使用 `getByRole`、`getByLabel`
   - 避免使用動態 ID 或索引

2. **適當的等待策略**
   - 使用 `waitForLoadState('networkidle')`
   - 避免固定 `waitForTimeout`

3. **錯誤恢復機制**
   - 實作 try-catch 處理預期錯誤
   - 使用 fixtures 管理測試狀態

## 需要更多協助？

如果以上方案都無法解決您的問題：

1. **查看詳細日誌**
   - 啟用 DEBUG 模式
   - 收集完整錯誤訊息

2. **提交 Issue**
   - 前往 [GitHub Issues](https://github.com/YOUR_USERNAME/daily-tick-runner/issues)
   - 提供錯誤日誌和重現步驟

3. **社群支援**
   - [Playwright Discord](https://discord.gg/playwright)
   - [GitHub Discussions](https://github.com/microsoft/playwright/discussions)