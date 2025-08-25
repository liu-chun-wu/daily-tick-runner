#!/bin/bash

# 排程時間檢查工具
# 作者: Claude Code  
# 用途: 顯示排程時間資訊

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

# 顯示排程資訊
show_schedule_info() {
    local current_hour=$(date +%H | sed 's/^0//')
    local current_minute=$(date +%M | sed 's/^0//')
    local current_time=$(printf "%02d:%02d" $current_hour $current_minute)
    local day_of_week=$(date +%u)
    local day_name=$(date +%A)
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                         排程時間資訊                              ║${NC}"
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
        echo
    else
        success "今天是工作日"
        echo
    fi
    
    # 顯示排程時間
    echo -e "${MAGENTA}【排程設定】${NC}"
    echo "  簽到時間: $(format_time_colored $CHECKIN_HOUR $CHECKIN_MINUTE)"
    echo "  簽退時間: $(format_time_colored $CHECKOUT_HOUR $CHECKOUT_MINUTE)"
    echo
    
    # 計算下次執行時間
    echo -e "${MAGENTA}【下次執行】${NC}"
    
    local checkin_minutes=$((CHECKIN_HOUR * 60 + CHECKIN_MINUTE))
    local checkout_minutes=$((CHECKOUT_HOUR * 60 + CHECKOUT_MINUTE))
    local current_minutes=$((current_hour * 60 + current_minute))
    
    if is_workday; then
        if [[ $current_minutes -lt $checkin_minutes ]]; then
            local diff=$((checkin_minutes - current_minutes))
            echo -e "  下次執行: ${GREEN}簽到${NC} ($(format_time_colored $CHECKIN_HOUR $CHECKIN_MINUTE))"
            echo "  距離時間: $diff 分鐘"
        elif [[ $current_minutes -lt $checkout_minutes ]]; then
            local diff=$((checkout_minutes - current_minutes))
            echo -e "  下次執行: ${GREEN}簽退${NC} ($(format_time_colored $CHECKOUT_HOUR $CHECKOUT_MINUTE))"
            echo "  距離時間: $diff 分鐘"
        else
            echo "  今日排程已全部完成"
            if [[ $day_of_week -eq 5 ]]; then
                echo "  下次執行: 下週一 $(format_time_colored $CHECKIN_HOUR $CHECKIN_MINUTE) (簽到)"
            else
                echo "  下次執行: 明天 $(format_time_colored $CHECKIN_HOUR $CHECKIN_MINUTE) (簽到)"
            fi
        fi
    else
        echo "  下次執行: 下個工作日 $(format_time_colored $CHECKIN_HOUR $CHECKIN_MINUTE) (簽到)"
    fi
    echo
    
    # 手動執行提示
    echo -e "${CYAN}【手動執行】${NC}"
    echo "  測試簽到: ./manage test checkin"
    echo "  測試簽退: ./manage test checkout"
    echo "  立即簽到: ./manage dispatch checkin"
    echo "  立即簽退: ./manage dispatch checkout"
}

# 主函數
main() {
    show_schedule_info
}

# 如果直接執行此腳本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi