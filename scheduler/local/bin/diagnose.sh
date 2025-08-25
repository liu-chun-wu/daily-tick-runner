#!/bin/bash

# 排程延遲診斷腳本
# 用途: 診斷並解決排程執行延遲問題

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config/schedule.conf"
LOG_DIR="$HOME/.daily-tick-runner/logs"

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_section() {
    echo -e "\n${BLUE}========== $* ==========${NC}"
}

# 檢查 launchd 服務狀態
check_launchd_status() {
    log_section "LaunchD 服務狀態"
    
    local services=("com.daily-tick-runner.checkin" "com.daily-tick-runner.checkout")
    
    for service in "${services[@]}"; do
        local status=$(launchctl list | grep "$service" || echo "未載入")
        if [[ "$status" == "未載入" ]]; then
            log_error "❌ $service: 未載入"
        else
            local pid=$(echo "$status" | awk '{print $1}')
            local exit_code=$(echo "$status" | awk '{print $2}')
            
            if [[ "$pid" == "-" ]]; then
                if [[ "$exit_code" == "0" ]]; then
                    log_info "✅ $service: 已載入，等待執行"
                else
                    log_warning "⚠️ $service: 已載入，上次執行退出碼: $exit_code"
                fi
            else
                log_info "✅ $service: 正在執行 (PID: $pid)"
            fi
        fi
    done
}

# 檢查系統節能設置
check_power_settings() {
    log_section "系統節能設置"
    
    # 檢查是否連接電源
    local power_source=$(pmset -g ps | head -1)
    if [[ "$power_source" == *"AC Power"* ]]; then
        log_info "✅ 已連接電源"
    else
        log_warning "⚠️ 使用電池供電，可能影響排程執行"
    fi
    
    # 檢查節能設置
    log_info "當前節能設置:"
    pmset -g | grep -E "sleep|standby|autopoweroff|tcpkeepalive" | while read -r line; do
        echo "  $line"
        
        # 檢查可能影響排程的設置
        if [[ "$line" == *"sleep"*"0"* ]]; then
            log_info "  ✅ 系統睡眠已禁用"
        elif [[ "$line" == *"sleep"* ]]; then
            local sleep_time=$(echo "$line" | awk '{print $2}')
            if [[ "$sleep_time" -lt 60 ]]; then
                log_warning "  ⚠️ 系統將在 $sleep_time 分鐘後睡眠，可能影響排程"
            fi
        fi
    done
    
    # 檢查喚醒排程
    log_info ""
    log_info "系統喚醒排程:"
    local wake_schedule=$(pmset -g sched)
    if [[ -z "$wake_schedule" || "$wake_schedule" == *"No scheduled events"* ]]; then
        log_warning "⚠️ 未設置系統喚醒排程"
        log_info "💡 建議執行: $SCRIPT_DIR/wake-scheduler.sh setup"
    else
        echo "$wake_schedule"
        log_info "✅ 已設置喚醒排程"
    fi
}

# 檢查系統負載
check_system_load() {
    log_section "系統負載狀態"
    
    local load_avg=$(uptime | awk -F'load averages:' '{print $2}')
    log_info "系統負載: $load_avg"
    
    local load_1min=$(echo "$load_avg" | awk '{print $1}')
    local cpu_count=$(sysctl -n hw.ncpu)
    
    # 使用 bc 進行浮點數比較
    if command -v bc &>/dev/null; then
        local high_load=$(echo "$load_1min > $cpu_count" | bc)
        if [[ "$high_load" == "1" ]]; then
            log_warning "⚠️ 系統負載較高 (${load_1min} > ${cpu_count} CPUs)"
        else
            log_info "✅ 系統負載正常"
        fi
    fi
    
    # 檢查記憶體使用
    log_info ""
    log_info "記憶體使用:"
    vm_stat | grep -E "Pages (free|active|inactive|speculative|wired)" | head -5
}

# 分析最近的執行日誌
analyze_recent_logs() {
    log_section "最近執行日誌分析"
    
    if [[ ! -d "$LOG_DIR" ]]; then
        log_warning "日誌目錄不存在: $LOG_DIR"
        return
    fi
    
    local current_month_log="$LOG_DIR/auto-punch-$(date +%Y%m).log"
    
    if [[ -f "$current_month_log" ]]; then
        log_info "分析本月日誌: $(basename "$current_month_log")"
        
        # 統計執行次數
        local total_runs=$(grep -c "自動打卡程序開始" "$current_month_log" 2>/dev/null || echo "0")
        local successful_runs=$(grep -c "自動打卡執行成功" "$current_month_log" 2>/dev/null || echo "0")
        local failed_runs=$(grep -c "自動打卡執行失敗" "$current_month_log" 2>/dev/null || echo "0")
        
        log_info "執行統計:"
        log_info "  總執行次數: $total_runs"
        log_info "  成功次數: $successful_runs"
        log_info "  失敗次數: $failed_runs"
        
        # 分析延遲情況
        log_info ""
        log_info "延遲分析:"
        local delays=$(grep "執行延遲:" "$current_month_log" 2>/dev/null | tail -5)
        if [[ -n "$delays" ]]; then
            log_warning "最近的延遲記錄:"
            echo "$delays" | while read -r line; do
                echo "  $line"
            done
        else
            log_info "✅ 最近沒有延遲記錄"
        fi
        
        # 檢查錯誤
        log_info ""
        local recent_errors=$(grep "ERROR" "$current_month_log" 2>/dev/null | tail -3)
        if [[ -n "$recent_errors" ]]; then
            log_error "最近的錯誤:"
            echo "$recent_errors" | while read -r line; do
                echo "  $line"
            done
        else
            log_info "✅ 最近沒有錯誤記錄"
        fi
    else
        log_warning "本月日誌檔案不存在"
    fi
}

# 檢查網路連接
check_network() {
    log_section "網路連接狀態"
    
    # 檢查 GitHub 連接
    if ping -c 1 -W 2 github.com &>/dev/null; then
        log_info "✅ GitHub 連接正常"
    else
        log_error "❌ 無法連接到 GitHub"
    fi
    
    # 檢查 GitHub CLI 認證
    if command -v gh &>/dev/null; then
        if gh auth status &>/dev/null; then
            log_info "✅ GitHub CLI 已認證"
        else
            log_error "❌ GitHub CLI 未認證"
        fi
    else
        log_error "❌ GitHub CLI 未安裝"
    fi
}

# 提供優化建議
provide_recommendations() {
    log_section "優化建議"
    
    local has_issues=false
    
    # 檢查各項設置並提供建議
    if ! launchctl list | grep -q "com.daily-tick-runner"; then
        has_issues=true
        log_warning "📌 建議重新載入 LaunchD 服務:"
        echo "     cd $SCRIPT_DIR/.."
        echo "     ./manage uninstall && ./manage install"
    fi
    
    if ! pmset -g sched | grep -q "wake"; then
        has_issues=true
        log_warning "📌 建議設置系統喚醒排程:"
        echo "     $SCRIPT_DIR/wake-scheduler.sh setup"
    fi
    
    local sleep_setting=$(pmset -g | grep "^[[:space:]]*sleep" | awk '{print $2}')
    if [[ -n "$sleep_setting" && "$sleep_setting" != "0" ]]; then
        has_issues=true
        log_warning "📌 建議禁用系統睡眠（連接電源時）:"
        echo "     sudo pmset -c sleep 0"
    fi
    
    if [[ "$has_issues" == "false" ]]; then
        log_info "✅ 系統配置良好，無需優化"
    fi
    
    log_info ""
    log_info "其他建議:"
    log_info "1. 確保 Mac 在排程時間保持開機狀態"
    log_info "2. 連接電源以獲得最佳性能"
    log_info "3. 定期檢查日誌: ./manage logs latest"
    log_info "4. 如果延遲持續，考慮將排程時間提前幾分鐘"
}

# 主函數
main() {
    log_section "排程系統診斷報告"
    log_info "診斷時間: $(date '+%Y-%m-%d %H:%M:%S')"
    
    # 載入配置
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        log_info "簽到時間: $(printf "%02d:%02d" "$CHECKIN_HOUR" "$CHECKIN_MINUTE")"
        log_info "簽退時間: $(printf "%02d:%02d" "$CHECKOUT_HOUR" "$CHECKOUT_MINUTE")"
    fi
    
    # 執行各項檢查
    check_launchd_status
    check_power_settings
    check_system_load
    check_network
    analyze_recent_logs
    provide_recommendations
    
    log_section "診斷完成"
}

# 執行主函數
main "$@"