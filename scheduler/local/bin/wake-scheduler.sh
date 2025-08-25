#!/bin/bash

# 系統喚醒排程設置腳本
# 用途: 確保 Mac 在排程時間前喚醒

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config/schedule.conf"

# 載入配置
source "$CONFIG_FILE"

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# 設置系統喚醒
set_wake_schedule() {
    local action="$1"
    local hour="$2"
    local minute="$3"
    
    # 提前 2 分鐘喚醒系統
    local wake_minute=$((minute - 2))
    local wake_hour=$hour
    
    if [[ $wake_minute -lt 0 ]]; then
        wake_minute=$((wake_minute + 60))
        wake_hour=$((wake_hour - 1))
        if [[ $wake_hour -lt 0 ]]; then
            wake_hour=23
        fi
    fi
    
    # 格式化時間
    local wake_time=$(printf "%02d:%02d:00" "$wake_hour" "$wake_minute")
    
    log_info "設置 $action 喚醒時間: $wake_time (排程時間前 2 分鐘)"
    
    # 使用 pmset 設置重複喚醒
    # MTWRF = 週一到週五
    sudo pmset repeat wake MTWRF "$wake_time"
    
    if [[ $? -eq 0 ]]; then
        log_info "✅ $action 喚醒排程設置成功"
    else
        log_error "❌ $action 喚醒排程設置失敗"
        return 1
    fi
}

# 清除喚醒排程
clear_wake_schedule() {
    log_info "清除現有喚醒排程..."
    sudo pmset repeat cancel
    
    if [[ $? -eq 0 ]]; then
        log_info "✅ 喚醒排程已清除"
    else
        log_warning "⚠️ 清除喚醒排程時發生錯誤"
    fi
}

# 顯示當前喚醒設置
show_wake_schedule() {
    log_info "當前系統喚醒設置:"
    pmset -g sched
}

# 檢查權限
check_permissions() {
    if [[ $EUID -eq 0 ]]; then
        log_error "請不要使用 root 執行此腳本，需要時會自動請求 sudo 權限"
        exit 1
    fi
    
    # 測試 sudo 權限
    if ! sudo -n true 2>/dev/null; then
        log_info "需要管理員權限來設置系統喚醒"
        sudo -v
    fi
}

# 主函數
main() {
    local action="${1:-setup}"
    
    case "$action" in
        setup)
            log_info "========== 設置系統喚醒排程 =========="
            check_permissions
            
            # 清除舊設置
            clear_wake_schedule
            
            # 設置簽到喚醒（只設置一個統一的喚醒時間）
            # 使用較早的時間確保兩個排程都能執行
            set_wake_schedule "簽到" "$CHECKIN_HOUR" "$CHECKIN_MINUTE"
            
            log_info ""
            show_wake_schedule
            
            log_info ""
            log_info "💡 提示:"
            log_info "1. 系統會在簽到時間前 2 分鐘喚醒"
            log_info "2. 請確保 Mac 連接電源以保證喚醒功能正常"
            log_info "3. 在系統偏好設定 > 節能 中關閉 '顯示器進入睡眠' 可提高可靠性"
            ;;
            
        clear)
            log_info "========== 清除系統喚醒排程 =========="
            check_permissions
            clear_wake_schedule
            ;;
            
        show)
            log_info "========== 當前喚醒排程 =========="
            show_wake_schedule
            ;;
            
        *)
            echo "用法: $0 [setup|clear|show]"
            echo ""
            echo "命令:"
            echo "  setup   設置系統喚醒排程（預設）"
            echo "  clear   清除所有喚醒排程"
            echo "  show    顯示當前喚醒設置"
            exit 1
            ;;
    esac
}

# 執行主函數
main "$@"