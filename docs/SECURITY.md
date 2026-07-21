# 安全指南

## 使用範圍

只能對你已獲明確授權的帳號、公司與出勤系統使用本專案。自動化不會取代組織的出勤政策、地理位置規範或人工覆核責任。

## Secrets

GitHub 正式環境的六個目標設定都必須放在 Repository Secrets：

- `BASE_URL`
- `COMPANY_CODE`
- `AOA_USERNAME`
- `AOA_PASSWORD`
- `AOA_LAT`
- `AOA_LON`

Discord 與 LINE 設定也是 Secrets，但為選填。不要使用 GitHub Variables 放目標網址、公司代碼或座標；不要把 `.env`、authentication state、trace、影片或含敏感畫面的 screenshot commit 到 Git。

本機請從 `.env.example` 複製 `.env`，只存於受控裝置。憑證外洩時應立即在來源系統輪替，不能只刪除 Git commit。

## GitHub Token 與 GHCR

Workflows 使用同一 repository 自動提供的 `GITHUB_TOKEN`：

- Build 只有 `packages: write` 與 `contents: read`。
- Candidate Smoke、Smoke Latest 與 Production 只有 `packages: read` 與 `contents: read`。
- 不需要建立長效 PAT。

Image 名稱由 Fork 的 `github.repository` 動態產生。若 GHCR package 權限被手動改成繼承以外的設定，應確認只有預期 repository 能讀寫。

## Image 供應鏈

- Node.js 必須為 24+。
- `@playwright/test` 與官方 Docker image 固定為相同的 `1.61.0`。
- 使用 `npm ci` 與 lockfile，不在 workflow 動態選擇新版套件。
- `.dockerignore` 排除 `.env*`（範例除外）、`playwright/.auth`、測試報告、trace、影片與 screenshots。
- 候選 `sha-* ` image 通過安全 Smoke 後，才把相同 digest 推進 `latest`。

不要把未知來源 image 改標為 `latest`，也不要讓 Production 接受任意 image input。

## 外部副作用邊界

`npm test` 與 `npm run test:smoke` 可以登入，但不可 click 出勤按鈕、不可發通知。`npm run test:list` 與 `npm run test:result` 完全在本機執行。

只有以下命令具有明確副作用：

- `npm run attendance:checkin`
- `npm run attendance:checkout`
- `npm run smoke:notify`
- `npm run notify:test`

真實 click project 的 Playwright retries 是 0，Production workflow 也沒有 retry wrapper。失敗、未知結果或 timeout 後不得自動重按；只有使用者檢視證據後能再手動執行。

## 日誌與 artifacts

- 不輸出 Secret 值，只輸出缺少的 Secret 名稱。
- 失敗 artifacts 可能含內部頁面、姓名、時間或錯誤文字，下載與分享前要檢查並遮蔽。
- CI artifacts 保留 7 天，正式失敗證據保留 14 天。
- authentication state 只存在單次 container，沒有掛載回 host，也不會上傳。
- 避免將 `LOG_LEVEL` 設成 `DEBUG` 作為長期排程預設。

## Pull request

Fork PR 不會取得 Repository Secrets。PR job 只能用假值建置並執行 `test:list`；它不得登入 GHCR、登入目標或呼叫通知 API。Review workflow 變更時要特別檢查：

- 是否新增 `pull_request_target`。
- 是否把 Secrets 傳給不受信任程式碼。
- 是否提高 `GITHUB_TOKEN` 權限。
- 是否加入會執行 attendance 或 notification 的命令。

## 通知

通知是選用且非打卡結果的唯一證據。手動 `Smoke Latest Image` 的通知驗收只把 Secrets 注入通知 step，並要求摘要文字與一張成功 Smoke 截圖都送達；push、PR 與 Build workflow 不接收通知 Secrets。圖片先上傳至設定的 Discord webhook，LINE 使用該 Discord CDN URL，因此截圖可能包含的內部資訊會同時進入所設定的平台。正式打卡的成功通知仍為 best effort，通知失敗不應觸發第二次打卡。Discord workflow-failure 通知也不會覆蓋原始失敗原因。

## 通報

安全問題請使用 repository 的私人安全回報機制（若已啟用），或聯絡維護者。不要在公開 Issue 貼出 Secret、token、cookie、authentication state、完整 trace 或未遮蔽的出勤畫面。

通報應包含受影響版本、重現步驟、影響與已遮蔽的證據。
