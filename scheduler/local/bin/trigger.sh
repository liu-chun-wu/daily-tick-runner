
#!/bin/bash

# 自動打卡觸發腳本
# 作者: Claude Code
# 用途: 根據當前時間自動判斷並觸發 GitHub Actions workflow

set -euo pipefail

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$HOME/.daily-tick-runner/logs"
LOG_FILE="$LOG_DIR/auto-punch-$(date +%Y%m).log"
WORKFLOW_NAME="正式排程 - 自動打卡"

# 載入時間配置
source "$SCRIPT_DIR/../config/schedule.conf"

# 建立日誌目錄
mkdir -p "$LOG_DIR"

# 日誌函數
log() {
    local level="$1"
    shift
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $*" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO" "$@"
}

log_error() {
    log "ERROR" "$@"
}

log_debug() {
    log "DEBUG" "$@"
}

log_warning() {
    log "WARNING" "$@"
}

# 檢查必要工具
check_requirements() {
    log_info "檢查系統需求..."
    
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) 未安裝。請執行: brew install gh"
        exit 1
    fi
    
    if ! gh auth status &> /dev/null; then
        log_error "GitHub CLI 未登入。請執行: gh auth login"
        exit 1
    fi
    
    log_info "系統需求檢查完成"
}

# 判斷執行動作 - 只返回結果，不輸出日誌
get_action_type() {
    local current_hour=$(date +%H | sed 's/^0//')
    local current_minute=$(date +%M | sed 's/^0//')
    local day_of_week=$(date +%u)  # 1=Monday, 7=Sunday
    
    # 檢查是否為工作日
    if ! is_workday; then
        return 1
    fi
    
    # 計算當前時間的總分鐘數
    local current_total_minutes=$((current_hour * 60 + current_minute))
    
    # 使用動態計算的簽到時間窗口
    local checkin_bounds=($(get_checkin_window))
    local checkin_start=${checkin_bounds[0]}
    local checkin_end=${checkin_bounds[1]}
    
    # 使用動態計算的簽退時間窗口
    local checkout_bounds=($(get_checkout_window))
    local checkout_start=${checkout_bounds[0]}
    local checkout_end=${checkout_bounds[1]}
    
    # 判斷時間窗口（精確到分鐘）
    if [[ $current_total_minutes -ge $checkin_start && $current_total_minutes -le $checkin_end ]]; then
        echo "checkin"
        return 0
    elif [[ $current_total_minutes -ge $checkout_start && $current_total_minutes -le $checkout_end ]]; then
        echo "checkout"
        return 0
    else
        return 1
    fi
}

# 記錄判斷過程的日誌
log_time_determination() {
    local current_hour=$(date +%H | sed 's/^0//')
    local current_minute=$(date +%M | sed 's/^0//')
    local current_time=$(printf "%02d:%02d" $current_hour $current_minute)
    local day_of_week=$(date +%u)  # 1=Monday, 7=Sunday
    
    log_debug "當前時間: $current_time, 星期: $day_of_week"
    
    # 檢查是否為工作日
    if ! is_workday; then
        log_info "今天不是工作日，不執行打卡"
        return
    fi
    
    # 計算當前時間的總分鐘數
    local current_total_minutes=$((current_hour * 60 + current_minute))
    
    # 使用動態計算的簽到時間窗口
    local checkin_bounds=($(get_checkin_window))
    local checkin_start=${checkin_bounds[0]}
    local checkin_end=${checkin_bounds[1]}
    
    # 使用動態計算的簽退時間窗口
    local checkout_bounds=($(get_checkout_window))
    local checkout_start=${checkout_bounds[0]}
    local checkout_end=${checkout_bounds[1]}
    
    # 轉換回時間格式顯示
    local checkin_start_time=$(printf "%02d:%02d" $((checkin_start / 60)) $((checkin_start % 60)))
    local checkin_end_time=$(printf "%02d:%02d" $((checkin_end / 60)) $((checkin_end % 60)))
    local checkout_start_time=$(printf "%02d:%02d" $((checkout_start / 60)) $((checkout_start % 60)))
    local checkout_end_time=$(printf "%02d:%02d" $((checkout_end / 60)) $((checkout_end % 60)))
    
    # 判斷時間窗口並記錄日誌
    if [[ $current_total_minutes -ge $checkin_start && $current_total_minutes -le $checkin_end ]]; then
        log_info "在簽到時間窗口內 ($checkin_start_time-$checkin_end_time)"
    elif [[ $current_total_minutes -ge $checkout_start && $current_total_minutes -le $checkout_end ]]; then
        log_info "在簽退時間窗口內 ($checkout_start_time-$checkout_end_time)"
    else
        log_info "當前時間 ($current_time) 不在打卡時段內"
        log_debug "簽到窗口: $checkin_start_time-$checkin_end_time (設定時間 $(printf "%02d:%02d" $CHECKIN_HOUR $CHECKIN_MINUTE) ± ${WINDOW_SIZE_MINUTES}分鐘)"
        log_debug "簽退窗口: $checkout_start_time-$checkout_end_time (設定時間 $(printf "%02d:%02d" $CHECKOUT_HOUR $CHECKOUT_MINUTE) ± ${WINDOW_SIZE_MINUTES}分鐘)"
    fi
}

# 觸發 workflow
trigger_workflow() {
    local action_type="$1"
    local log_level="${2:-INFO}"
    
    # 重試配置
    local MAX_RETRIES=3
    local RETRY_DELAY=10
    local attempt=0
    local success=false
    
    log_info "準備觸發 workflow: action_type=$action_type, log_level=$log_level"
    
    # 重試循環
    while [[ $attempt -lt $MAX_RETRIES ]]; do
        attempt=$((attempt + 1))
        
        log_debug "執行命令: gh workflow run \"$WORKFLOW_NAME\" --field action_type=\"$action_type\" --field log_level=\"$log_level\" (第 $attempt/$MAX_RETRIES 次嘗試)"
        
        if gh workflow run "$WORKFLOW_NAME" \
            --field action_type="$action_type" \
            --field log_level="$log_level" 2>&1 | tee -a "$LOG_FILE"; then
            
            log_info "成功觸發 workflow: $action_type (第 $attempt 次嘗試)"
            success=true
            
            # 等待一下再查看狀態
            sleep 5
            
            # 顯示最新的 workflow run
            log_info "最新的 workflow 執行狀態:"
            if gh run list --workflow="$WORKFLOW_NAME" --limit=1 2>&1 | tee -a "$LOG_FILE"; then
                log_debug "成功查詢 workflow 執行狀態"
            else
                log_warning "查詢 workflow 狀態時發生錯誤，但觸發成功"
            fi
            
            break
        else
            local exit_code=$?
            
            if [[ $attempt -lt $MAX_RETRIES ]]; then
                log_warning "觸發 workflow 失敗 (退出碼: $exit_code)，$RETRY_DELAY 秒後重試 (第 $attempt/$MAX_RETRIES 次)"
                
                # 檢查網路連線
                if ! ping -c 1 github.com &>/dev/null; then
                    log_warning "檢測到網路連線問題，等待恢復..."
                fi
                
                sleep $RETRY_DELAY
            else
                log_error "觸發 workflow 失敗: $action_type (退出碼: $exit_code)，已達最大重試次數"
                log_error "可能原因:"
                log_error "1. GitHub CLI 權限不足"
                log_error "2. Workflow 名稱錯誤: '$WORKFLOW_NAME'"
                log_error "3. Repository 權限問題"
                log_error "4. 持續的網路連線問題"
                
                # 嘗試列出可用的 workflows 來診斷問題
                log_info "嘗試列出可用的 workflows 進行診斷:"
                if gh workflow list 2>&1 | tee -a "$LOG_FILE"; then
                    log_debug "成功列出 workflows"
                else
                    log_error "無法列出 workflows，可能是 GitHub CLI 或權限問題"
                fi
            fi
        fi
    done
    
    if [[ "$success" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# 主函數
main() {
    log_info "========== 自動打卡程序開始 =========="
    
    # 檢查需求
    check_requirements
    
    # 記錄時間判斷過程
    log_time_determination
    
    # 判斷執行動作
    if action_type=$(get_action_type); then
        log_info "判斷結果: 需要執行 $action_type"
        
        # 觸發 workflow
        if trigger_workflow "$action_type" "INFO"; then
            log_info "自動打卡執行成功"
            exit 0
        else
            log_error "自動打卡執行失敗"
            exit 1
        fi
    else
        log_info "當前時間不需要執行打卡動作"
        exit 0
    fi
}

# 處理中斷信號
trap 'log_error "程序被中斷"; exit 130' INT TERM

# 如果直接執行此腳本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
