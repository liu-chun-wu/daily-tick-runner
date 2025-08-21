# API 說明文件

腳本間的 API 接口和開發指南。

## 📋 腳本架構

### 目錄結構
```
scripts/
├── bin/                          # 主要可執行腳本
│   ├── auto-punch.sh            # 核心打卡邏輯
│   ├── setup-local-scheduler.sh # 系統管理
│   ├── update-time.sh           # 時間管理
│   ├── log-viewer.sh            # 日誌管理
│   └── quick-install.sh         # 安裝嚮導
├── config/                       # 配置文件
│   ├── time-config.sh           # 時間配置
│   ├── templates/               # plist 模板
│   └── backup/                  # 配置備份
├── docs/                        # 說明文件
└── utils/                       # 共用工具 (未來擴展)
```

## 🔧 核心腳本 API

### auto-punch.sh

**用途**: 核心打卡邏輯執行器

**主要函數**:
```bash
# 檢查系統需求
check_requirements()

# 獲取執行動作類型
get_action_type()
# 返回: "checkin" | "checkout"
# 退出碼: 0=需要執行, 1=不執行

# 記錄時間判斷日誌
log_time_determination()

# 觸發 workflow
trigger_workflow(action_type, log_level)
# 參數: action_type ("checkin"|"checkout"), log_level ("DEBUG"|"INFO"|"WARN"|"ERROR")
# 返回: 0=成功, 1=失敗
```

**環境變數**:
```bash
SCRIPT_DIR        # 腳本所在目錄
SCRIPTS_ROOT      # scripts 根目錄
LOG_DIR           # 日誌目錄
LOG_FILE          # 當前日誌文件
WORKFLOW_NAME     # GitHub Actions workflow 名稱
```

**依賴配置**:
- `config/time-config.sh` - 時間相關配置

### setup-local-scheduler.sh

**用途**: 系統安裝和管理工具

**主要函數**:
```bash
# 檢查系統需求
check_requirements()

# 建立必要目錄
create_directories()

# 安裝定時任務
install_scheduler()

# 卸載定時任務
uninstall_scheduler()

# 啟用/停用任務
enable_scheduler()
disable_scheduler()

# 顯示狀態
show_status()

# 測試腳本
test_script()
```

**配置變數**:
```bash
SCRIPT_DIR           # bin 目錄
SCRIPTS_ROOT         # scripts 根目錄  
PROJECT_DIR          # 專案根目錄
LAUNCH_AGENTS_DIR    # launchd 目錄
CHECKIN_PLIST        # 簽到任務文件名
CHECKOUT_PLIST       # 簽退任務文件名
```

### update-time.sh

**用途**: 時間設定管理工具

**主要函數**:
```bash
# 顯示當前配置
show_current_config()

# 更新配置文件
update_config_file(checkin_hour, checkin_minute, checkout_hour, checkout_minute)

# 更新 plist 文件
update_plist_files(checkin_hour, checkin_minute, checkout_hour, checkout_minute)

# 重新載入 launchd 任務
reload_launchd()

# 互動式更新
interactive_update()

# 快速更新
quick_update(checkin_hour, checkin_minute, checkout_hour, checkout_minute)
```

### log-viewer.sh

**用途**: 日誌檢視和管理工具

**主要函數**:
```bash
# 顯示概覽
show_overview()

# 顯示最新日誌
show_latest(lines)

# 即時監控
monitor_logs()

# 搜尋日誌
search_logs(pattern, days)

# 顯示統計
show_statistics()

# 清理日誌
cleanup_logs(days)

# 顯示今日日誌
show_today()
```

## 📝 配置文件 API

### config/time-config.sh

**時間配置變數**:
```bash
# 簽到設定
CHECKIN_HOUR=8                # 簽到小時
CHECKIN_MINUTE=30             # 簽到分鐘
CHECKIN_START_HOUR=8          # 簽到窗口開始
CHECKIN_END_HOUR=9            # 簽到窗口結束

# 簽退設定
CHECKOUT_HOUR=18              # 簽退小時
CHECKOUT_MINUTE=0             # 簽退分鐘
CHECKOUT_START_HOUR=17        # 簽退窗口開始
CHECKOUT_END_HOUR=19          # 簽退窗口結束

# 工作日設定
WORKDAYS=(1 2 3 4 5)          # 1=週一, 7=週日
```

**工具函數**:
```bash
# 檢查是否為工作日
is_workday()
# 返回: 0=是工作日, 1=非工作日

# 格式化時間顯示
format_time(hour, minute)

# 顯示當前配置
show_config()
```

## 🔄 日誌系統 API

### 日誌函數
```bash
# 基礎日誌函數
log(level, message)

# 快捷日誌函數
log_info(message)
log_error(message) 
log_debug(message)
log_warning(message)
```

### 日誌格式
```
YYYY-MM-DD HH:MM:SS [LEVEL] MESSAGE
```

### 日誌文件結構
```
~/.daily-tick-runner/logs/
├── auto-punch-YYYYMM.log     # 主日誌 (月度)
├── checkin.log               # 簽到日誌
├── checkout.log              # 簽退日誌
├── checkin.error.log         # 簽到錯誤日誌
└── checkout.error.log        # 簽退錯誤日誌
```

## 🎛️ 擴展和自訂

### 添加新功能

1. **創建新腳本**:
```bash
# 在 bin/ 目錄創建新腳本
touch bin/my-feature.sh
chmod +x bin/my-feature.sh

# 在根目錄創建包裝腳本
echo '#!/bin/bash' > my-feature.sh
echo 'exec "$(dirname "$0")/bin/my-feature.sh" "$@"' >> my-feature.sh
chmod +x my-feature.sh
```

2. **載入共用配置**:
```bash
# 在腳本開頭載入配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_ROOT="$(dirname "$SCRIPT_DIR")"
source "$SCRIPTS_ROOT/config/time-config.sh"
```

3. **使用日誌系統**:
```bash
# 設定日誌文件
LOG_DIR="$HOME/.daily-tick-runner/logs"
LOG_FILE="$LOG_DIR/my-feature-$(date +%Y%m).log"
mkdir -p "$LOG_DIR"

# 載入日誌函數 (從 auto-punch.sh 複製)
log() { ... }
log_info() { ... }
```

### 自訂 Workflow 參數

編輯 `bin/auto-punch.sh` 中的 `trigger_workflow` 函數:

```bash
trigger_workflow() {
    local action_type="$1"
    local log_level="${2:-INFO}"
    
    # 添加自訂參數
    gh workflow run "$WORKFLOW_NAME" \
        --field action_type="$action_type" \
        --field log_level="$log_level" \
        --field custom_param="custom_value"
}
```

### 自訂時間判斷邏輯

編輯 `bin/auto-punch.sh` 中的 `get_action_type` 函數:

```bash
get_action_type() {
    local current_hour=$(date +%H)
    local current_minute=$(date +%M)
    local day_of_week=$(date +%u)
    
    # 自訂邏輯
    if [[ $day_of_week -eq 6 ]]; then  # 週六特殊處理
        # 自訂週六邏輯
    fi
    
    # 原有邏輯...
}
```

## 🔒 安全考量

### 敏感資訊處理
- 使用 GitHub CLI 儲存認證資訊
- 日誌中不記錄 token 或密碼
- 配置文件使用環境變數或安全儲存

### 權限設定
```bash
# 確保腳本權限正確
find scripts/ -name "*.sh" -exec chmod 755 {} \;

# 確保配置文件權限
chmod 644 config/*

# 確保私密文件權限
chmod 600 config/backup/*
```

### 錯誤處理
```bash
# 在所有腳本中使用
set -euo pipefail

# 捕捉中斷信號
trap 'cleanup_function' INT TERM

# 驗證輸入參數
if [[ $# -lt 1 ]]; then
    echo "錯誤: 缺少必要參數"
    exit 1
fi
```

## 🧪 測試和除錯

### 單元測試建議
```bash
# 測試時間判斷邏輯
test_time_logic() {
    # 模擬不同時間
    export TEST_HOUR=8
    export TEST_MINUTE=30
    
    # 執行測試
    result=$(get_action_type)
    assert_equals "$result" "checkin"
}
```

### 除錯模式
```bash
# 啟用除錯輸出
export DEBUG=1

# 在腳本中檢查
if [[ "${DEBUG:-0}" == "1" ]]; then
    set -x  # 啟用詳細追蹤
fi
```

### 乾執行模式
```bash
# 添加乾執行選項
if [[ "${DRY_RUN:-0}" == "1" ]]; then
    echo "乾執行: 會執行 $command"
    return 0
fi
```

## 📊 效能考量

### 最佳化建議
- 使用本地緩存減少 API 呼叫
- 適當的日誌輪轉避免檔案過大
- 避免在關鍵路徑中執行昂貴操作

### 監控指標
- 腳本執行時間
- 成功/失敗率
- GitHub API 使用量
- 系統資源使用