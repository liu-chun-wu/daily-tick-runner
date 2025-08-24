# 容器化 CI/CD 設置說明

## 概覽

本專案已完成容器化 CI/CD 設置，確保本地開發、CI 測試、和生產排程在相同環境中執行。

## 架構組成

### 1. Docker 基礎設施
- **Dockerfile** (`docker/Dockerfile`): 基於 Playwright 官方映像，預裝中文字型和台北時區
- **.dockerignore**: 優化構建上下文，排除不必要的文件

### 2. GitHub Actions 工作流程

#### 構建映像 (`build-image.yml`)
- 自動構建並推送 Docker 映像到 GitHub Container Registry (GHCR)
- 觸發條件：推送到 main 分支或手動觸發
- 映像位置：`ghcr.io/liu-chun-wu/daily-tick-runner/runner:latest`

#### CI 測試 (`ci.yml`)
- 在容器中執行所有測試
- 包含 npm 快取和並發控制
- 自動取消舊的執行（當有新的 commit）

#### 安全掃描 (`codeql.yml`)
- 執行 JavaScript/TypeScript 安全掃描
- 每週一自動執行，或在 PR/Push 時觸發

#### 依賴更新 (`dependabot.yml`)
- 自動檢查 npm 和 GitHub Actions 的更新
- 將小版本和補丁更新分組

### 3. 已更新的排程工作流程
- **test-schedule.yml**: 測試環境排程，已容器化
- **production-schedule.yml**: 生產環境排程，已容器化

## 本地開發

### 使用 Docker Compose

```bash
# 構建本地映像
docker-compose build

# 啟動開發容器
docker-compose up app

# 在容器中執行命令
docker-compose run app npm test

# 運行測試服務
docker-compose up test
```

### 直接使用 Docker

```bash
# 構建映像
docker build -f docker/Dockerfile -t daily-tick-runner:local .

# 運行容器
docker run --rm -it -v "$PWD":/app -w /app daily-tick-runner:local bash

# 在容器內執行測試
npm ci
npx playwright test
```

## 環境變數配置

創建 `.env` 文件（不要提交到版本控制）：

```env
AOA_USERNAME=your_username
AOA_PASSWORD=your_password
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
LINE_CHANNEL_ACCESS_TOKEN=your_token
LINE_USER_ID=your_user_id
```

## GitHub 設置要求

### Secrets（敏感信息）
- `AOA_USERNAME`: AOA 系統用戶名
- `AOA_PASSWORD`: AOA 系統密碼
- `DISCORD_WEBHOOK_URL`: Discord 通知 webhook
- `LINE_CHANNEL_ACCESS_TOKEN`: LINE 通知 token
- `LINE_USER_ID`: LINE 用戶 ID

### Variables（非敏感配置）
- `BASE_URL`: 基礎 URL（默認：https://erpline.aoacloud.com.tw/）
- `COMPANY_CODE`: 公司代碼（默認：CYBERBIZ）
- `AOA_LAT`: 緯度（默認：25.080869）
- `AOA_LON`: 經度（默認：121.569862）
- `TZ`: 時區（默認：Asia/Taipei）
- `LOCALE`: 語言設置（默認：zh-TW）

## 首次部署步驟

1. **推送代碼到 main 分支**
   - 這會觸發 `build-image.yml` 構建並推送映像到 GHCR

2. **配置 GitHub Secrets 和 Variables**
   - 在 Settings → Secrets and variables → Actions 中配置

3. **啟用工作流程**
   - CI 會在 PR 和推送時自動執行
   - 排程工作流程需要取消註解 schedule 部分

4. **（可選）啟用安全功能**
   - 在 Settings → Security → Code scanning 啟用 Default setup
   - Dependabot 會自動開始工作

## 優勢

1. **環境一致性**: 本地、CI、CD 使用相同容器環境
2. **快速構建**: npm 快取減少安裝時間
3. **自動化維護**: Dependabot 自動更新依賴
4. **安全掃描**: CodeQL 定期檢查安全問題
5. **並發控制**: 避免重複執行浪費資源

## 故障排除

### 映像構建失敗
- 檢查 Dockerfile 語法
- 確認 package-lock.json 存在且有效

### 容器權限問題
- 確保文件權限正確
- 檢查 GITHUB_TOKEN 是否有 packages:write 權限

### 測試失敗
- 查看上傳的 artifacts（test-results, traces）
- 檢查環境變數是否正確配置

## 維護建議

1. 定期更新基礎映像版本（Playwright）
2. 監控 Dependabot PR 並及時合併
3. 查看 CodeQL 安全報告
4. 定期檢查 GitHub Actions 使用量