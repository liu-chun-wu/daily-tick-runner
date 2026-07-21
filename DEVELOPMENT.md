# 開發與測試

## 必要工具

- Node.js 24+
- npm（使用 repository 內的 `package-lock.json`）
- Docker（要驗證正式 image 時）

Playwright package 與 Docker image 必須同為 `1.61.0`。升級時要在 `package.json` 與 `docker/Dockerfile` 同一個 commit 更新，並重新產生 lockfile。

## 本機設定

```bash
cp .env.example .env
npm ci
```

`.env` 必須提供：

```dotenv
BASE_URL=https://attendance.example.com/
COMPANY_CODE=your_company_code
AOA_USERNAME=your_username
AOA_PASSWORD=your_password
AOA_LAT=0
AOA_LON=0
```

`TZ`、`LOCALE`、`LOG_LEVEL` 可省略，預設依序為 `Asia/Taipei`、`zh-TW`、`INFO`。日誌只接受 `DEBUG`、`INFO`、`WARN`、`ERROR`。

設定在載入 `playwright.config.ts` 時驗證。URL 必須是完整 HTTP/HTTPS URL，緯度需在 -90 到 90，經度需在 -180 到 180；因此錯誤會在開啟瀏覽器與登入前出現。

## 命令

| 命令 | 安全層級 | 用途 |
| --- | --- | --- |
| `npm run test:list` | 無外部操作 | 驗證設定與測試載入 |
| `npm run test:result` | 無外部操作 | 模擬結果與單次 click |
| `npm test` | 登入，不打卡 | 安全 Smoke |
| `npm run test:smoke` | 登入，不打卡 | 與 `npm test` 相同 |
| `npm run smoke:notify` | 登入並發通知，不打卡 | 全部 Smoke 成功後發一則摘要 |
| `npm run test:setup` | 登入，不打卡 | 只建立 auth state |
| `npm run notify:test` | 會發送訊息 | 明確測試通知 API |
| `npm run attendance:checkin` | 會真實簽到 | 一次 click、無自動 retry |
| `npm run attendance:checkout` | 會真實簽退 | 一次 click、無自動 retry |
| `npm run test:ui` | 依選取測試而定 | Playwright UI |
| `npm run test:debug` | 依選取測試而定 | Playwright debug |

不要建立「跑全部 project」的便利命令，因為它很容易意外包含真實打卡或通知。

`smoke:notify` 是明確的手動 opt-in。`Build & Smoke Test` 的手動 dispatch 預設啟用此模式；push 與 PR 一律不發通知。沒有完整通知設定、通知 API 失敗、Smoke 本身失敗或 timeout 時，通知驗收會失敗且不推進 `latest`。

## 結果判斷測試

`tests/check/attendance-result.spec.ts` 必須涵蓋：

1. `打卡成功` 回傳 `success`。
2. `打卡失敗` 回傳 `failure`。
3. 未知 title 拋出例外。
4. 沒有 alert 時 timeout。
5. 每個案例的按鈕 click count 都等於 1。

變更正式操作時，先跑：

```bash
npm run test:result
npm run test:list
```

不要在自動測試中執行真實 attendance commands。

## Docker

本機安全 Smoke：

```bash
docker compose build
docker compose run --rm smoke
```

`docker-compose.yml` 透過 `env_file: .env` 注入設定。建置 context 由 `.dockerignore` 排除 Secrets、`playwright/.auth`、`test-results`、`playwright-report` 與 screenshots。

Compose 預設以 `LOCAL_UID=1000`、`LOCAL_GID=1000` 寫入 bind mounts，避免產物在 WSL 變成 `root` 或 `nobody`。若 `id -u`／`id -g` 不是 1000，請在 `.env` 改成實際值。

驗證版本：

```bash
docker build -f docker/Dockerfile -t daily-tick-runner:verify .
docker run --rm daily-tick-runner:verify node --version
docker run --rm daily-tick-runner:verify npx playwright --version
```

`npm ci` 在官方 Playwright image 中設有 `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1`，直接使用 image 內相同版本的 Chromium。

## Pull request 與 CI

Pull request workflow 不會收到 Fork Repository Secrets，所以只能：

- 建置本地、不推送的 image。
- 以假值載入 Playwright 設定並執行 `test:list`。
- 不登入目標、不呼叫通知、不寫 GHCR。

`main` push 與手動 dispatch 才會建置 SHA image、執行整合 Smoke，成功後推進 `latest`。修改文件也會觸發完整流程。

提交前建議執行：

```bash
npm ci
npm run test:list
npm run test:result
```

若有 Docker，另外檢查 image 內容與版本。真實 Smoke 需要授權帳號與可存取的目標環境。

## 新增測試

- 安全 UI 檢查使用 `@smoke`，不可 click 簽到／簽退或呼叫通知。
- 真實操作只能使用 `@click` 且 project retries 必須維持 0。
- 純本機結果測試使用 `@result`。
- 通知 API 測試使用 `@notify`。
- 不要在測試檔、fixtures、截圖或 trace 寫入憑證。

## 文件治理

- 部署行為只在 [DEPLOYMENT.md](DEPLOYMENT.md) 維護。
- [ARCHITECTURE.md](ARCHITECTURE.md) 只描述已實作元件。
- 工作流程、命令或 Secret 名稱變動時，同步 README、本文件、Security、Troubleshooting 與 `CLAUDE.md`。
