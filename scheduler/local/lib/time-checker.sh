#!/bin/bash

# 時間窗口檢查工具
# 作者: Claude Code  
# 用途: 檢查當前時間是否在打卡窗口內，提供時間狀態資訊

set -euo pipefail

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config/schedule.conf"

# 載入時間配置
source "$CONFIG_FILE"

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# 輸出函數
info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

success() {
    echo -e "${GREEN}[✓]${NC} $*"
}

warning() {
    echo -e "${YELLOW}[!]${NC} $*"
}

error() {
    echo -e "${RED}[✗]${NC} $*"
}

# 格式化時間顯示
format_time_colored() {
    printf "${CYAN}%02d:%02d${NC}" "$1" "$2"
}

# 計算時間差（分鐘）
time_diff_minutes() {
    local target_hour=$1
    local target_minute=$2
    local current_hour=$(date +%H | sed 's/^0//')
    local current_minute=$(date +%M | sed 's/^0//')
    
    local target_total=$((target_hour * 60 + target_minute))
    local current_total=$((current_hour * 60 + current_minute))
    
    echo $((target_total - current_total))
}


# 檢查時間窗口
check_time_window() {
    local current_hour=$(date +%H | sed 's/^0//')
    local current_minute=$(date +%M | sed 's/^0//')
    local current_time=$(printf "%02d:%02d" $current_hour $current_minute)
    local day_of_week=$(date +%u)
    local day_name=$(date +%A)
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                         時間窗口檢查                              ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # 顯示當前時間
    echo -e "📅 當前時間: ${CYAN}$(date '+%Y-%m-%d %H:%M:%S')${NC} ($day_name)"
    echo
    
    # 檢查是否為工作日
    if ! is_workday; then
        warning "今天不是工作日，排程不會執行"
        echo
        echo "工作日設定: "
        for day in "${WORKDAYS[@]}"; do
            case $day in
                1) echo -n "週一 " ;;
                2) echo -n "週二 " ;;
                3) echo -n "週三 " ;;
                4) echo -n "週四 " ;;
                5) echo -n "週五 " ;;
                6) echo -n "週六 " ;;
                7) echo -n "週日 " ;;
            esac
        done
        echo
        return
    fi
    
    success "今天是工作日"
    echo
    
    # 簽到窗口檢查
    echo -e "${MAGENTA}【簽到窗口】${NC}"
    echo "  設定時間: $(format_time_colored $CHECKIN_HOUR $CHECKIN_MINUTE)"
    
    # 使用動態計算的時間窗口
    local checkin_bounds=($(get_checkin_window))
    local checkin_start=${checkin_bounds[0]}
    local checkin_end=${checkin_bounds[1]}
    local checkin_start_time=$(printf "%02d:%02d" $((checkin_start / 60)) $((checkin_start % 60)))
    local checkin_end_time=$(printf "%02d:%02d" $((checkin_end / 60)) $((checkin_end % 60)))
    
    echo -e "  執行窗口: ${CYAN}${checkin_start_time} - ${checkin_end_time}${NC} (±${WINDOW_SIZE_MINUTES}分鐘)"
    
    # 計算當前時間的總分鐘數
    local current_total_minutes=$((current_hour * 60 + current_minute))
    local checkin_total_minutes=$((CHECKIN_HOUR * 60 + CHECKIN_MINUTE))
    
    if [[ $current_total_minutes -ge $checkin_start && $current_total_minutes -le $checkin_end ]]; then
        success "當前在簽到窗口內 ✓"
        local time_to_target=$((checkin_total_minutes - current_total_minutes))
        if [[ $time_to_target -gt 0 ]]; then
            info "距離設定時間還有 $time_to_target 分鐘"
        elif [[ $time_to_target -lt 0 ]]; then
            info "已過設定時間 $((-time_to_target)) 分鐘"
        else
            info "正好是設定時間"
        fi
    else
        if [[ $current_total_minutes -lt $checkin_start ]]; then
            local diff=$((checkin_start - current_total_minutes))
            info "距離簽到窗口還有 $diff 分鐘"
        else
            warning "已錯過簽到窗口"
            local diff=$((current_total_minutes - checkin_end))
            info "窗口已結束 $diff 分鐘"
        fi
    fi
    echo
    
    # 簽退窗口檢查
    echo -e "${MAGENTA}【簽退窗口】${NC}"
    echo "  設定時間: $(format_time_colored $CHECKOUT_HOUR $CHECKOUT_MINUTE)"
    
    # 使用動態計算的時間窗口
    local checkout_bounds=($(get_checkout_window))
    local checkout_start=${checkout_bounds[0]}
    local checkout_end=${checkout_bounds[1]}
    local checkout_start_time=$(printf "%02d:%02d" $((checkout_start / 60)) $((checkout_start % 60)))
    local checkout_end_time=$(printf "%02d:%02d" $((checkout_end / 60)) $((checkout_end % 60)))
    
    echo -e "  執行窗口: ${CYAN}${checkout_start_time} - ${checkout_end_time}${NC} (±${WINDOW_SIZE_MINUTES}分鐘)"
    
    # 計算當前時間的總分鐘數
    local current_total_minutes=$((current_hour * 60 + current_minute))
    local checkout_total_minutes=$((CHECKOUT_HOUR * 60 + CHECKOUT_MINUTE))
    
    if [[ $current_total_minutes -ge $checkout_start && $current_total_minutes -le $checkout_end ]]; then
        success "當前在簽退窗口內 ✓"
        local time_to_target=$((checkout_total_minutes - current_total_minutes))
        if [[ $time_to_target -gt 0 ]]; then
            info "距離設定時間還有 $time_to_target 分鐘"
        elif [[ $time_to_target -lt 0 ]]; then
            info "已過設定時間 $((-time_to_target)) 分鐘"
        else
            info "正好是設定時間"
        fi
    else
        if [[ $current_total_minutes -lt $checkout_start ]]; then
            local diff=$((checkout_start - current_total_minutes))
            info "距離簽退窗口還有 $diff 分鐘"
        else
            warning "已錯過簽退窗口"
            local diff=$((current_total_minutes - checkout_end))
            info "窗口已結束 $diff 分鐘"
        fi
    fi
    echo
    
    # 建議動作
    echo -e "${CYAN}【建議動作】${NC}"
    
    # 使用動態計算的時間窗口
    local current_total_minutes=$((current_hour * 60 + current_minute))
    local checkin_bounds=($(get_checkin_window))
    local checkin_start=${checkin_bounds[0]}
    local checkin_end=${checkin_bounds[1]}
    local checkout_bounds=($(get_checkout_window))
    local checkout_start=${checkout_bounds[0]}
    local checkout_end=${checkout_bounds[1]}
    
    if [[ $current_total_minutes -ge $checkin_start && $current_total_minutes -le $checkin_end ]]; then
        echo -e "  👉 可執行: ${GREEN}簽到${NC}"
        echo "     命令: ./manage dispatch checkin"
    elif [[ $current_total_minutes -ge $checkout_start && $current_total_minutes -le $checkout_end ]]; then
        echo -e "  👉 可執行: ${GREEN}簽退${NC}"
        echo "     命令: ./manage dispatch checkout"
    else
        echo "  ⏸ 當前不在任何打卡窗口內"
        
        # 計算下一個窗口
        if [[ $current_total_minutes -lt $checkin_start ]]; then
            local checkin_start_time=$(printf "%02d:%02d" $((checkin_start / 60)) $((checkin_start % 60)))
            echo -e "  ⏰ 下個窗口: ${CYAN}簽到${NC} ($checkin_start_time)"
        elif [[ $current_total_minutes -lt $checkout_start ]]; then
            local checkout_start_time=$(printf "%02d:%02d" $((checkout_start / 60)) $((checkout_start % 60)))
            echo -e "  ⏰ 下個窗口: ${CYAN}簽退${NC} ($checkout_start_time)"
        else
            echo "  ⏰ 今日打卡窗口已全部結束"
        fi
    fi
}

# 簡單檢查（用於其他腳本調用）
simple_check() {
    local current_hour=$(date +%H | sed 's/^0//')
    local current_minute=$(date +%M | sed 's/^0//')
    
    if ! is_workday; then
        echo "non-workday"
        return
    fi
    
    # 計算當前時間的總分鐘數
    local current_total_minutes=$((current_hour * 60 + current_minute))
    
    # 使用動態計算的時間窗口
    local checkin_bounds=($(get_checkin_window))
    local checkin_start=${checkin_bounds[0]}
    local checkin_end=${checkin_bounds[1]}
    
    local checkout_bounds=($(get_checkout_window))
    local checkout_start=${checkout_bounds[0]}
    local checkout_end=${checkout_bounds[1]}
    
    if [[ $current_total_minutes -ge $checkin_start && $current_total_minutes -le $checkin_end ]]; then
        echo "checkin"
    elif [[ $current_total_minutes -ge $checkout_start && $current_total_minutes -le $checkout_end ]]; then
        echo "checkout"
    else
        echo "outside-window"
    fi
}

# 主函數
main() {
    local mode="${1:-full}"
    
    case "$mode" in
        "full")
            check_time_window
            ;;
        "simple")
            simple_check
            ;;
        *)
            error "未知模式: $mode"
            echo "可用模式: full (完整顯示), simple (簡單輸出)"
            exit 1
            ;;
    esac
}

# 如果直接執行此腳本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi