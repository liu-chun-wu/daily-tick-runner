## 🔧 專案名稱

**daily-tick-runner** — 震旦 HR 系統自動打卡工具（Docker 化 + LINE Bot 通知 + 本地 log 儲存）

---

## 🎯 專案目標

開發一個可自動登入「震旦 HR 系統」並完成每日打卡的工具，具備以下特性：

* ⏰ 支援每日定時打卡（上班）
* 🐳 Docker 容器化執行，方便部署與維運
* 🤖 LINE Bot 通知打卡結果（使用 LINE Messaging API）
* 📄 本地 log 儲存，方便除錯與記錄
* 🚀 支援 GitHub Actions / Cron 排程執行
* 🔐 帳密安全保護與失敗驗證回報

---

## 🧩 系統架構概覽

```text
GitHub Actions / Local Cron
          |
    +-----v------------------+
    | infra-job-helper App   |
    |  - Selenium login & click
    |  - Python logging      |
    +-----+------------------+
          |
    +-----v---------------------+
    | log file (本地 log 儲存)  |
    +-----+---------------------+
          |
    +-----v---------------+
    | LINE Bot 推播結果   |
    +---------------------+
```

*註：log 直接寫入檔案或標準輸出，便於後續調閱、除錯。若未來有需求再升級到集中式 log 系統。*

---

## 📁 專案資料夾結構建議

```
infra-job-helper/
├── Dockerfile
├── docker-compose.yml
├── .env.example
├── app/
│   ├── main.py               # 主打卡邏輯
│   ├── clockin.py            # Selenium 操作封裝
│   ├── line_bot.py           # LINE 推播模組
│   ├── utils.py              # 驗證與工具方法
│   └── logs/                 # log 檔案存放資料夾（新增）
└── requirements.txt
```

---

## 🛠️ 開發步驟

### 1. Python 打卡工具開發

* 使用 Selenium 模擬登入 `https://erpline.aoacloud.com.tw`
* 判斷是否登入成功、按下打卡按鈕後出現成功提示
* 使用 logging 模組寫入本地 log 檔（如：logs/clockin.log）
* 打卡成功與失敗皆記錄並通知

### 2. 驗證機制設計

* 登入驗證：透過 DOM 判斷登入狀態
* 打卡驗證：確認成功訊息或時間戳記
* 通知驗證：發送 LINE Bot 時回傳狀態碼檢查
* 任務錯誤回報：log 並使用 exit code 区分

### 3. Docker 容器化

* 建立 Dockerfile：安裝 Python、Selenium、Chrome Headless
* 透過環境變數注入帳密與 token
* 支援用 cron 或 GitHub Actions 觸發

### 4. 本地 log 儲存整合（**此處為 EFK 替換重點**）

* 直接於 app 內用 Python logging 寫入 logs/clockin.log
* 若於 Docker 執行，可直接掛載 logs 資料夾於宿主機，方便查看
* 日誌等級可設為 INFO/ERROR 依需求調整
* 若需進一步通知錯誤，可額外發送 LINE Bot

### 5. LINE Bot 通知整合（Messaging API）

* 建立 LINE Messaging API channel
* 取得 Channel Access Token、加入 bot 為好友
* 在 `.env` 儲存 `LINE_CHANNEL_ACCESS_TOKEN` 和 `LINE_USER_ID`
* 使用 `requests` 發送 Push API 訊息通知打卡結果

---

## 🔐 安全性考量

| 項目                   | 說明                         |
| -------------------- | -------------------------- |
| 密碼存取                 | 使用 `.env` 或 GitHub Secrets |
| Chrome automation 偵測 | 加入 User-Agent、等待時間避免被封鎖    |
| 推播對象                 | 限制為固定 LINE userId          |
| log 保護               | logs 目錄可設存取權限避免外洩          |

---

## 🚀 排程方式選擇

### ✅ GitHub Actions

（同原本內容，可省略不變）

### ✅ Local Cron + Docker

（同原本內容，可省略不變）

---

## 📊 可擴充方向

* 支援下班自動打卡（根據時間判斷）
* 多帳號版本支援
* Web UI 控制（FastAPI + JWT）
* LINE webhook 回應查詢（"今天打卡了嗎？"）
* Telegram 或 Slack 通知切換
* **集中式 log 架構（EFK、Grafana Loki 等，依未來規模決定）**

---

## 📘 相關技術版本建議

| 技術             | 建議版本  |
| -------------- | ----- |
| Python         | 3.11+ |
| Selenium       | 4.x   |
| Docker Compose | v2    |

---

### 說明

* **EFK 架構相關說明及步驟已移除**，取而代之為本地 log 儲存（`logs/clockin.log`）。
* 若未來要觀察 log，可直接查看 logs 目錄或透過 Docker volume 對外掛載。
