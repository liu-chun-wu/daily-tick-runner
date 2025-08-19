結論先說：**不用在指令裡「顯示標記路徑」**。
檔案/資料夾路徑是「測試篩選（test-filter）」；而\*\*標記（@no-click / @click）\*\*用 `--grep`（或在 project 裡 `grep:`）過濾即可。Playwright 的 CLI 讓你同時用「路徑 + 標記」組合篩選，非常彈性。([Playwright][1])

下面用你現況直接可用的**CLI 速查**（都能與 `--project=chromium` 或 `--project=chromium-smoke` 一起用）：

---

# 路徑 / 測試選擇

* **跑單一檔案**
  `npx playwright test tests/attendance/checkin.smoke.spec.ts --project=chromium-smoke`
  （在 CLI 的最後面加上的參數會被視為「檔案路徑 regex 篩選」；也可放資料夾路徑。）([Playwright][1])

* **跑整個資料夾**
  `npx playwright test tests/attendance/ --project=chromium-smoke` ([Playwright][1])

* **跑檔案中的某一「行」的測試（最精準）**
  `npx playwright test tests/checkin.click.spec.ts:12 --project=chromium-click --debug`
  （`file:line` 語法會只執行那行所屬的測試，常用來精準除錯。）([Playwright][2])

* **依測試標題篩選**
  `npx playwright test -g "簽到頁可見" --project=chromium-smoke` （`-g/--grep` 對測試標題做 regex 篩選）。([Playwright][1])

* **只列出會跑哪些測試（不執行）**
  `npx playwright test --project=chromium-smoke --list`
  （會印出測試清單與路徑，方便你確認篩選條件有沒有撈到。）([Playwright][1])

---

# 標記（tags）/ grep

* **用「@標記」跑子集合**

  * 給 smoke（不點擊）：`npx playwright test --grep "@no-click" --project=chromium`
  * 排除 click：`npx playwright test --grep-invert "@click" --project=chromium`
    你也可以把 `grep: /@no-click/` 寫進 `chromium-smoke` 專案，CI 就不用每次下 `--grep`。([Playwright][1])

* **怎麼「加標記」？**
  兩種寫法都被官方支援：

  ```ts
  test('簽到頁可見 @no-click', async () => { /* ... */ });

  // 或用 details 物件（較新）
  test('簽到（真的點）', { tag: '@click' }, async () => { /* ... */ });
  ```

  上面兩種都能被 `--grep "@no-click"` 或 `--grep "@click"` 篩到。([Playwright][3])

* **UI Mode 也能用標記/專案過濾**
  `npx playwright test --ui` 開起來後，可用「搜尋文字或 @tag」與「Projects」過濾；若有 project 依賴，需**先手動跑 setup** 再跑依賴測試。([Playwright][4])

---

# 你的兩條指令怎麼最佳化？

* **只驗證到簽到頁、有按鈕可點（不點擊）**
  `npx playwright test tests/attendance --project=chromium-smoke --headed --workers=1 --trace on`
  （`chromium-smoke` 專案內放 `grep: /@no-click/`，就不必在指令再寫 `--grep`。）([Playwright][5])

* **本機真的點擊（手動觸發時才跑）**
  `npx playwright test tests/attendance/checkin.click.spec.ts --project=chromium-click --headed --workers=1 --trace on`
  （`chromium-click` 專案用 `grep: /@click/`；另外在檔案加 `test.skip(!!process.env.CI, ...)` 防止 CI 誤跑。）([Playwright][1])

---

# 常用執行/除錯旗標（跟你情境最相關）

* `--project`：選擇要跑哪個 project（例如 `chromium`、`chromium-smoke`）。([Playwright][5])
* `--headed` / `--workers=1`：開視窗、單工除錯更穩。([Playwright][6])
* `--trace on|retain-on-failure|on-first-retry`：打開 trace；跑完用 `npx playwright show-report` 看測試＋點進 trace。也可用 `npx playwright show-trace test-results/**/trace.zip` 直接開 trace。([Playwright][1])
* `--reporter=list|dot|html|junit|json`：需要更清楚輸出或整合 CI 時很好用。([Playwright][7])
* `--list`：先確認「會跑到哪些測試／路徑」再執行。([Playwright][1])
* `--debug`（或環境變數 `PWDEBUG=1`）：開 Inspector、暫停逐步執行。([Playwright][2], [BrowserStack][8])

---

## 一套「你現在就能用」的指令樣板

* 檢查 smoke 子集會選到哪些檔與測試：
  `npx playwright test tests/attendance --project=chromium-smoke --list` ([Playwright][1])

* 只跑「簽到頁可見 @no-click」這一條：
  `npx playwright test -g "@no-click .*簽到頁可見" --project=chromium` ([Playwright][1])

* 跑單一測試（以行號鎖定）並開偵錯：
  `npx playwright test tests/checkin.click.spec.ts:12 --project=chromium-click --debug` ([Playwright][2])

* 看上次結果（含 trace）：
  `npx playwright show-report`；或直接：`npx playwright show-trace test-results/**/trace.zip`。([Playwright][1])

---

如果你願意，我也可以幫你把 `playwright.config.ts` 補上 `chromium-smoke`/`chromium-click` 兩個專案的 `grep`，再加兩個 npm scripts：
`"smoke": "playwright test --project=chromium-smoke"`, `"click": "playwright test --project=chromium-click --headed --workers=1"`.

[1]: https://playwright.dev/docs/test-cli "Command line | Playwright"
[2]: https://playwright.dev/docs/debug?utm_source=chatgpt.com "Debugging Tests | Playwright"
[3]: https://playwright.dev/docs/test-annotations?utm_source=chatgpt.com "Annotations"
[4]: https://playwright.dev/docs/test-ui-mode?utm_source=chatgpt.com "UI Mode"
[5]: https://playwright.dev/docs/test-projects?utm_source=chatgpt.com "Projects"
[6]: https://playwright.dev/docs/running-tests?utm_source=chatgpt.com "Running and debugging tests"
[7]: https://playwright.dev/docs/test-reporters?utm_source=chatgpt.com "Reporters"
[8]: https://www.browserstack.com/guide/playwright-debugging?utm_source=chatgpt.com "How to start with Playwright Debugging? | BrowserStack"
