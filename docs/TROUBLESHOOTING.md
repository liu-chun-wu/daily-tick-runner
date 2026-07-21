# 疑難排解

## Build & Smoke Test 顯示缺少 Secrets

確認名稱完全一致：

`BASE_URL`、`COMPANY_CODE`、`AOA_USERNAME`、`AOA_PASSWORD`、`AOA_LAT`、`AOA_LON`。

它們必須建立在 Fork 的 **Repository secrets**，不是上游 repository，也不是 Variables。workflow 只會列出缺少的名稱，不會顯示值。

## 設定在開啟瀏覽器前失敗

常見訊息：

- `BASE_URL must be a valid absolute URL`：需要含 `https://` 或 `http://`。
- `AOA_LAT must be a number between -90 and 90`。
- `AOA_LON must be a number between -180 and 180`。
- `LOG_LEVEL must be one of...`：只能使用 DEBUG、INFO、WARN、ERROR。

本機可先執行：

```bash
npm run test:list
```

## Production 找不到 runner:latest

Fork 第一次使用時，先手動執行 **Build & Smoke Test**。只有候選 SHA image 通過所有測試後才會建立或更新 `latest`。

也要確認 repository 的 **Actions → General → Workflow permissions** 沒有限制 package 操作，以及 GHCR package 允許此 repository 存取。

## 有 SHA image，但 latest 沒更新

這通常是預期的安全行為。檢查 `smoke` job：

- 缺少 Secret。
- 登入失敗或目標不可用。
- 安全 Smoke 找不到按鈕。
- 結果判斷測試失敗。
- workflow 被手動取消或被同 ref 的新版 run 取消。

`promote-latest` 只在所有前置 jobs 成功後執行。取消 run 不代表 trigger 異常，既有 `latest` 應保持原 digest。

## PR 沒有執行登入 Smoke

這是設計行為。Fork PR 不會取得 Repository Secrets，因此 PR 只建置 image 與執行無外部副作用的 `test:list`，不推 GHCR、不登入目標。

## 打卡顯示失敗、未知結果或 timeout

每個正式 run 只 click 一次，系統不會自動重試：

- `打卡失敗`：查看 failure screenshot 與 alert detail。
- 未知 title：查看 `*-unexpected-result.png`。
- 15 秒 timeout：確認目標服務是否延遲、頁面是否改版。

先到 run 的 artifacts 下載證據並確認目標系統實際紀錄，再決定是否手動重跑。不要因 workflow failure 直接假設打卡沒有發生。

## 排程沒有準時執行

確認：

1. `production-schedule.yml` 的兩個 placeholder 已替換。
2. `schedule` 區塊已取消註解。
3. 修改存在於預設分支。
4. 兩個 cron 不相同。
5. repository Actions 沒有被停用。

`timezone: Asia/Taipei` 免除 UTC 換算，但不能消除 GitHub 平台延遲。高負載時 schedule 可能延遲或被丟棄，整點尤其容易壅塞。若必須精準準時，應選擇具有執行保證的其他系統；本專案不提供主機排程替代方案。

## 本機 Playwright browser 版本不符

需要 Node.js 24+，package 與 browser image 必須為 1.61.0：

```bash
node --version
npx playwright --version
npx playwright install chromium
```

如果 lockfile 或 node_modules 不一致：

```bash
npm ci
```

Docker 可檢查：

```bash
docker build -f docker/Dockerfile -t daily-tick-runner:verify .
docker run --rm daily-tick-runner:verify node --version
docker run --rm daily-tick-runner:verify npx playwright --version
```

## Smoke 成功但沒有測試通知

這是 `npm test` 與 `npm run test:smoke` 的設計行為。要在 Smoke 全部成功後發送一則摘要，需在受控本機設定選填環境變數後明確執行：

```bash
npm run smoke:notify
```

若只想驗證通知 API，執行：

```bash
npm run notify:test
```

此命令會真的發送訊息。

`smoke:notify` 沒有設定任何通知平台時會失敗；Smoke 失敗時不會發送成功摘要。

## Docker Compose 找不到 .env

從 repository root 建立：

```bash
cp .env.example .env
docker compose config
```

Compose 直接讀取 `.env`。不要把檔案加入 Git 或複製進 Dockerfile。

## test-results 顯示 Permission denied

確認 `.env` 的 `LOCAL_UID` 與 `LOCAL_GID` 等於 `id -u`、`id -g`。修正後重新 build image；既有產物可由具有 sudo 權限的使用者執行 `chown` 修正擁有者，不需要刪除測試證據。

## 回報問題

請提供：

- workflow 名稱與 run URL。
- commit SHA 與失敗 job。
- Node／Playwright 版本。
- 已遮蔽的錯誤訊息。

不要提供密碼、token、cookie、storage state 或未遮蔽截圖。
