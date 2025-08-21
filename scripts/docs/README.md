# Daily Tick Runner - 本機定時打卡系統

自動化您的 Mac 定時觸發 GitHub Actions workflow_dispatch，實現智慧打卡功能。

## 🚀 快速開始

### 一鍵安裝
```bash
cd scripts
./quick-install.sh
```

### 手動安裝
```bash
# 1. 確認環境
gh --version || brew install gh
gh auth login

# 2. 安裝定時任務
./setup-local-scheduler.sh install

# 3. 檢查狀態
./setup-local-scheduler.sh status
```

## 📁 目錄結構

```
scripts/
├── bin/                    # 可執行腳本
├── config/                 # 配置檔案
├── docs/                   # 說明文件
├── utils/                  # 工具函數
└── *.sh                    # 便捷訪問腳本
```

## ⚡ 核心功能

- **🤖 智慧判斷**: 自動根據時間和星期判斷簽到/簽退
- **⏰ 彈性時間**: 可自訂執行時間和時間窗口
- **📊 完整日誌**: 詳細記錄所有執行過程
- **🔧 易於管理**: 簡單的命令管理整個系統
- **🛠️ 故障診斷**: 內建錯誤診斷和修復建議

## 📖 詳細文件

- **[使用指南](USAGE.md)** - 詳細的命令和功能說明
- **[故障排除](TROUBLESHOOTING.md)** - 常見問題和解決方案
- **[API 說明](API.md)** - 腳本開發和自訂指南

## 🎛️ 常用命令

```bash
# 系統管理
./setup-local-scheduler.sh status    # 查看狀態
./setup-local-scheduler.sh disable   # 暫時停用
./setup-local-scheduler.sh enable    # 重新啟用

# 時間管理
./update-time.sh                      # 互動式修改時間
./time-config.sh                      # 查看當前設定

# 日誌管理
./log-viewer.sh latest                # 查看最新日誌
./log-viewer.sh monitor               # 即時監控
```

## ⚙️ 預設設定

- **簽到時間**: 週一到週五 08:30 (時間窗口: 08:00-09:00)
- **簽退時間**: 週一到週五 18:00 (時間窗口: 17:00-19:00)
- **日誌保存**: 30 天
- **重試機制**: 最多 3 次，間隔 60 秒

## 🔐 安全性

- 使用 GitHub CLI 認證，無需儲存 Token
- 日誌不包含敏感資訊
- 僅限當前用戶權限

---

*🤖 由 Claude Code 自動生成*