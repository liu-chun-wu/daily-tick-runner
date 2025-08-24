# 本地排程器 - macOS 定時打卡

這個本地排程器讓您的 Mac 自動定時觸發 GitHub Actions workflow_dispatch，實現完全本地化的定時打卡功能。

## 🏗️ 專案結構

```
scheduler/local/
├── bin/                        # 執行檔
│   └── trigger.sh              # 主程式 - 觸發打卡
├── config/                     # 配置檔
│   ├── schedule.conf           # 時間設定配置
│   └── launchd/               # macOS 排程配置
│       ├── checkin.plist       # 簽到任務配置
│       └── checkout.plist      # 簽退任務配置
├── lib/                        # 內部工具庫
│   ├── setup.sh               # 安裝與管理工具
│   ├── schedule-manager.sh    # 時間設定管理
│   └── log-viewer.sh          # 日誌檢視工具
├── docs/                       # 文件
│   └── README.md              # 本文件
└── manage                      # 統一管理入口
```

## 🚀 快速開始

### 1. 確認前置需求

```bash
# 檢查是否已安裝 GitHub CLI
gh --version

# 如果未安裝，請執行：
brew install gh

# 登入 GitHub
gh auth login
```

### 2. 安裝定時排程

```bash
# 進入本地排程器目錄
cd scheduler/local

# 安裝定時任務（互動式安裝）
./manage install

# 或快速安裝（跳過確認）
./manage install --force
```

### 3. 檢查狀態

```bash
# 查看排程狀態
./manage status

# 查看最新執行日誌
./manage logs latest
```

## 📋 管理命令

### 基本操作

```bash
# 安裝排程
./manage install

# 卸載排程
./manage uninstall

# 查看狀態
./manage status

# 測試執行
./manage test

# 顯示幫助
./manage help
```

### 日誌管理

```bash
# 查看最新日誌 (預設 50 行)
./manage logs latest

# 查看最新 100 行日誌
./manage logs latest 100

# 查看今日日誌
./manage logs today

# 即時監控日誌
./manage logs monitor

# 搜尋錯誤訊息
./manage logs search ERROR

# 搜尋最近 7 天的簽到記錄
./manage logs search "checkin" 7

# 查看日誌統計
./manage logs stats

# 清理 30 天前的日誌
./manage logs cleanup

# 清理 60 天前的日誌
./manage logs cleanup 60
```

### 時間管理

```bash
# 互動式更新時間
./manage update-time

# 快速設定時間 (格式: 簽到時 簽到分 簽退時 簽退分)
./manage update-time 9 0 18 30     # 設定 9:00 簽到, 18:30 簽退
./manage update-time 8 45 17 45    # 設定 8:45 簽到, 17:45 簽退

# 查看當前時間設定
./manage update-time show
```

## ⏰ 時間設定

### 預設執行時間

- **簽到時間**: 週一到週五 08:30
- **簽退時間**: 週一到週五 18:00
- **自動判斷**: 腳本會根據當前時間自動判斷執行簽到或簽退

### 時間窗口機制

本排程器採用「時間窗口」機制，提供彈性的執行時間：

```bash
# 簽到時間窗口 (預設 7:00-10:00)
CHECKIN_START_HOUR=7
CHECKIN_END_HOUR=9

# 簽退時間窗口 (預設 17:00-19:00)  
CHECKOUT_START_HOUR=17
CHECKOUT_END_HOUR=19
```

### 自訂時間設定

編輯 `config/schedule.conf` 或使用管理命令：

```bash
# 使用互動式設定
./manage update-time

# 直接指定時間
./manage update-time 9 30 18 0  # 9:30 簽到, 18:00 簽退
```

## 📁 檔案位置

### 系統檔案

- **執行檔**: `bin/trigger.sh`
- **配置檔**: `config/schedule.conf`
- **launchd 任務**: `~/Library/LaunchAgents/com.daily-tick-runner.*.plist`

### 日誌檔案

- **主日誌**: `~/.daily-tick-runner/logs/auto-punch-YYYYMM.log`
- **簽到日誌**: `~/.daily-tick-runner/logs/checkin.log`
- **簽退日誌**: `~/.daily-tick-runner/logs/checkout.log`

## 🔧 進階設定

### 自訂工作日

修改 `config/schedule.conf` 中的 `is_workday` 函數：

```bash
is_workday() {
    local day_of_week=$(date +%u)  # 1=Monday, 7=Sunday
    # 預設: 週一到週五 (1-5) 為工作日
    [[ $day_of_week -ge 1 && $day_of_week -le 5 ]]
}
```

### 修改日誌等級

在 `bin/trigger.sh` 中調整日誌等級：

```bash
# 將 INFO 改為 DEBUG 以獲得更詳細的日誌
trigger_workflow "$action_type" "DEBUG"
```

## 🚨 故障排除

### 常見問題

1. **GitHub CLI 未登入**
   ```bash
   gh auth login
   ```

2. **權限不足**
   ```bash
   chmod +x manage bin/* lib/*
   ```

3. **定時任務未執行**
   ```bash
   # 檢查 launchd 狀態
   ./manage status
   
   # 檢查系統日誌
   log show --predicate 'subsystem == "com.apple.launchd"' --last 1h
   ```

4. **時間設定問題**
   ```bash
   # 查看當前設定
   ./manage update-time show
   
   # 重新設定合理的時間窗口
   ./manage update-time 8 30 18 0
   ```

### 除錯模式

```bash
# 手動執行查看詳細輸出
./bin/trigger.sh

# 監控即時日誌
./manage logs monitor

# 搜尋錯誤訊息
./manage logs search ERROR
```

## 📊 監控建議

### 日常檢查

```bash
# 每週檢查執行狀態
./manage logs stats

# 檢查最近錯誤
./manage logs search ERROR 7

# 查看排程狀態
./manage status
```

### 維護任務

```bash
# 月度清理舊日誌
./manage logs cleanup 30

# 檢查配置檔案
cat config/schedule.conf

# 測試執行
./manage test
```

## 🔐 安全注意事項

1. **GitHub Token**: 使用 GitHub CLI 登入，避免明文儲存 token
2. **日誌安全**: 日誌檔案不包含敏感資訊
3. **權限控制**: 腳本僅有當前使用者執行權限
4. **定期檢查**: 定期查看執行日誌確認無異常活動

## 📞 支援

如有問題，請檢查：

1. **執行狀態**: `./manage status`
2. **最新日誌**: `./manage logs latest`
3. **GitHub Actions**: 檢查 repository 的 Actions 頁面
4. **系統日誌**: `./manage logs search ERROR`

---

## 🎯 快速參考

### 一次性操作
```bash
./manage install    # 安裝
./manage uninstall  # 卸載  
./manage status     # 狀態
./manage test       # 測試
```

### 日常維護
```bash
./manage logs latest         # 查看日誌
./manage logs stats          # 統計資訊
./manage update-time        # 更新時間
./manage logs cleanup       # 清理日誌
```

*本排程器採用模組化設計，所有操作都透過統一的 `manage` 命令進行*