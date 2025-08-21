
#!/bin/bash

# 本機定時打卡設定腳本
# 作者: Claude Code
# 用途: 設定和管理 macOS launchd 定時任務

set -euo pipefail

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
LOG_DIR="$HOME/.daily-tick-runner/logs"

CHECKIN_PLIST="com.daily-tick-runner.checkin.plist"
CHECKOUT_PLIST="com.daily-tick-runner.checkout.plist"

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# 檢查系統需求
check_requirements() {
    info "檢查系統需求..."
    
    # 檢查 GitHub CLI
    if ! command -v gh &> /dev/null; then
        error "GitHub CLI 未安裝"
        info "請執行以下命令安裝:"
        echo "  brew install gh"
        exit 1
    fi
    
    # 檢查 GitHub CLI 登入狀態
    if ! gh auth status &> /dev/null; then
        error "GitHub CLI 未登入"
        info "請執行以下命令登入:"
        echo "  gh auth login"
        exit 1
    fi
    
    # 檢查腳本是否存在
    if [[ ! -f "$SCRIPT_DIR/auto-punch.sh" ]]; then
        error "自動打卡腳本不存在: $SCRIPT_DIR/auto-punch.sh"
        exit 1
    fi
    
    # 檢查腳本是否可執行
    if [[ ! -x "$SCRIPT_DIR/auto-punch.sh" ]]; then
        warning "自動打卡腳本不可執行，正在設定執行權限..."
        chmod +x "$SCRIPT_DIR/auto-punch.sh"
    fi
    
    success "系統需求檢查完成"
}

# 建立必要目錄
create_directories() {
    info "建立必要目錄..."
    
    mkdir -p "$LAUNCH_AGENTS_DIR"
    mkdir -p "$LOG_DIR"
    
    success "目錄建立完成"
}

# 更新 plist 文件路徑
update_plist_paths() {
    local plist_file="$1"
    local temp_file="/tmp/$(basename "$plist_file")"
    
    # 替換路徑中的用戶名
    sed "s|/Users/jeffery.liu|$HOME|g" "$SCRIPT_DIR/$plist_file" > "$temp_file"
    
    # 替換專案路徑
    sed -i '' "s|/Users/jeffery.liu/Desktop/daily-tick-runner|$PROJECT_DIR|g" "$temp_file"
    
    echo "$temp_file"
}

# 安裝定時任務
install_scheduler() {
    info "安裝本機定時打卡任務..."
    
    check_requirements
    create_directories
    
    # 處理簽到任務
    info "安裝簽到任務..."
    checkin_temp=$(update_plist_paths "$CHECKIN_PLIST")
    cp "$checkin_temp" "$LAUNCH_AGENTS_DIR/$CHECKIN_PLIST"
    rm "$checkin_temp"
    
    # 處理簽退任務
    info "安裝簽退任務..."
    checkout_temp=$(update_plist_paths "$CHECKOUT_PLIST")
    cp "$checkout_temp" "$LAUNCH_AGENTS_DIR/$CHECKOUT_PLIST"
    rm "$checkout_temp"
    
    # 載入任務
    launchctl load "$LAUNCH_AGENTS_DIR/$CHECKIN_PLIST" 2>/dev/null || true
    launchctl load "$LAUNCH_AGENTS_DIR/$CHECKOUT_PLIST" 2>/dev/null || true
    
    success "定時任務安裝完成"
    info "簽到時間: 週一到週五 08:30"
    info "簽退時間: 週一到週五 18:00"
}

# 卸載定時任務
uninstall_scheduler() {
    info "卸載本機定時打卡任務..."
    
    # 卸載任務
    launchctl unload "$LAUNCH_AGENTS_DIR/$CHECKIN_PLIST" 2>/dev/null || true
    launchctl unload "$LAUNCH_AGENTS_DIR/$CHECKOUT_PLIST" 2>/dev/null || true
    
    # 刪除文件
    rm -f "$LAUNCH_AGENTS_DIR/$CHECKIN_PLIST"
    rm -f "$LAUNCH_AGENTS_DIR/$CHECKOUT_PLIST"
    
    success "定時任務卸載完成"
}

# 啟用定時任務
enable_scheduler() {
    info "啟用定時打卡任務..."
    
    launchctl load "$LAUNCH_AGENTS_DIR/$CHECKIN_PLIST" 2>/dev/null || true
    launchctl load "$LAUNCH_AGENTS_DIR/$CHECKOUT_PLIST" 2>/dev/null || true
    
    success "定時任務已啟用"
}

# 停用定時任務
disable_scheduler() {
    info "停用定時打卡任務..."
    
    launchctl unload "$LAUNCH_AGENTS_DIR/$CHECKIN_PLIST" 2>/dev/null || true
    launchctl unload "$LAUNCH_AGENTS_DIR/$CHECKOUT_PLIST" 2>/dev/null || true
    
    success "定時任務已停用"
}

# 查看狀態
show_status() {
    info "本機定時打卡狀態:"
    echo
    
    # 檢查文件是否存在
    if [[ -f "$LAUNCH_AGENTS_DIR/$CHECKIN_PLIST" ]]; then
        echo "✅ 簽到任務已安裝"
    else
        echo "❌ 簽到任務未安裝"
    fi
    
    if [[ -f "$LAUNCH_AGENTS_DIR/$CHECKOUT_PLIST" ]]; then
        echo "✅ 簽退任務已安裝"
    else
        echo "❌ 簽退任務未安裝"
    fi
    
    echo
    
    # 檢查任務狀態
    info "launchctl 狀態:"
    launchctl list | grep "daily-tick-runner" || echo "  無運行中的任務"
    
    echo
    
    # 顯示日誌位置
    info "日誌文件位置:"
    echo "  主日誌: $LOG_DIR/"
    echo "  簽到日誌: $LOG_DIR/checkin.log"
    echo "  簽退日誌: $LOG_DIR/checkout.log"
}

# 測試腳本
test_script() {
    info "測試自動打卡腳本..."
    
    check_requirements
    
    info "執行測試運行..."
    "$SCRIPT_DIR/auto-punch.sh"
    
    success "測試完成"
}

# 顯示幫助
show_help() {
    echo "本機定時打卡管理工具"
    echo
    echo "用法: $0 [命令]"
    echo
    echo "命令:"
    echo "  install     安裝定時任務"
    echo "  uninstall   卸載定時任務"
    echo "  enable      啟用定時任務"
    echo "  disable     停用定時任務"
    echo "  status      查看狀態"
    echo "  test        測試腳本"
    echo "  help        顯示此幫助"
    echo
    echo "範例:"
    echo "  $0 install    # 安裝並啟用定時任務"
    echo "  $0 status     # 查看目前狀態"
    echo "  $0 disable    # 臨時停用任務"
}

# 主函數
main() {
    case "${1:-help}" in
        "install")
            install_scheduler
            ;;
        "uninstall")
            uninstall_scheduler
            ;;
        "enable")
            enable_scheduler
            ;;
        "disable")
            disable_scheduler
            ;;
        "status")
            show_status
            ;;
        "test")
            test_script
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# 執行主函數
main "$@"
