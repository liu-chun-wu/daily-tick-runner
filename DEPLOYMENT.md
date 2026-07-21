# 部署與 Fork 初始化

本文件是 Daily Tick Runner 唯一的部署來源。專案只支援 GitHub Actions；不提供本機、macOS 或主機排程器。

## 1. Fork 與啟用 Actions

1. 在 GitHub Fork repository。
2. 開啟 Fork 的 **Actions** 頁並同意啟用 workflows。
3. 確認 Fork 的預設分支是 `main`。
4. 尚未建立 `runner:latest` 前，不要執行 `Production Attendance`。

Fork 本身不保證會觸發初次建置，因此初始化必須手動執行 `Build & Promote Image`。

## 2. 設定 Repository Secrets

到 **Settings → Secrets and variables → Actions → Repository secrets** 建立：

| 名稱 | 必填 | 驗證 |
| --- | --- | --- |
| `BASE_URL` | 是 | 完整的 HTTP/HTTPS URL |
| `COMPANY_CODE` | 是 | 不可空白 |
| `AOA_USERNAME` | 是 | 不可空白 |
| `AOA_PASSWORD` | 是 | 不可空白 |
| `AOA_LAT` | 是 | -90 到 90 |
| `AOA_LON` | 是 | -180 到 180 |
| `DISCORD_WEBHOOK_URL` | 否 | Discord webhook URL |
| `LINE_CHANNEL_ACCESS_TOKEN` | 否 | LINE token |
| `LINE_USER_ID` | 否 | LINE user ID |

所有目標相關設定都必須是 Secrets，不使用 GitHub Variables，也沒有真實網址、公司或座標 fallback。

Smoke 圖片通知必須設定 `DISCORD_WEBHOOK_URL`。LINE 圖片訊息需要公開 HTTPS URL，因此啟用 LINE 時會沿用 Discord 上傳後的 CDN URL；LINE 的兩個 Secrets 仍是選填，但必須成對設定。

## 3. 初始化與 image 生命週期

在 **Actions → Build & Promote Image → Run workflow** 執行：

1. workflow 由 `github.repository` 轉成小寫，得到 `ghcr.io/<fork-owner>/<repo>/runner`。
2. 使用目前 commit 建置並推送 `runner:sha-<commit>`。
3. 拉回該 SHA image，先執行 `test:list` 與本機結果判斷測試。
4. 使用同一 image 登入目標並執行安全 Smoke；不點打卡按鈕，也不發送通知。
5. 全部通過後，才將該 image 追加 `runner:latest` tag。

GHCR 的 push 與 pull 使用 workflow 內建的 `GITHUB_TOKEN`，同一 Fork 不需要 PAT。Docker image 的 OCI source label 會連結回該 Fork，方便 GitHub Packages 套用 repository 權限。

### 取消與失敗

- 候選 SHA image 可能已存在，便於稽核或除錯。
- Smoke、Secret 缺少或 workflow 被取消時，promotion job 不會執行。
- 已存在的 `latest` 保持不變，因此正式流程不會自動改用未測試版本。
- 使用者手動取消的 run 屬於取消，不代表 workflow trigger 異常。

`main` 的每次 push 都會執行，包含只有 Markdown 或文件變更的 commit；沒有 paths 排除，且不發送 Smoke 通知。Pull request 只建置不發佈的 image 並載入測試設定，因為 Fork PR 不會取得 Repository Secrets。

## 4. 手動驗證目前的 latest

在 **Actions → Smoke Latest Image → Run workflow** 執行：

1. workflow 拉取 Fork 自己的 `runner:latest`，並解析成固定的 digest。
2. 以該 digest 執行 `test:list`、結果判斷測試與安全 Smoke；整次 run 不會因 `latest` 被同時更新而換版本。
3. 通知選項預設啟用。全部 Smoke 通過後，Discord 會收到摘要文字與一張 Smoke 截圖；有完整 LINE Secrets 時，LINE 也會收到相同文字與圖片。
4. workflow 不 checkout、不建置、不推送 image。成功、失敗或取消都不會改動 `latest`。

通知或圖片 API 拒絕、找不到 Smoke 截圖，或只設定 LINE 而沒有 `DISCORD_WEBHOOK_URL` 時，通知驗收會失敗。若只想驗證登入與頁面，可在啟動 workflow 時關閉通知選項。

## 5. 手動執行正式打卡

1. 確認最新一次 `Build & Promote Image` 與 `Smoke Latest Image` 成功。
2. 開啟 **Actions → Production Attendance → Run workflow**。
3. 選擇 `checkin` 或 `checkout`，並選擇日誌等級。
4. 確認 run 結果與 artifacts；有設定通知時，成功後才發送成功通知。

正式 workflow 不 checkout、不執行 `npm ci`，而是拉取 Fork 自己最後通過測試的 `runner:latest`。

真實按鈕只 click 一次：

| 畫面結果 | 行為 |
| --- | --- |
| `打卡成功` | 回傳成功、保存截圖、發送已設定的成功通知 |
| `打卡失敗` | 保存錯誤文字與截圖，workflow 失敗，不重按 |
| 15 秒內沒有結果 | 保存證據並拋出 timeout，不重按 |
| 未知 alert 標題 | 保存證據並失敗，不重按 |

要重新執行真實打卡，必須由使用者評估後再次手動啟動 workflow。

## 6. 啟用選用排程

排程預設停用。編輯 [production-schedule.yml](.github/workflows/production-schedule.yml)：

1. 將兩個 placeholder 改為五欄 cron，例如自己的上班與下班規則：

```yaml
env:
  CHECKIN_CRON: &checkin_cron 'YOUR_CHECKIN_CRON'
  CHECKOUT_CRON: &checkout_cron 'YOUR_CHECKOUT_CRON'
```

2. 取消下列區塊註解：

```yaml
schedule:
  - cron: *checkin_cron
    timezone: Asia/Taipei
  - cron: *checkout_cron
    timezone: Asia/Taipei
```

3. Push 到預設分支。此 push 也會完整建置、Smoke 並在成功後更新 `latest`。

workflow 會將觸發它的 cron expression 與兩個 anchor 值精確比對，因此不依執行當下的時鐘猜測簽到或簽退。兩個 cron 不可相同。

GitHub Actions schedule 只會從預設分支執行。即使使用 `timezone: Asia/Taipei`，排程仍可能因平台負載延遲；GitHub 也說明高負載時排隊工作可能被丟棄。請避開整點，且不要把此方案當成硬即時排程。

## 7. 權限與驗收

Workflows 使用最小權限：

- Build job：`contents: read`、`packages: write`
- Candidate Smoke job：`contents: read`、`packages: read`
- Smoke Latest：`contents: read`、`packages: read`，沒有 package 寫入權限
- Production：`contents: read`、`packages: read`

Fork 初始化驗收：

- `Build & Promote Image` 有 `sha-<commit>` tag。
- 候選 Smoke 成功後 `latest` 指向相同 digest。
- 手動取消或製造安全的 Smoke 失敗時，原 `latest` digest 不變。
- `Smoke Latest Image` 顯示固定的 digest，並且沒有 build 或 push step。
- 啟用通知時，Discord 收到文字與 PNG；有設定 LINE 時也收到文字與圖片。
- `Production Attendance` 顯示拉取的是 Fork 自己的 GHCR 路徑。
- schedule 保持註解，直到自行填入 cron。

參考：[GitHub Packages workflow authentication](https://docs.github.com/en/packages/managing-github-packages-using-github-actions-workflows/publishing-and-installing-a-package-with-github-actions)、[Secrets 限制](https://docs.github.com/en/code-security/reference/secret-security/secret-types)、[schedule 行為](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule)。
