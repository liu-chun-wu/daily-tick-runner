# 1) 整個流程怎麼運作（從觸發→打卡→證據→回報）

**(A) 觸發與排程**

* 來源：定時（cron）、手動 CLI、或外部 webhook。
* 生產環境用 APScheduler `CronTrigger(timezone="Asia/Taipei", jitter=… )`，同時指定**時區**與**抖動**，避免整點風暴。([APScheduler][1])

**(B) 護欄與設定載入**

* 讀取 12-Factor 的**環境化設定**（帳密、URL、地理座標、閾值），而不是硬編在程式與 repo。([十二因素應用程式][2])
* 執行「政策檢查」：是否在允許的時間窗／是否需要人工覆核（假日、請假日就停用）。

**(C) 啟動瀏覽器執行環境**

* 以 **Playwright** 啟動測試用瀏覽器 Context，設定：`timezoneId='Asia/Taipei'`、`locale='zh-TW'`、（若系統需要）`permissions=['geolocation']` 與 `geolocation`。這些都能在 config 的 `use` 區塊統一配置。([playwright.dev][3])
* 若在容器或 CI，使用官方 **Playwright Docker** 映像，以確保所有瀏覽器依賴一致。([playwright.dev][4], [Docker Hub][5])

**(D) 認證與會話**

* 能重用會話就絕不重複登入：把一次成功登入後的 cookie／localStorage 存成 `storageState`，下次啟動直接載入（記得當成敏感檔處理）。([playwright.dev][6])
* 首次登入或狀態失效時，走「登入流程」Page Object，成功後重新導出 `storageState`。([playwright.dev][7])

**(E) 導航與操作**

* **選擇器策略**：優先 `getByRole`/可存取性屬性 → `getByTestId`（自訂如 `data-pw`）→ 穩定 CSS，盡量避免脆弱 XPath。`testIdAttribute` 可在 config 設定。([playwright.dev][8], [Stack Overflow][9])
* **等待策略**：Playwright 內建 **auto-waiting** 與 actionability 檢查，不用硬 `sleep`；若你用 Selenium，官方直接警告**不要混用隱式與顯式等待**。([playwright.dev][10], [Selenium][11])

**(F) 驗證與證據**

* 使用 Web-first Assertions（`expect(locator).toHaveText(...)` 等），會自動重試直到條件成立或逾時。([playwright.dev][12])
* 失敗時**截圖／錄影／Trace**：建議 `trace: 'on-first-retry'`，收斂容量但保留可回放性；HTML Reporter 會產出自包含報表。([playwright.dev][13])

**(G) 失敗復原與重試**

* 區分短暫錯誤（網路／渲染慢）與邏輯錯誤（DOM 變更、權限失敗）。短暫錯誤走 **tenacity** 指數回退（上限封頂，限次）。([tenacity.readthedocs.io][14])
* 任務層重試＋Playwright 測試層 retries 搭配使用（例如只在 CI 開啟 2 次重試）。([playwright.dev][8])

**(H) 回報、審計與清理**

* 結構化日誌＋指標（成功/失敗/重試次數/耗時），並**避免在日誌中留下敏感資訊（token、cookie、個資）**；這是 OWASP Logging Cheat Sheet 的明確建議。([cheatsheetseries.owasp.org][15], [owasp-top-10-proactive-controls-2018.readthedocs.io][16])
* 產物（HTML 報表、trace、screenshot）上傳到 CI artifacts 供事後檢視。([playwright.dev][17])

---

# 2) 開發步驟的最佳實踐（你可以照這個順序落地）

**Step 0 — 合規對齊與整備**

* 確認站方/公司政策允許自動化；需求中若涉及 API 互動，實作「**冪等鍵**」避免重複提交（業務層面的「打卡意圖」也建議做冪等）。可參考 Stripe 的設計與文章。([docs.stripe.com][18], [stripe.com][19])

**Step 1 — 選框架與專案骨架**

* 選 **Playwright** 為主：有 locator、自動等待與 trace 等穩定性優勢；搭**Page Object Model** 來集中管理選擇器與流程，提升可維護性。([playwright.dev][20], [Selenium][21])
* 初始目錄：`automation/pages`（POM）、`core/flows`（登入/打卡流程）、`observability/`、`config/`、`apps/scheduler`。

**Step 2 — 設定與敏感資訊**

* 一律走 **環境變數與秘密管理**（Vault/KMS/.env），不要把帳密或 token 放進 repo；12-Factor 對此有明確原則，OWASP 秘密管理清單也提供控管準則。([十二因素應用程式][2], [cheatsheetseries.owasp.org][22])

**Step 3 — Playwright 基礎配置**

* `playwright.config`：`testIdAttribute`、`storageState`、`timezoneId`、`locale`、（需要時）`permissions` 與 `geolocation`、`trace: 'on-first-retry'`、`screenshot: 'only-on-failure'`。([playwright.dev][3])

**Step 4 — 選擇器治理**

* 優先 `getByRole`/label 這類**使用者可見**的 locator；沒有語義時再退回 `getByTestId`（配置自訂屬性名）。這是 Playwright 官方的建議路線。([playwright.dev][8])

**Step 5 — 等待與抗脆弱**

* Playwright 依賴 auto-waiting + Web-first Assertions；嚴禁廣撒固定 `sleep`。若 Selenium 場景，**不要混用**隱式/顯式等待（官方文件直接警告）。([playwright.dev][10], [Selenium][11])

**Step 6 — 認證與會話復用**

* 建立一次性登入流程（POM + 專用測帳），成功後導出 `storageState`；在 CI 與本地都重用，失效再自動刷新。([playwright.dev][6])

**Step 7 — 觀測性與證據**

* 打開 **Trace Viewer** 與 HTML Reporter；CI 工作流把 `playwright-report/` 整個上傳成 artifacts，讓你能離線回放失敗現場。([playwright.dev][13])

**Step 8 — 重試與回退**

* 對外部不穩定操作以 **tenacity** 做「指數回退 + 次數上限」；避免「無限自我放大」重試。([tenacity.readthedocs.io][23])

**Step 9 — 容器化與 CI**

* 用官方 **Playwright Docker** 基底，在 GitHub Actions（或任一 CI）直接執行；善用**並行與 sharding** 縮短時間。([playwright.dev][4])

**Step 10 — 排程上線**

* APScheduler 設 `CronTrigger(timezone=…, jitter=…)`，按場景設併發限制與互斥鎖，避免同帳號重入。([APScheduler][1])

**Step 11 — 安全與日誌**

* 依 **OWASP Logging Cheat Sheet**，避免在日誌/報表/trace 中曝露密碼、token、個資；對 artifacts 設存取權限與保留期。([cheatsheetseries.owasp.org][15])

**Step 12 — 維運與調整**

* 針對 DOM 變更頻繁區塊，建立「選擇器斷裂」檢測（每日 smoke run）；持續檢視 trace 報告來調整等待、補上更穩定的 locator 或 test id。([playwright.dev][13])

---

## 小總結（可以直接抄用的最小配置要點）

* **Playwright**：POM、`getByRole`/`getByTestId`、auto-waiting、Web-first Assertions。([playwright.dev][7])
* **時間/地理**：`timezoneId='Asia/Taipei'` +（必要時）`geolocation`/`permissions`。([playwright.dev][24])
* **證據**：`trace: 'on-first-retry'`、HTML reporter artifact。([playwright.dev][13])
* **排程/重試**：APScheduler + tenacity 的指數回退。([APScheduler][1], [tenacity.readthedocs.io][23])
* **安全**：12-Factor（環境化設定）、OWASP Secrets/Logging。([十二因素應用程式][2], [cheatsheetseries.owasp.org][22])
* **CI/Docker**：官方 Playwright Docker + 並行/分片。([playwright.dev][4])

[1]: https://apscheduler.readthedocs.io/en/3.x/modules/triggers/cron.html?utm_source=chatgpt.com "apscheduler.triggers.cron - Read the Docs"
[2]: https://12factor.net/config?utm_source=chatgpt.com "Store config in the environment"
[3]: https://playwright.dev/docs/test-use-options?utm_source=chatgpt.com "Test use options"
[4]: https://playwright.dev/docs/docker?utm_source=chatgpt.com "Docker"
[5]: https://hub.docker.com/r/microsoft/playwright?utm_source=chatgpt.com "microsoft/playwright - Docker Image"
[6]: https://playwright.dev/docs/auth?utm_source=chatgpt.com "Authentication"
[7]: https://playwright.dev/docs/pom?utm_source=chatgpt.com "Page object models"
[8]: https://playwright.dev/docs/best-practices?utm_source=chatgpt.com "Best Practices"
[9]: https://stackoverflow.com/questions/75151754/how-can-i-select-an-element-by-id?utm_source=chatgpt.com "How can I select an element by Id? - playwright"
[10]: https://playwright.dev/docs/actionability?utm_source=chatgpt.com "Auto-waiting"
[11]: https://www.selenium.dev/documentation/webdriver/waits/?utm_source=chatgpt.com "Waiting Strategies"
[12]: https://playwright.dev/docs/test-assertions?utm_source=chatgpt.com "Assertions"
[13]: https://playwright.dev/docs/trace-viewer-intro?utm_source=chatgpt.com "Trace viewer"
[14]: https://tenacity.readthedocs.io/?utm_source=chatgpt.com "Tenacity — Tenacity documentation"
[15]: https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html?utm_source=chatgpt.com "Logging - OWASP Cheat Sheet Series"
[16]: https://owasp-top-10-proactive-controls-2018.readthedocs.io/en/latest/c9-implement-security-logging-monitoring.html?utm_source=chatgpt.com "C9: Implement Security Logging and Monitoring"
[17]: https://playwright.dev/docs/ci-intro?utm_source=chatgpt.com "Setting up CI"
[18]: https://docs.stripe.com/api/idempotent_requests?utm_source=chatgpt.com "Idempotent requests | Stripe API Reference"
[19]: https://stripe.com/blog/idempotency?utm_source=chatgpt.com "Designing robust and predictable APIs with idempotency"
[20]: https://playwright.dev/docs/api/class-locator?utm_source=chatgpt.com "Locator"
[21]: https://www.selenium.dev/documentation/test_practices/encouraged/page_object_models/?utm_source=chatgpt.com "Page object models"
[22]: https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html?utm_source=chatgpt.com "Secrets Management - OWASP Cheat Sheet Series"
[23]: https://tenacity.readthedocs.io/en/latest/api.html?utm_source=chatgpt.com "API Reference - Tenacity documentation"
[24]: https://playwright.dev/docs/emulation?utm_source=chatgpt.com "Emulation"
