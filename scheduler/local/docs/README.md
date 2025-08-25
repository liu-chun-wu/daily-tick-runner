# 本地排程器 - macOS 定時打卡

這個本地排程器讓您的 Mac 自動定時觸發 GitHub Actions workflow_dispatch，實現完全本地化的定時打卡功能。

## 🏗️ 專案結構

```
scheduler/local/
├── bin/                        # 執行檔
│   ├── trigger.sh              # 主程式 - 觸發打卡（需要參數）
│   └── dispatch.sh             # 手動觸發工具
├── config/                     # 配置檔
│   ├── schedule.conf           # 時間設定配置
│   └── launchd/               # macOS 排程配置
│       ├── checkin.plist       # 簽到任務配置（含參數）
│       └── checkout.plist      # 簽退任務配置（含參數）
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

# 顯示幫助
./manage help
```

### 手動觸發

```bash
# 手動觸發簽到
./manage dispatch checkin

# 手動觸發簽退
./manage dispatch checkout

# 使用不同的 workflow
./manage dispatch checkin production
./manage dispatch checkout production
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

### 工作原理

本排程器採用簡化的參數化設計：

1. **plist 控制時間**: macOS launchd 根據 plist 配置在指定時間執行
2. **參數決定動作**: 
   - `checkin.plist` 傳遞 `checkin` 參數給 `trigger.sh`
   - `checkout.plist` 傳遞 `checkout` 參數給 `trigger.sh`
3. **無時間判斷**: 腳本不再判斷時間，直接執行指定動作

### 自訂時間設定

編輯 `config/schedule.conf` 或使用管理命令：

```bash
# 使用互動式設定
./manage update-time

# 直接指定時間
./manage update-time 9 30 18 0  # 9:30 簽到, 18:00 簽退
```

更新時間後會自動：
1. 更新 `schedule.conf` 配置檔
2. 重新生成 plist 檔案（含正確參數）
3. 重新載入 launchd 任務

## 📁 檔案位置

### 系統檔案

- **執行檔**: `bin/trigger.sh` (需要 checkin/checkout 參數)
- **配置檔**: `config/schedule.conf`
- **launchd 任務**: `~/Library/LaunchAgents/checkin.plist` 和 `checkout.plist`

### 日誌檔案

- **主日誌**: `~/.daily-tick-runner/logs/auto-punch-YYYYMM.log`
- **簽到日誌**: `~/.daily-tick-runner/logs/checkin.log`
- **簽退日誌**: `~/.daily-tick-runner/logs/checkout.log`

## 🔧 進階設定

### 自訂工作日

修改 `config/schedule.conf` 中的 `WORKDAYS` 陣列：

```bash
# 1=週一, 2=週二, 3=週三, 4=週四, 5=週五, 6=週六, 7=週日
WORKDAYS=(1 2 3 4 5)    # 預設週一到週五
```

### 修改日誌等級

執行時指定日誌等級：

```bash
# 使用 DEBUG 等級執行
./bin/trigger.sh checkin DEBUG
./bin/trigger.sh checkout DEBUG
```

### 直接使用 trigger.sh

```bash
# trigger.sh 現在需要參數
./bin/trigger.sh checkin              # 執行簽到
./bin/trigger.sh checkout             # 執行簽退
./bin/trigger.sh checkin DEBUG        # 使用 DEBUG 日誌等級
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


### 除錯模式

```bash
# 手動執行查看詳細輸出（需指定參數）
./bin/trigger.sh checkin
./bin/trigger.sh checkout

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
./manage install         # 安裝
./manage uninstall       # 卸載  
./manage status          # 狀態（含時間資訊）
```

### 手動執行
```bash
./manage dispatch checkin    # 手動簽到
./manage dispatch checkout   # 手動簽退
```

### 日常維護
```bash
./manage logs latest     # 查看日誌
./manage logs stats      # 統計資訊
./manage update-time     # 更新時間
./manage logs cleanup    # 清理日誌
```

*本排程器採用簡化的參數化設計，所有操作都透過統一的 `manage` 命令進行，plist 負責時間控制，參數決定執行動作*