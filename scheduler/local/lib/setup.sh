
#!/bin/bash

# 本機定時打卡設定腳本
# 作者: Claude Code
# 用途: 設定和管理 macOS launchd 定時任務

set -euo pipefail

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
LOG_DIR="$HOME/.daily-tick-runner/logs"

CHECKIN_PLIST="checkin.plist"
CHECKOUT_PLIST="checkout.plist"

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
    if [[ ! -f "$SCRIPT_DIR/../bin/trigger.sh" ]]; then
        error "自動打卡腳本不存在: $SCRIPT_DIR/../bin/trigger.sh"
        exit 1
    fi
    
    # 檢查腳本是否可執行
    if [[ ! -x "$SCRIPT_DIR/../bin/trigger.sh" ]]; then
        warning "自動打卡腳本不可執行，正在設定執行權限..."
        chmod +x "$SCRIPT_DIR/../bin/trigger.sh"
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

# 檢查安裝狀態
check_installation_status() {
    local checkin_file_exists=false
    local checkout_file_exists=false
    local checkin_running=false
    local checkout_running=false
    
    # 檢查檔案是否存在
    if [[ -f "$LAUNCH_AGENTS_DIR/$CHECKIN_PLIST" ]]; then
        checkin_file_exists=true
    fi
    
    if [[ -f "$LAUNCH_AGENTS_DIR/$CHECKOUT_PLIST" ]]; then
        checkout_file_exists=true
    fi
    
    # 檢查任務是否正在運行
    if launchctl list | grep -q "com.daily-tick-runner.checkin"; then
        checkin_running=true
    fi
    
    if launchctl list | grep -q "com.daily-tick-runner.checkout"; then
        checkout_running=true
    fi
    
    # 設定回傳值
    local status="none"
    if [[ "$checkin_file_exists" == true ]] && [[ "$checkout_file_exists" == true ]]; then
        # 如果兩個檔案都存在，就算是完全安裝（不需要都在運行）
        status="fully_installed"
    elif [[ "$checkin_file_exists" == true ]] || [[ "$checkout_file_exists" == true ]]; then
        status="partially_installed"
    fi
    
    echo "$status"
    
    # 也設定全域變數供其他函數使用
    INSTALL_STATUS="$status"
    CHECKIN_FILE_EXISTS="$checkin_file_exists"
    CHECKOUT_FILE_EXISTS="$checkout_file_exists"
    CHECKIN_RUNNING="$checkin_running"
    CHECKOUT_RUNNING="$checkout_running"
}

# 更新 plist 文件路徑
update_plist_paths() {
    local plist_file="$1"
    local temp_file="/tmp/$(basename "$plist_file")"
    
    # 替換路徑中的用戶名
    sed "s|/Users/jeffery.liu|$HOME|g" "$SCRIPT_DIR/../config/launchd/$plist_file" > "$temp_file"
    
    # 替換專案路徑
    sed -i '' "s|/Users/jeffery.liu/Projects/daily-tick-runner|$PROJECT_DIR|g" "$temp_file"
    
    echo "$temp_file"
}

# 安裝定時任務
install_scheduler() {
    info "安裝本機定時打卡任務..."
    
    # 檢查當前安裝狀態
    local status=$(check_installation_status)
    
    if [[ "$status" != "none" ]]; then
        warning "檢測到已存在的定時任務"
        echo "當前狀態:"
        
        # 直接檢查而不依賴全域變數
        local checkin_exists=false
        local checkout_exists=false
        local checkin_running=false
        local checkout_running=false
        
        if [[ -f "$LAUNCH_AGENTS_DIR/$CHECKIN_PLIST" ]]; then
            checkin_exists=true
        fi
        if [[ -f "$LAUNCH_AGENTS_DIR/$CHECKOUT_PLIST" ]]; then
            checkout_exists=true
        fi
        if launchctl list | grep -q "com.daily-tick-runner.checkin"; then
            checkin_running=true
        fi
        if launchctl list | grep -q "com.daily-tick-runner.checkout"; then
            checkout_running=true
        fi
        
        if [[ "$checkin_exists" == true ]] || [[ "$checkin_running" == true ]]; then
            echo "  簽到任務: 檔案存在=$checkin_exists, 運行中=$checkin_running"
        fi
        if [[ "$checkout_exists" == true ]] || [[ "$checkout_running" == true ]]; then
            echo "  簽退任務: 檔案存在=$checkout_exists, 運行中=$checkout_running"
        fi
        echo
        read -p "是否要重新安裝? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "取消安裝"
            return 0
        fi
        info "正在卸載舊的任務..."
        if ! uninstall_scheduler; then
            error "卸載舊任務失敗，安裝中止"
            return 1
        fi
    fi
    
    # 檢查系統需求
    if ! check_requirements; then
        error "系統需求檢查失敗，安裝中止"
        return 1
    fi
    
    if ! create_directories; then
        error "建立目錄失敗，安裝中止"
        return 1
    fi
    
    local install_success=true
    
    # 處理簽到任務
    info "安裝簽到任務..."
    if ! checkin_temp=$(update_plist_paths "$CHECKIN_PLIST"); then
        error "生成簽到任務配置失敗"
        install_success=false
    else
        # 直接複製已配置好的檔案（不需要額外添加參數）
        if cp "$checkin_temp" "$LAUNCH_AGENTS_DIR/$CHECKIN_PLIST"; then
            success "簽到任務配置已安裝"
            rm -f "$checkin_temp"
        else
            error "簽到任務配置安裝失敗"
            rm -f "$checkin_temp"
            install_success=false
        fi
    fi
    
    # 處理簽退任務
    info "安裝簽退任務..."
    if ! checkout_temp=$(update_plist_paths "$CHECKOUT_PLIST"); then
        error "生成簽退任務配置失敗"
        install_success=false
    else
        # 直接複製已配置好的檔案（不需要額外添加參數）
        if cp "$checkout_temp" "$LAUNCH_AGENTS_DIR/$CHECKOUT_PLIST"; then
            success "簽退任務配置已安裝"
            rm -f "$checkout_temp"
        else
            error "簽退任務配置安裝失敗"
            rm -f "$checkout_temp"
            install_success=false
        fi
    fi
    
    if [[ "$install_success" == false ]]; then
        error "配置文件安裝失敗，正在清理..."
        uninstall_scheduler
        return 1
    fi
    
    # 載入任務
    info "載入 launchd 任務..."
    local load_success=true
    local load_count=0
    
    # 載入簽到任務
    if launchctl load "$LAUNCH_AGENTS_DIR/$CHECKIN_PLIST" 2>/dev/null; then
        success "簽到任務載入成功"
        ((load_count++))
    else
        if launchctl list | grep -q "com.daily-tick-runner.checkin"; then
            warning "簽到任務已在運行中"
            ((load_count++))
        else
            error "簽到任務載入失敗"
            load_success=false
        fi
    fi
    
    # 載入簽退任務
    if launchctl load "$LAUNCH_AGENTS_DIR/$CHECKOUT_PLIST" 2>/dev/null; then
        success "簽退任務載入成功"
        ((load_count++))
    else
        if launchctl list | grep -q "com.daily-tick-runner.checkout"; then
            warning "簽退任務已在運行中"
            ((load_count++))
        else
            error "簽退任務載入失敗"
            load_success=false
        fi
    fi
    
    # 驗證最終結果
    local final_status=$(check_installation_status)
    
    if [[ "$final_status" == "fully_installed" ]]; then
        success "定時任務安裝完成 (載入了 $load_count 個任務)"
        
        # 載入配置以顯示正確時間
        source "$SCRIPT_DIR/../config/schedule.conf" 2>/dev/null || true
        info "簽到時間: 週一到週五 $(format_time $CHECKIN_HOUR $CHECKIN_MINUTE)"
        info "簽退時間: 週一到週五 $(format_time $CHECKOUT_HOUR $CHECKOUT_MINUTE)"
        return 0
    else
        error "定時任務安裝未完全成功"
        info "執行 './manage status' 查看詳細狀態"
        if [[ $load_count -eq 0 ]]; then
            error "建議執行清理並重試: ./manage uninstall && ./manage install"
        fi
        return 1
    fi
}

# 卸載定時任務
uninstall_scheduler() {
    info "卸載本機定時打卡任務..."
    
    # 檢查當前安裝狀態
    local status=$(check_installation_status)
    
    if [[ "$status" == "none" ]]; then
        warning "未檢測到已安裝的定時任務"
        info "沒有需要卸載的內容"
        return 0
    fi
    
    # 直接檢查狀態，不依賴全域變數
    local checkin_exists=false
    local checkout_exists=false
    local checkin_running=false
    local checkout_running=false
    
    if [[ -f "$LAUNCH_AGENTS_DIR/$CHECKIN_PLIST" ]]; then
        checkin_exists=true
    fi
    if [[ -f "$LAUNCH_AGENTS_DIR/$CHECKOUT_PLIST" ]]; then
        checkout_exists=true
    fi
    if launchctl list | grep -q "com.daily-tick-runner.checkin"; then
        checkin_running=true
    fi
    if launchctl list | grep -q "com.daily-tick-runner.checkout"; then
        checkout_running=true
    fi
    
    local unload_count=0
    local file_count=0
    
    # 卸載任務
    info "正在停止運行中的任務..."
    if [[ "$checkin_running" == true ]]; then
        if launchctl unload "$LAUNCH_AGENTS_DIR/$CHECKIN_PLIST" 2>/dev/null; then
            success "簽到任務已停止"
            ((unload_count++))
        else
            warning "簽到任務停止失敗，但繼續處理"
        fi
    fi
    
    if [[ "$checkout_running" == true ]]; then
        if launchctl unload "$LAUNCH_AGENTS_DIR/$CHECKOUT_PLIST" 2>/dev/null; then
            success "簽退任務已停止"
            ((unload_count++))
        else
            warning "簽退任務停止失敗，但繼續處理"
        fi
    fi
    
    # 刪除文件
    info "正在清理配置檔案..."
    if [[ "$checkin_exists" == true ]]; then
        if rm -f "$LAUNCH_AGENTS_DIR/$CHECKIN_PLIST"; then
            info "簽到配置檔案已刪除"
            ((file_count++))
        else
            error "簽到配置檔案刪除失敗"
        fi
    fi
    
    if [[ "$checkout_exists" == true ]]; then
        if rm -f "$LAUNCH_AGENTS_DIR/$CHECKOUT_PLIST"; then
            info "簽退配置檔案已刪除"
            ((file_count++))
        else
            error "簽退配置檔案刪除失敗"
        fi
    fi
    
    # 驗證卸載結果
    local final_status=$(check_installation_status)
    if [[ "$final_status" == "none" ]]; then
        success "定時任務卸載完成 (停止了 $unload_count 個任務，刪除了 $file_count 個檔案)"
    else
        warning "卸載可能未完全成功，請檢查狀態"
        info "執行 './manage status' 查看詳細狀態"
    fi
}

# 啟用定時任務
enable_scheduler() {
    info "啟用定時打卡任務..."
    
    # 檢查當前安裝狀態
    local status=$(check_installation_status)
    
    if [[ "$status" == "none" ]]; then
        error "未檢測到已安裝的定時任務"
        info "請先執行: ./manage install"
        return 1
    fi
    
    # 直接檢查狀態，不依賴全域變數
    local checkin_exists=false
    local checkout_exists=false
    local checkin_running=false
    local checkout_running=false
    
    if [[ -f "$LAUNCH_AGENTS_DIR/$CHECKIN_PLIST" ]]; then
        checkin_exists=true
    fi
    if [[ -f "$LAUNCH_AGENTS_DIR/$CHECKOUT_PLIST" ]]; then
        checkout_exists=true
    fi
    if launchctl list | grep -q "com.daily-tick-runner.checkin"; then
        checkin_running=true
    fi
    if launchctl list | grep -q "com.daily-tick-runner.checkout"; then
        checkout_running=true
    fi
    
    local load_count=0
    local skip_count=0
    local error_count=0
    
    # 啟用簽到任務
    if [[ "$checkin_exists" == true ]]; then
        if [[ "$checkin_running" == true ]]; then
            info "簽到任務已在運行中，跳過"
            ((skip_count++))
        else
            if launchctl load "$LAUNCH_AGENTS_DIR/$CHECKIN_PLIST" 2>/dev/null; then
                success "簽到任務已啟用"
                ((load_count++))
            else
                error "簽到任務啟用失敗"
                ((error_count++))
            fi
        fi
    else
        error "簽到配置檔案不存在"
        ((error_count++))
    fi
    
    # 啟用簽退任務
    if [[ "$checkout_exists" == true ]]; then
        if [[ "$checkout_running" == true ]]; then
            info "簽退任務已在運行中，跳過"
            ((skip_count++))
        else
            if launchctl load "$LAUNCH_AGENTS_DIR/$CHECKOUT_PLIST" 2>/dev/null; then
                success "簽退任務已啟用"
                ((load_count++))
            else
                error "簽退任務啟用失敗"
                ((error_count++))
            fi
        fi
    else
        error "簽退配置檔案不存在"
        ((error_count++))
    fi
    
    # 結果報告
    if [[ $error_count -gt 0 ]]; then
        error "定時任務啟用過程中發生錯誤 (成功: $load_count, 跳過: $skip_count, 錯誤: $error_count)"
        info "執行 './manage status' 查看詳細狀態"
        return 1
    elif [[ $load_count -gt 0 ]]; then
        success "定時任務已啟用 (啟用了 $load_count 個任務，跳過了 $skip_count 個已運行的任務)"
    else
        info "所有任務都已在運行中，無需啟用"
    fi
}

# 停用定時任務
disable_scheduler() {
    info "停用定時打卡任務..."
    
    # 檢查當前安裝狀態
    local status=$(check_installation_status)
    
    if [[ "$status" == "none" ]]; then
        warning "未檢測到已安裝的定時任務"
        info "沒有需要停用的內容"
        return 0
    fi
    
    # 直接檢查狀態，不依賴全域變數
    local checkin_exists=false
    local checkout_exists=false
    local checkin_running=false
    local checkout_running=false
    
    if [[ -f "$LAUNCH_AGENTS_DIR/$CHECKIN_PLIST" ]]; then
        checkin_exists=true
    fi
    if [[ -f "$LAUNCH_AGENTS_DIR/$CHECKOUT_PLIST" ]]; then
        checkout_exists=true
    fi
    if launchctl list | grep -q "com.daily-tick-runner.checkin"; then
        checkin_running=true
    fi
    if launchctl list | grep -q "com.daily-tick-runner.checkout"; then
        checkout_running=true
    fi
    
    local unload_count=0
    local skip_count=0
    local error_count=0
    
    # 停用簽到任務
    if [[ "$checkin_exists" == true ]]; then
        if [[ "$checkin_running" == false ]]; then
            info "簽到任務未在運行，跳過"
            ((skip_count++))
        else
            if launchctl unload "$LAUNCH_AGENTS_DIR/$CHECKIN_PLIST" 2>/dev/null; then
                success "簽到任務已停用"
                ((unload_count++))
            else
                error "簽到任務停用失敗"
                ((error_count++))
            fi
        fi
    else
        warning "簽到配置檔案不存在，無法停用"
        ((skip_count++))
    fi
    
    # 停用簽退任務
    if [[ "$checkout_exists" == true ]]; then
        if [[ "$checkout_running" == false ]]; then
            info "簽退任務未在運行，跳過"
            ((skip_count++))
        else
            if launchctl unload "$LAUNCH_AGENTS_DIR/$CHECKOUT_PLIST" 2>/dev/null; then
                success "簽退任務已停用"
                ((unload_count++))
            else
                error "簽退任務停用失敗"
                ((error_count++))
            fi
        fi
    else
        warning "簽退配置檔案不存在，無法停用"
        ((skip_count++))
    fi
    
    # 結果報告
    if [[ $error_count -gt 0 ]]; then
        error "定時任務停用過程中發生錯誤 (成功: $unload_count, 跳過: $skip_count, 錯誤: $error_count)"
        info "執行 './manage status' 查看詳細狀態"
        return 1
    elif [[ $unload_count -gt 0 ]]; then
        success "定時任務已停用 (停用了 $unload_count 個任務，跳過了 $skip_count 個未運行的任務)"
    else
        info "所有任務都已停用，無需操作"
    fi
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
    
    # 檢查 GitHub CLI 狀態
    info "GitHub CLI 狀態:"
    if command -v gh &> /dev/null; then
        if gh auth status &> /dev/null; then
            echo "✅ GitHub CLI 已認證"
            # 顯示當前登入的用戶
            gh auth status 2>&1 | grep "Logged in" | head -1 || true
        else
            echo "❌ GitHub CLI 未認證 (請執行: gh auth login)"
        fi
    else
        echo "❌ GitHub CLI 未安裝 (請執行: brew install gh)"
    fi
    
    echo
    
    # 顯示最後執行時間
    info "最近執行記錄:"
    if [[ -d "$LOG_DIR" ]]; then
        # 找最新的日誌文件
        local latest_log=$(find "$LOG_DIR" -name "auto-punch-*.log" 2>/dev/null | sort | tail -1)
        if [[ -n "$latest_log" && -f "$latest_log" ]]; then
            # 顯示最後執行時間
            local last_run=$(grep "自動打卡程序開始" "$latest_log" 2>/dev/null | tail -1 | cut -d' ' -f1-2)
            if [[ -n "$last_run" ]]; then
                echo "  最後執行時間: $last_run"
            fi
            
            # 顯示最近的成功/失敗記錄
            local recent_success=$(grep "自動打卡執行成功" "$latest_log" 2>/dev/null | tail -1)
            local recent_error=$(grep "自動打卡執行失敗" "$latest_log" 2>/dev/null | tail -1)
            
            if [[ -n "$recent_success" ]]; then
                echo "  最近成功: $(echo "$recent_success" | cut -d' ' -f1-2)"
            fi
            
            if [[ -n "$recent_error" ]]; then
                echo "  ⚠️  最近失敗: $(echo "$recent_error" | cut -d' ' -f1-2)"
            fi
        else
            echo "  無執行記錄"
        fi
    else
        echo "  無日誌目錄"
    fi
    
    echo
    
    # 顯示排程狀態
    info "排程狀態:"
    source "$SCRIPT_DIR/../config/schedule.conf" 2>/dev/null || true
    
    local current_hour=$(date +%H | sed 's/^0//')
    local current_minute=$(date +%M | sed 's/^0//')
    local current_time=$(printf "%02d:%02d" $current_hour $current_minute)
    local day_of_week=$(date +%u)
    
    echo "  當前時間: $current_time"
    
    # 檢查是否為工作日
    if is_workday; then
        echo "  📅 今天是工作日"
    else
        echo "  📅 今天不是工作日"
    fi
    
    echo
    info "排程時間:"
    echo "  簽到: 週一至週五 $(format_time $CHECKIN_HOUR $CHECKIN_MINUTE)"
    echo "  簽退: 週一至週五 $(format_time $CHECKOUT_HOUR $CHECKOUT_MINUTE)"
    
    # 計算下次執行時間
    local current_hour=$(date +%H | sed 's/^0//')
    local current_minute=$(date +%M | sed 's/^0//')
    local day_of_week=$(date +%u)
    
    if [[ $day_of_week -le 5 ]]; then  # 工作日
        if [[ $current_hour -lt $CHECKIN_HOUR ]] || 
           [[ $current_hour -eq $CHECKIN_HOUR && $current_minute -lt $CHECKIN_MINUTE ]]; then
            echo "  下次執行: 今日 $(format_time $CHECKIN_HOUR $CHECKIN_MINUTE) (簽到)"
        elif [[ $current_hour -lt $CHECKOUT_HOUR ]] || 
             [[ $current_hour -eq $CHECKOUT_HOUR && $current_minute -lt $CHECKOUT_MINUTE ]]; then
            echo "  下次執行: 今日 $(format_time $CHECKOUT_HOUR $CHECKOUT_MINUTE) (簽退)"
        else
            # 明天
            if [[ $day_of_week -eq 5 ]]; then
                echo "  下次執行: 下週一 $(format_time $CHECKIN_HOUR $CHECKIN_MINUTE) (簽到)"
            else
                echo "  下次執行: 明日 $(format_time $CHECKIN_HOUR $CHECKIN_MINUTE) (簽到)"
            fi
        fi
    else  # 週末
        echo "  下次執行: 下週一 $(format_time $CHECKIN_HOUR $CHECKIN_MINUTE) (簽到)"
    fi
    
    echo
    
    # 顯示日誌位置
    info "日誌文件位置:"
    echo "  主日誌: $LOG_DIR/"
    echo "  簽到日誌: $LOG_DIR/checkin.log"
    echo "  簽退日誌: $LOG_DIR/checkout.log"
    echo
    echo "提示: 使用 './manage logs latest' 查看最新日誌"
}

# 測試腳本
test_script() {
    info "測試自動打卡腳本..."
    
    check_requirements
    
    # 需要指定參數
    if [[ $# -lt 1 ]]; then
        error "測試需要指定動作類型"
        echo "用法: $0 test <checkin|checkout>"
        exit 1
    fi
    
    local action_type="$1"
    info "執行測試運行: $action_type"
    "$SCRIPT_DIR/../bin/trigger.sh" "$action_type"
    
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
            shift || true
            test_script "$@"
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# 執行主函數
main "$@"
