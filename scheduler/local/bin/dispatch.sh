#!/bin/bash

# 直接觸發 GitHub Actions Workflow
# 作者: Claude Code
# 用途: 不檢查時間，直接觸發指定的 workflow

set -euo pipefail

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$HOME/.daily-tick-runner/logs"
LOG_FILE="$LOG_DIR/dispatch-$(date +%Y%m).log"

# Workflow 名稱
TEST_WORKFLOW="測試排程 - 自動打卡"
PRODUCTION_WORKFLOW="正式排程 - 自動打卡"

# 建立日誌目錄
mkdir -p "$LOG_DIR"

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 日誌函數
log() {
    local level="$1"
    shift
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $*" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
    log "INFO" "$@"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
    log "ERROR" "$@"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
    log "SUCCESS" "$@"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
    log "WARNING" "$@"
}

# 檢查必要工具
check_requirements() {
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) 未安裝。請執行: brew install gh"
        exit 1
    fi
    
    if ! gh auth status &> /dev/null; then
        log_error "GitHub CLI 未登入。請執行: gh auth login"
        exit 1
    fi
}

# 顯示幫助
show_help() {
    echo -e "${CYAN}直接觸發 GitHub Actions Workflow${NC}"
    echo
    echo "用法: $0 <action_type> [workflow] [log_level]"
    echo
    echo "參數:"
    echo "  action_type    必須，可選: checkin, checkout, both"
    echo "  workflow       可選，可選: test (預設), production"
    echo "  log_level      可選，可選: DEBUG (預設), INFO, WARN, ERROR"
    echo
    echo "範例:"
    echo "  $0 checkin                    # 觸發測試 workflow 簽到，DEBUG 模式"
    echo "  $0 checkout production         # 觸發正式 workflow 簽退，DEBUG 模式"
    echo "  $0 both test INFO             # 觸發測試 workflow 簽到+簽退，INFO 模式"
    echo "  $0 checkin production DEBUG   # 觸發正式 workflow 簽到，DEBUG 模式"
}

# 觸發 workflow
trigger_workflow() {
    local workflow_name="$1"
    local action_type="$2"
    local log_level="$3"
    
    log_info "準備觸發 workflow"
    log_info "  Workflow: $workflow_name"
    log_info "  Action Type: $action_type"
    log_info "  Log Level: $log_level"
    
    echo
    
    # 執行觸發
    if gh workflow run "$workflow_name" \
        --field action_type="$action_type" \
        --field log_level="$log_level" 2>&1 | tee -a "$LOG_FILE"; then
        
        log_success "成功觸發 workflow!"
        echo
        
        # 等待一下再查看狀態
        sleep 3
        
        # 顯示最新的 workflow run
        log_info "查看最新執行狀態..."
        if gh run list --workflow="$workflow_name" --limit=1 2>&1 | tee -a "$LOG_FILE"; then
            echo
            log_info "可使用以下命令查看詳細執行狀態:"
            echo "  gh run list --workflow=\"$workflow_name\""
            echo "  gh run watch"
        fi
        
        return 0
    else
        log_error "觸發 workflow 失敗"
        return 1
    fi
}

# 主函數
main() {
    # 檢查參數
    if [[ $# -lt 1 ]]; then
        show_help
        exit 1
    fi
    
    # 解析參數
    local action_type="$1"
    local workflow="${2:-test}"
    local log_level="${3:-DEBUG}"  # 預設 DEBUG
    
    # 驗證 action_type
    case "$action_type" in
        checkin|checkout|both)
            ;;
        help|-h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "無效的 action_type: $action_type"
            echo "有效值: checkin, checkout, both"
            exit 1
            ;;
    esac
    
    # 選擇 workflow
    local workflow_name
    case "$workflow" in
        test)
            workflow_name="$TEST_WORKFLOW"
            ;;
        production|prod)
            workflow_name="$PRODUCTION_WORKFLOW"
            ;;
        *)
            log_error "無效的 workflow: $workflow"
            echo "有效值: test, production"
            exit 1
            ;;
    esac
    
    # 驗證 log_level
    case "$log_level" in
        DEBUG|INFO|WARN|ERROR)
            ;;
        *)
            log_warning "無效的 log_level: $log_level，使用預設 DEBUG"
            log_level="DEBUG"
            ;;
    esac
    
    echo -e "${CYAN}========== 直接觸發 Workflow ==========${NC}"
    echo
    
    # 檢查需求
    check_requirements
    
    # 觸發 workflow
    if trigger_workflow "$workflow_name" "$action_type" "$log_level"; then
        echo
        log_success "操作完成"
        exit 0
    else
        echo
        log_error "操作失敗"
        exit 1
    fi
}

# 處理中斷信號
trap 'log_error "程序被中斷"; exit 130' INT TERM

# 執行主函數
main "$@"