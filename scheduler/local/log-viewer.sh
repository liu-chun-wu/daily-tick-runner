
#!/bin/bash

# 日誌檢視和管理工具
# 作者: Claude Code
# 用途: 檢視和管理自動打卡日誌

set -euo pipefail

# 配置
LOG_DIR="$HOME/.daily-tick-runner/logs"

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 輸出函數
info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# 檢查日誌目錄
check_log_dir() {
    if [[ ! -d "$LOG_DIR" ]]; then
        warning "日誌目錄不存在: $LOG_DIR"
        info "請先執行自動打卡程序或手動建立目錄"
        exit 1
    fi
}

# 顯示日誌概覽
show_overview() {
    info "日誌概覽"
    echo "日誌目錄: $LOG_DIR"
    echo
    
    if [[ -d "$LOG_DIR" ]]; then
        echo "可用的日誌文件:"
        ls -la "$LOG_DIR" 2>/dev/null || echo "  無日誌文件"
    else
        echo "日誌目錄不存在"
    fi
}

# 顯示最新日誌
show_latest() {
    check_log_dir
    
    local lines="${1:-50}"
    
    info "顯示最新 $lines 行日誌"
    echo
    
    # 顯示主日誌
    local latest_log=$(find "$LOG_DIR" -name "auto-punch-*.log" | sort | tail -1)
    if [[ -n "$latest_log" && -f "$latest_log" ]]; then
        echo -e "${CYAN}=== 主日誌 ($(basename "$latest_log")) ===${NC}"
        tail -n "$lines" "$latest_log" | while read -r line; do
            # 根據日誌級別着色
            if [[ $line =~ \[ERROR\] ]]; then
                echo -e "${RED}$line${NC}"
            elif [[ $line =~ \[WARNING\] ]]; then
                echo -e "${YELLOW}$line${NC}"
            elif [[ $line =~ \[INFO\] ]]; then
                echo -e "${GREEN}$line${NC}"
            else
                echo "$line"
            fi
        done
        echo
    fi
    
    # 顯示簽到日誌
    if [[ -f "$LOG_DIR/checkin.log" ]]; then
        echo -e "${CYAN}=== 簽到日誌 ===${NC}"
        tail -n 10 "$LOG_DIR/checkin.log"
        echo
    fi
    
    # 顯示簽退日誌
    if [[ -f "$LOG_DIR/checkout.log" ]]; then
        echo -e "${CYAN}=== 簽退日誌 ===${NC}"
        tail -n 10 "$LOG_DIR/checkout.log"
        echo
    fi
}

# 即時監控日誌
monitor_logs() {
    check_log_dir
    
    info "即時監控日誌 (Ctrl+C 停止)"
    echo
    
    # 監控主日誌
    local latest_log=$(find "$LOG_DIR" -name "auto-punch-*.log" | sort | tail -1)
    if [[ -n "$latest_log" && -f "$latest_log" ]]; then
        tail -f "$latest_log" | while read -r line; do
            # 根據日誌級別着色
            if [[ $line =~ \[ERROR\] ]]; then
                echo -e "${RED}$line${NC}"
            elif [[ $line =~ \[WARNING\] ]]; then
                echo -e "${YELLOW}$line${NC}"
            elif [[ $line =~ \[INFO\] ]]; then
                echo -e "${GREEN}$line${NC}"
            else
                echo "$line"
            fi
        done
    else
        warning "沒有找到可監控的日誌文件"
    fi
}

# 搜尋日誌
search_logs() {
    check_log_dir
    
    local pattern="$1"
    local days="${2:-7}"
    
    info "搜尋關鍵字: '$pattern' (最近 $days 天)"
    echo
    
    find "$LOG_DIR" -name "*.log" -mtime -"$days" -exec grep -l "$pattern" {} \; | while read -r file; do
        echo -e "${CYAN}=== $(basename "$file") ===${NC}"
        grep --color=always "$pattern" "$file" | tail -20
        echo
    done
}

# 統計資訊
show_statistics() {
    check_log_dir
    
    info "執行統計 (最近30天)"
    echo
    
    # 統計成功/失敗次數
    local success_count=0
    local error_count=0
    local checkin_count=0
    local checkout_count=0
    
    find "$LOG_DIR" -name "auto-punch-*.log" -mtime -30 -exec cat {} \; | while read -r line; do
        if [[ $line =~ "成功觸發 workflow: checkin" ]]; then
            ((checkin_count++))
        elif [[ $line =~ "成功觸發 workflow: checkout" ]]; then
            ((checkout_count++))
        elif [[ $line =~ "自動打卡執行成功" ]]; then
            ((success_count++))
        elif [[ $line =~ "自動打卡執行失敗" ]]; then
            ((error_count++))
        fi
    done 2>/dev/null
    
    echo "統計結果:"
    echo "  成功執行: $success_count 次"
    echo "  執行失敗: $error_count 次"
    echo "  簽到次數: $checkin_count 次"
    echo "  簽退次數: $checkout_count 次"
    
    # 檢查最近的錯誤
    echo
    info "最近錯誤 (最近7天):"
    find "$LOG_DIR" -name "*.log" -mtime -7 -exec grep -l "ERROR" {} \; | head -5 | while read -r file; do
        echo -e "${YELLOW}在 $(basename "$file") 中:${NC}"
        grep "ERROR" "$file" | tail -3
        echo
    done 2>/dev/null || echo "  無錯誤記錄"
}

# 清理舊日誌
cleanup_logs() {
    check_log_dir
    
    local days="${1:-30}"
    
    warning "將刪除 $days 天前的日誌文件"
    read -p "確定要繼續嗎? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "清理 $days 天前的日誌..."
        
        local deleted_count=0
        find "$LOG_DIR" -name "*.log" -mtime +"$days" -print0 | while IFS= read -r -d '' file; do
            echo "刪除: $(basename "$file")"
            rm "$file"
            ((deleted_count++))
        done
        
        success "日誌清理完成"
    else
        info "取消清理操作"
    fi
}

# 顯示今日日誌
show_today() {
    check_log_dir
    
    local today=$(date +%Y%m%d)
    
    info "今日日誌 ($today)"
    echo
    
    find "$LOG_DIR" -name "*.log" -newermt "$(date +%Y-%m-%d)" | while read -r file; do
        if [[ -s "$file" ]]; then
            echo -e "${CYAN}=== $(basename "$file") ===${NC}"
            cat "$file" | while read -r line; do
                if [[ $line =~ \[ERROR\] ]]; then
                    echo -e "${RED}$line${NC}"
                elif [[ $line =~ \[WARNING\] ]]; then
                    echo -e "${YELLOW}$line${NC}"
                elif [[ $line =~ \[INFO\] ]]; then
                    echo -e "${GREEN}$line${NC}"
                else
                    echo "$line"
                fi
            done
            echo
        fi
    done 2>/dev/null || echo "今日無日誌記錄"
}

# 顯示幫助
show_help() {
    echo "日誌檢視和管理工具"
    echo
    echo "用法: $0 [命令] [參數]"
    echo
    echo "命令:"
    echo "  overview                  顯示日誌概覽"
    echo "  latest [行數]             顯示最新日誌 (預設50行)"
    echo "  monitor                   即時監控日誌"
    echo "  search <關鍵字> [天數]     搜尋日誌 (預設7天)"
    echo "  stats                     顯示統計資訊"
    echo "  today                     顯示今日日誌"
    echo "  cleanup [天數]            清理舊日誌 (預設30天)"
    echo "  help                      顯示此幫助"
    echo
    echo "範例:"
    echo "  $0 latest                 # 顯示最新50行日誌"
    echo "  $0 latest 100             # 顯示最新100行日誌"
    echo "  $0 search 'ERROR'         # 搜尋錯誤記錄"
    echo "  $0 search 'checkin' 3     # 搜尋最近3天的簽到記錄"
    echo "  $0 cleanup 60             # 清理60天前的日誌"
}

# 主函數
main() {
    case "${1:-help}" in
        "overview")
            show_overview
            ;;
        "latest")
            show_latest "${2:-50}"
            ;;
        "monitor")
            monitor_logs
            ;;
        "search")
            if [[ -z "${2:-}" ]]; then
                error "請提供搜尋關鍵字"
                echo "用法: $0 search <關鍵字> [天數]"
                exit 1
            fi
            search_logs "$2" "${3:-7}"
            ;;
        "stats")
            show_statistics
            ;;
        "today")
            show_today
            ;;
        "cleanup")
            cleanup_logs "${2:-30}"
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# 執行主函數
main "$@"
