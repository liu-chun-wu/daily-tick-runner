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

# 顯示時間狀態條
show_time_bar() {
    local start_hour=$1
    local end_hour=$2
    local current_hour=$(date +%H | sed 's/^0//')
    
    echo -n "  時間窗口: ["
    
    for hour in $(seq 0 23); do
        if [[ $hour -ge $start_hour && $hour -le $end_hour ]]; then
            if [[ $hour -eq $current_hour ]]; then
                echo -n -e "${GREEN}▓${NC}"
            else
                echo -n -e "${CYAN}░${NC}"
            fi
        else
            if [[ $hour -eq $current_hour ]]; then
                echo -n -e "${YELLOW}▓${NC}"
            else
                echo -n " "
            fi
        fi
    done
    
    echo "] (0-23時)"
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
    echo "  執行窗口: ${CHECKIN_START_HOUR}:00 - ${CHECKIN_END_HOUR}:00"
    show_time_bar $CHECKIN_START_HOUR $CHECKIN_END_HOUR
    
    if [[ $current_hour -ge $CHECKIN_START_HOUR && $current_hour -le $CHECKIN_END_HOUR ]]; then
        success "當前在簽到窗口內 ✓"
    else
        if [[ $current_hour -lt $CHECKIN_START_HOUR ]]; then
            local diff=$(time_diff_minutes $CHECKIN_START_HOUR 0)
            info "距離簽到窗口還有 $diff 分鐘"
        else
            warning "已錯過簽到窗口"
        fi
    fi
    echo
    
    # 簽退窗口檢查
    echo -e "${MAGENTA}【簽退窗口】${NC}"
    echo "  設定時間: $(format_time_colored $CHECKOUT_HOUR $CHECKOUT_MINUTE)"
    echo "  執行窗口: ${CHECKOUT_START_HOUR}:00 - ${CHECKOUT_END_HOUR}:00"
    show_time_bar $CHECKOUT_START_HOUR $CHECKOUT_END_HOUR
    
    if [[ $current_hour -ge $CHECKOUT_START_HOUR && $current_hour -le $CHECKOUT_END_HOUR ]]; then
        success "當前在簽退窗口內 ✓"
    else
        if [[ $current_hour -lt $CHECKOUT_START_HOUR ]]; then
            local diff=$(time_diff_minutes $CHECKOUT_START_HOUR 0)
            info "距離簽退窗口還有 $diff 分鐘"
        else
            warning "已錯過簽退窗口"
        fi
    fi
    echo
    
    # 建議動作
    echo -e "${CYAN}【建議動作】${NC}"
    if [[ $current_hour -ge $CHECKIN_START_HOUR && $current_hour -le $CHECKIN_END_HOUR ]]; then
        echo -e "  👉 可執行: ${GREEN}簽到${NC}"
        echo "     命令: ./manage dispatch checkin"
    elif [[ $current_hour -ge $CHECKOUT_START_HOUR && $current_hour -le $CHECKOUT_END_HOUR ]]; then
        echo -e "  👉 可執行: ${GREEN}簽退${NC}"
        echo "     命令: ./manage dispatch checkout"
    else
        echo "  ⏸ 當前不在任何打卡窗口內"
        
        # 計算下一個窗口
        if [[ $current_hour -lt $CHECKIN_START_HOUR ]]; then
            echo -e "  ⏰ 下個窗口: ${CYAN}簽到${NC} (${CHECKIN_START_HOUR}:00)"
        elif [[ $current_hour -lt $CHECKOUT_START_HOUR ]]; then
            echo -e "  ⏰ 下個窗口: ${CYAN}簽退${NC} (${CHECKOUT_START_HOUR}:00)"
        else
            echo "  ⏰ 今日打卡窗口已全部結束"
        fi
    fi
}

# 簡單檢查（用於其他腳本調用）
simple_check() {
    local current_hour=$(date +%H | sed 's/^0//')
    
    if ! is_workday; then
        echo "non-workday"
        return
    fi
    
    if [[ $current_hour -ge $CHECKIN_START_HOUR && $current_hour -le $CHECKIN_END_HOUR ]]; then
        echo "checkin"
    elif [[ $current_hour -ge $CHECKOUT_START_HOUR && $current_hour -le $CHECKOUT_END_HOUR ]]; then
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