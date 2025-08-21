# 本機定時打卡設定

這個目錄包含了讓您的 Mac 自動定時觸發 GitHub Actions workflow_dispatch 的所有工具。

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

### 2. 安裝定時任務

```bash
# 進入 scheduler/local 目錄
cd scheduler/local

# 安裝定時任務
./setup-local-scheduler.sh install
```

### 3. 檢查狀態

```bash
# 查看安裝狀態
./setup-local-scheduler.sh status

# 查看最新日誌
./log-viewer.sh latest
```

## 📋 工具說明

### 主要腳本

| 文件 | 說明 | 主要功能 |
|------|------|----------|
| `quick-install.sh` | 一鍵安裝腳本 | 完整的安裝引導流程 |
| `auto-punch.sh` | 智慧打卡觸發腳本 | 自動判斷簽到/簽退時機並觸發 workflow |
| `setup-local-scheduler.sh` | 定時任務管理工具 | 安裝/卸載/啟用/停用 launchd 任務 |
| `update-time.sh` | 時間設定更新工具 | 修改執行時間，自動更新所有相關設定 |
| `log-viewer.sh` | 日誌檢視和管理工具 | 查看、監控、搜尋、清理日誌 |

### 配置文件

| 文件 | 說明 | 內容 |
|------|------|------|
| `time-config.sh` | 時間設定配置文件 | 所有時間相關參數的集中管理 |
| `com.daily-tick-runner.checkin.plist` | 簽到定時任務配置 | macOS launchd 簽到任務設定 |
| `com.daily-tick-runner.checkout.plist` | 簽退定時任務配置 | macOS launchd 簽退任務設定 |

## ⏰ 執行時間

- **簽到時間**: 週一到週五 08:30
- **簽退時間**: 週一到週五 18:00
- **自動判斷**: 腳本會根據當前時間自動判斷執行簽到或簽退

## 🛠️ 管理命令

### 定時任務管理

```bash
# 安裝定時任務
./setup-local-scheduler.sh install

# 查看狀態
./setup-local-scheduler.sh status

# 暫時停用
./setup-local-scheduler.sh disable

# 重新啟用
./setup-local-scheduler.sh enable

# 完全卸載
./setup-local-scheduler.sh uninstall

# 測試腳本
./setup-local-scheduler.sh test
```

### 日誌管理

```bash
# 查看日誌概覽
./log-viewer.sh overview

# 查看最新日誌 (預設 50 行)
./log-viewer.sh latest

# 查看最新日誌 (指定行數)
./log-viewer.sh latest 100

# 即時監控日誌
./log-viewer.sh monitor

# 查看今日日誌
./log-viewer.sh today

# 搜尋日誌內容
./log-viewer.sh search "ERROR"
./log-viewer.sh search "checkin" 7  # 搜尋最近7天的簽到記錄

# 查看統計資訊
./log-viewer.sh stats

# 清理舊日誌 (預設保留30天)
./log-viewer.sh cleanup
./log-viewer.sh cleanup 60  # 保留60天
```

### 時間管理

```bash
# 查看當前時間設定
./time-config.sh
./update-time.sh show

# 互動式修改時間
./update-time.sh

# 快速修改時間 (格式: 簽到時 簽到分 簽退時 簽退分)
./update-time.sh 9 0 18 30     # 設定 9:00 簽到, 18:30 簽退
./update-time.sh 8 45 17 45    # 設定 8:45 簽到, 17:45 簽退
./update-time.sh 13 55 18 0    # 設定 13:55 簽到, 18:00 簽退

# 查看更新說明
./update-time.sh help
```

## 📁 文件位置

### 日誌文件
- **主日誌**: `~/.daily-tick-runner/logs/auto-punch-YYYYMM.log`
- **簽到日誌**: `~/.daily-tick-runner/logs/checkin.log`
- **簽退日誌**: `~/.daily-tick-runner/logs/checkout.log`
- **錯誤日誌**: `~/.daily-tick-runner/logs/*.error.log`

### 系統文件
- **定時任務**: `~/Library/LaunchAgents/com.daily-tick-runner.*.plist`

## 🔧 自訂設定

### 修改執行時間

#### 🚀 方法 1: 使用便捷更新工具 (推薦)

```bash
# 互動式更新 - 系統會引導您輸入新時間
./update-time.sh

# 快速更新 (格式: 簽到時 簽到分 簽退時 簽退分)
./update-time.sh 9 0 18 30     # 設定 9:00 簽到, 18:30 簽退
./update-time.sh 8 45 17 45    # 設定 8:45 簽到, 17:45 簽退
./update-time.sh 13 55 18 0    # 設定 13:55 簽到, 18:00 簽退

# 查看當前時間設定
./update-time.sh show
./time-config.sh               # 直接執行配置文件也可查看

# 獲取使用說明
./update-time.sh help
```

**更新工具的功能：**
- ✅ 自動更新配置文件
- ✅ 重新生成 launchd plist 文件
- ✅ 自動重新載入定時任務
- ✅ 計算合理的時間窗口
- ✅ 驗證時間格式

#### 🔧 方法 2: 手動修改配置文件

編輯 `time-config.sh` 中的時間設定：

```bash
# 簽到時間設定
CHECKIN_HOUR=8          # 簽到小時 (24小時制)
CHECKIN_MINUTE=30       # 簽到分鐘

# 簽到時間窗口 (判斷是否該執行簽到的時間範圍)
CHECKIN_START_HOUR=7    # 簽到窗口開始小時  
CHECKIN_END_HOUR=10     # 簽到窗口結束小時

# 簽退時間設定  
CHECKOUT_HOUR=18        # 簽退小時 (24小時制)
CHECKOUT_MINUTE=0       # 簽退分鐘

# 簽退時間窗口 (判斷是否該執行簽退的時間範圍)
CHECKOUT_START_HOUR=17  # 簽退窗口開始小時
CHECKOUT_END_HOUR=19    # 簽退窗口結束小時
```

**手動修改後的更新步驟：**
```bash
# 方法 A: 使用更新工具重新套用 (推薦)
./update-time.sh show          # 確認新設定

# 方法 B: 手動重新載入
./setup-local-scheduler.sh disable
./setup-local-scheduler.sh enable
```

### 🕐 時間配置詳細說明

#### 時間設定的組成部分

1. **執行時間** (`CHECKIN_HOUR/MINUTE`, `CHECKOUT_HOUR/MINUTE`)
   - launchd 定時任務觸發的精確時間
   - 這是 Mac 系統實際執行腳本的時間

2. **時間窗口** (`*_START_HOUR`, `*_END_HOUR`)
   - 腳本判斷是否該執行打卡的時間範圍
   - 提供彈性，即使不在精確時間也能執行
   - 通常設定為執行時間前後 1-2 小時

#### 常見時間設定範例

```bash
# 早班族 (8:30 上班, 17:30 下班)
CHECKIN_HOUR=8 CHECKIN_MINUTE=30
CHECKOUT_HOUR=17 CHECKOUT_MINUTE=30

# 彈性上班 (9:00-10:00 可簽到, 17:00-19:00 可簽退)  
CHECKIN_START_HOUR=9 CHECKIN_END_HOUR=10
CHECKOUT_START_HOUR=17 CHECKOUT_END_HOUR=19

# 午班族 (13:00 上班, 22:00 下班)
CHECKIN_HOUR=13 CHECKIN_MINUTE=0  
CHECKOUT_HOUR=22 CHECKOUT_MINUTE=0
```

#### ⚠️ 時間窗口設定注意事項

- **不要設定過寬的窗口** (如 1:00-23:00)，這會導致誤判
- **建議窗口範圍**: 執行時間前後 1-3 小時
- **避免重疊**: 簽到和簽退窗口不應重疊

### 修改日誌等級

編輯 `auto-punch.sh` 中的 `trigger_workflow` 函數，將 `INFO` 改為 `DEBUG`:

```bash
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
   chmod +x scripts/*.sh
   ```

3. **定時任務未執行**
   ```bash
   # 檢查系統日誌
   log show --predicate 'subsystem == "com.apple.launchd"' --last 1h
   
   # 檢查定時任務狀態
   launchctl list | grep daily-tick-runner
   ```

4. **網路連線問題**
   - 檢查網路連線
   - 確認 GitHub 服務狀態
   - 查看錯誤日誌: `./log-viewer.sh search "ERROR"`

5. **時間設定問題**
   
   **時間窗口過寬 (如 1:00-23:00):**
   ```bash
   # 檢查當前設定
   ./time-config.sh
   
   # 修正為合理範圍
   ./update-time.sh 8 30 18 0  # 設定簽到 8:30, 簽退 18:00
   ```
   
   **時間修改後未生效:**
   ```bash
   # 確認配置更新
   ./update-time.sh show
   
   # 重新載入定時任務
   ./setup-local-scheduler.sh disable
   ./setup-local-scheduler.sh enable
   
   # 檢查 launchd 狀態
   launchctl list | grep daily-tick-runner
   ```
   
   **手動測試時間判斷:**
   ```bash
   # 測試當前時間是否在執行窗口內
   ./auto-punch.sh
   
   # 查看詳細時間判斷日誌
   ./log-viewer.sh latest | grep "時間窗口"
   ```

6. **時間判斷邏輯驗證**
   ```bash
   # 查看當前時間配置
   ./time-config.sh
   
   # 檢查是否為工作日
   date +%u  # 1-5 為工作日
   
   # 檢查當前小時是否在窗口內
   date +%H  # 查看當前小時
   ```

### 除錯模式

啟用詳細日誌：
```bash
# 手動執行以查看詳細輸出
./auto-punch.sh

# 查看系統日誌
./log-viewer.sh monitor
```

## 📊 監控建議

### 日常檢查

```bash
# 每週檢查執行狀態
./log-viewer.sh stats

# 檢查最近錯誤
./log-viewer.sh search "ERROR" 7

# 清理月度日誌
./log-viewer.sh cleanup 30
```

### 通知設定

如需要失敗通知，可以修改 `auto-punch.sh` 增加本機通知：

```bash
# 在失敗時發送 macOS 通知
osascript -e 'display notification "自動打卡執行失敗" with title "Daily Tick Runner"'
```

## 🔐 安全注意事項

1. **GitHub Token**: 使用 GitHub CLI 登入，避免明文儲存 token
2. **日誌安全**: 日誌文件不包含敏感資訊
3. **權限控制**: 腳本僅有當前用戶執行權限

## 📞 支援

如有問題，請檢查：

1. **日誌文件**: `./log-viewer.sh latest`
2. **GitHub Actions**: 檢查 repository 的 Actions 頁面
3. **系統狀態**: `./setup-local-scheduler.sh status`

---

*本工具由 Claude Code 自動生成*