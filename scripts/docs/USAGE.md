# 使用指南

詳細的命令參考和功能說明。

## 🛠️ 系統管理

### setup-local-scheduler.sh

主要的系統管理工具，用於安裝和管理 macOS launchd 定時任務。

```bash
# 安裝定時任務
./setup-local-scheduler.sh install

# 查看系統狀態
./setup-local-scheduler.sh status

# 暫時停用任務
./setup-local-scheduler.sh disable

# 重新啟用任務
./setup-local-scheduler.sh enable

# 完全卸載系統
./setup-local-scheduler.sh uninstall

# 測試腳本功能
./setup-local-scheduler.sh test

# 顯示幫助訊息
./setup-local-scheduler.sh help
```

## ⏰ 時間管理

### update-time.sh

管理和更新所有時間相關設定的工具。

```bash
# 互動式時間設定
./update-time.sh

# 快速設定 (簽到時 簽到分 簽退時 簽退分)
./update-time.sh 9 0 18 30        # 9:00 簽到, 18:30 簽退
./update-time.sh 8 45 17 45       # 8:45 簽到, 17:45 簽退

# 查看當前設定
./update-time.sh show

# 顯示幫助
./update-time.sh help
```

### time-config.sh

查看當前時間配置的工具。

```bash
# 顯示當前時間設定
./time-config.sh
```

**輸出範例:**
```
當前時間配置:
==============
簽到時間: 08:30
簽到窗口: 8:00 - 10:00

簽退時間: 18:00
簽退窗口: 17:00 - 19:00

工作日: 週一 週二 週三 週四 週五
```

## 📊 日誌管理

### log-viewer.sh

強大的日誌檢視和管理工具。

```bash
# 顯示日誌概覽
./log-viewer.sh overview

# 查看最新日誌 (預設 50 行)
./log-viewer.sh latest
./log-viewer.sh latest 100       # 指定行數

# 即時監控日誌
./log-viewer.sh monitor

# 查看今日日誌
./log-viewer.sh today

# 搜尋日誌內容
./log-viewer.sh search "ERROR"
./log-viewer.sh search "checkin" 7    # 搜尋最近7天

# 顯示執行統計
./log-viewer.sh stats

# 清理舊日誌
./log-viewer.sh cleanup            # 預設保留30天
./log-viewer.sh cleanup 60         # 保留60天

# 顯示幫助
./log-viewer.sh help
```

## 🎯 核心執行

### auto-punch.sh

核心的打卡邏輯腳本，通常由定時任務自動執行。

```bash
# 手動執行 (用於測試)
./auto-punch.sh
```

**執行邏輯:**
1. 檢查 GitHub CLI 狀態
2. 判斷當前時間是否在執行窗口內
3. 決定執行簽到或簽退
4. 觸發 GitHub Actions workflow
5. 記錄執行結果

## 🚀 一鍵安裝

### quick-install.sh

提供完整安裝體驗的腳本。

```bash
# 執行一鍵安裝
./quick-install.sh
```

**安裝流程:**
1. 檢查系統需求 (GitHub CLI)
2. 安裝定時任務
3. 測試腳本功能
4. 顯示安裝狀態
5. 提供使用指引

## 📁 檔案位置

### 日誌檔案
- **主日誌**: `~/.daily-tick-runner/logs/auto-punch-YYYYMM.log`
- **簽到日誌**: `~/.daily-tick-runner/logs/checkin.log`
- **簽退日誌**: `~/.daily-tick-runner/logs/checkout.log`
- **錯誤日誌**: `~/.daily-tick-runner/logs/*.error.log`

### 系統檔案
- **定時任務**: `~/Library/LaunchAgents/com.daily-tick-runner.*.plist`
- **配置檔案**: `scripts/config/time-config.sh`
- **備份檔案**: `scripts/config/backup/`

## 🔧 進階設定

### 自訂工作日

編輯 `config/time-config.sh`:

```bash
# 預設: 週一到週五
WORKDAYS=(1 2 3 4 5)

# 範例: 週一到週六
WORKDAYS=(1 2 3 4 5 6)

# 範例: 僅週二和週四
WORKDAYS=(2 4)
```

### 調整時間窗口

```bash
# 縮小簽到窗口 (更精確)
CHECKIN_START_HOUR=8
CHECKIN_END_HOUR=9

# 擴大簽退窗口 (更彈性)
CHECKOUT_START_HOUR=16
CHECKOUT_END_HOUR=20
```

### 修改日誌等級

編輯 `bin/auto-punch.sh` 中的觸發命令:

```bash
# 預設: INFO
trigger_workflow "$action_type" "INFO"

# 詳細日誌: DEBUG
trigger_workflow "$action_type" "DEBUG"
```

## ⚠️ 注意事項

1. **系統需求**: Mac 需要保持開機狀態
2. **網路連線**: 需要穩定的網路來觸發 GitHub Actions
3. **權限設定**: 確保所有腳本都有執行權限
4. **時間設定**: 避免設定過寬的時間窗口
5. **GitHub 限制**: 注意 GitHub Actions 的使用限制

## 🔄 工作流程

### 典型的日常流程

1. **早上 8:30** - 系統自動觸發簽到
2. **下午 18:00** - 系統自動觸發簽退
3. **定期檢查** - 查看日誌確認執行狀況
4. **必要時調整** - 使用 update-time.sh 修改時間

### 維護建議

- **每週檢查**: `./log-viewer.sh stats`
- **每月清理**: `./log-viewer.sh cleanup 30`
- **測試功能**: `./setup-local-scheduler.sh test`
- **備份設定**: 定期備份 `config/` 目錄