
#!/bin/bash

# 更新定時打卡時間設定
# 作者: Claude Code
# 用途: 便捷更新所有相關文件的時間設定

set -euo pipefail

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

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

# 載入當前配置
source "$SCRIPT_DIR/../config/schedule.conf"

# 顯示當前配置
show_current_config() {
    echo -e "${CYAN}========== 當前時間配置 ==========${NC}"
    show_config
    echo -e "${CYAN}===================================${NC}"
    echo
}

# 更新配置文件
update_config_file() {
    local new_checkin_hour="$1"
    local new_checkin_minute="$2"
    local new_checkout_hour="$3"
    local new_checkout_minute="$4"
    local new_workdays="$5"
    
    # 備份原配置
    cp "$SCRIPT_DIR/../config/schedule.conf" "$SCRIPT_DIR/../config/schedule.conf.bak"
    
    # 更新簽到時間
    sed -i '' "s/^CHECKIN_HOUR=.*/CHECKIN_HOUR=$new_checkin_hour/" "$SCRIPT_DIR/../config/schedule.conf"
    sed -i '' "s/^CHECKIN_MINUTE=.*/CHECKIN_MINUTE=$new_checkin_minute/" "$SCRIPT_DIR/../config/schedule.conf"
    
    # 更新簽退時間
    sed -i '' "s/^CHECKOUT_HOUR=.*/CHECKOUT_HOUR=$new_checkout_hour/" "$SCRIPT_DIR/../config/schedule.conf"
    sed -i '' "s/^CHECKOUT_MINUTE=.*/CHECKOUT_MINUTE=$new_checkout_minute/" "$SCRIPT_DIR/../config/schedule.conf"
    
    # 更新工作天
    if [[ -n "$new_workdays" ]]; then
        sed -i '' "s/^WORKDAYS=.*/WORKDAYS=($new_workdays)/" "$SCRIPT_DIR/../config/schedule.conf"
    fi
    
    success "配置文件已更新"
}

# 更新 plist 文件
update_plist_files() {
    local checkin_hour="$1"
    local checkin_minute="$2"
    local checkout_hour="$3"
    local checkout_minute="$4"
    
    info "更新 plist 文件..."
    
    # 重新載入配置以獲取最新的 WORKDAYS
    source "$SCRIPT_DIR/../config/schedule.conf"
    
    # 創建臨時 plist 文件
    
    # 簽到 plist
    cat > "$SCRIPT_DIR/../config/launchd/checkin.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.daily-tick-runner.checkin</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>$PROJECT_DIR/scheduler/local/bin/trigger.sh</string>
        <string>checkin</string>
    </array>
    
    <key>StartCalendarInterval</key>
    <array>
EOF
    
    # 根據 WORKDAYS 設定添加工作天
    for day in "${WORKDAYS[@]}"; do
        cat >> "$SCRIPT_DIR/../config/launchd/checkin.plist" << EOF
        <dict>
            <key>Hour</key>
            <integer>$checkin_hour</integer>
            <key>Minute</key>
            <integer>$checkin_minute</integer>
            <key>Weekday</key>
            <integer>$day</integer>
        </dict>
EOF
    done
    
    cat >> "$SCRIPT_DIR/../config/launchd/checkin.plist" << EOF
    </array>
    
    <key>StandardOutPath</key>
    <string>$HOME/.daily-tick-runner/logs/checkin.log</string>
    
    <key>StandardErrorPath</key>
    <string>$HOME/.daily-tick-runner/logs/checkin.error.log</string>
    
    <key>RunAtLoad</key>
    <false/>
    
    <key>KeepAlive</key>
    <false/>
    
    <key>WorkingDirectory</key>
    <string>$PROJECT_DIR</string>
    
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin</string>
    </dict>
</dict>
</plist>
EOF
    
    # 簽退 plist
    cat > "$SCRIPT_DIR/../config/launchd/checkout.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.daily-tick-runner.checkout</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>$PROJECT_DIR/scheduler/local/bin/trigger.sh</string>
        <string>checkout</string>
    </array>
    
    <key>StartCalendarInterval</key>
    <array>
EOF
    
    # 根據 WORKDAYS 設定添加工作天
    for day in "${WORKDAYS[@]}"; do
        cat >> "$SCRIPT_DIR/../config/launchd/checkout.plist" << EOF
        <dict>
            <key>Hour</key>
            <integer>$checkout_hour</integer>
            <key>Minute</key>
            <integer>$checkout_minute</integer>
            <key>Weekday</key>
            <integer>$day</integer>
        </dict>
EOF
    done
    
    cat >> "$SCRIPT_DIR/../config/launchd/checkout.plist" << EOF
    </array>
    
    <key>StandardOutPath</key>
    <string>$HOME/.daily-tick-runner/logs/checkout.log</string>
    
    <key>StandardErrorPath</key>
    <string>$HOME/.daily-tick-runner/logs/checkout.error.log</string>
    
    <key>RunAtLoad</key>
    <false/>
    
    <key>KeepAlive</key>
    <false/>
    
    <key>WorkingDirectory</key>
    <string>$PROJECT_DIR</string>
    
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin</string>
    </dict>
</dict>
</plist>
EOF
    
    # plist 文件已直接生成在 config/launchd 目錄中
    
    success "plist 文件已更新"
}

# 重新載入 launchd 任務
reload_launchd() {
    info "重新載入 launchd 任務..."
    
    # 檢查是否已安裝
    if [[ -f "$LAUNCH_AGENTS_DIR/checkin.plist" ]]; then
        # 卸載舊任務
        launchctl unload "$LAUNCH_AGENTS_DIR/checkin.plist" 2>/dev/null || true
        launchctl unload "$LAUNCH_AGENTS_DIR/checkout.plist" 2>/dev/null || true
        
        # 複製新的 plist 文件
        cp "$SCRIPT_DIR/../config/launchd/checkin.plist" "$LAUNCH_AGENTS_DIR/checkin.plist"
        cp "$SCRIPT_DIR/../config/launchd/checkout.plist" "$LAUNCH_AGENTS_DIR/checkout.plist"
        
        # 載入新任務
        launchctl load "$LAUNCH_AGENTS_DIR/checkin.plist"
        launchctl load "$LAUNCH_AGENTS_DIR/checkout.plist"
        
        success "launchd 任務已重新載入"
    else
        warning "launchd 任務尚未安裝，請先執行: ../manage install"
    fi
}

# 互動式更新
interactive_update() {
    show_current_config
    
    echo "請輸入新的時間設定 (直接按 Enter 保持原設定):"
    echo
    
    # 簽到時間
    read -p "簽到小時 [當前: $CHECKIN_HOUR]: " new_checkin_hour
    new_checkin_hour=${new_checkin_hour:-$CHECKIN_HOUR}
    
    read -p "簽到分鐘 [當前: $CHECKIN_MINUTE]: " new_checkin_minute
    new_checkin_minute=${new_checkin_minute:-$CHECKIN_MINUTE}
    
    # 簽退時間
    read -p "簽退小時 [當前: $CHECKOUT_HOUR]: " new_checkout_hour
    new_checkout_hour=${new_checkout_hour:-$CHECKOUT_HOUR}
    
    read -p "簽退分鐘 [當前: $CHECKOUT_MINUTE]: " new_checkout_minute
    new_checkout_minute=${new_checkout_minute:-$CHECKOUT_MINUTE}
    
    # 工作天設定
    echo
    echo -e "${CYAN}[工作天設定]${NC}"
    echo -n "當前工作天: "
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
    
    read -p "是否要修改工作天? (y/N): " -n 1 -r
    echo
    
    local new_workdays=""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "請選擇需要打卡的工作天："
        echo "  1 = 週一"
        echo "  2 = 週二"
        echo "  3 = 週三"
        echo "  4 = 週四"
        echo "  5 = 週五"
        echo "  6 = 週六"
        echo "  7 = 週日"
        echo
        read -p "輸入數字（用空格分隔，例如: 1 3 5）: " selected_days
        if [[ -n "$selected_days" ]]; then
            new_workdays="$selected_days"
        else
            new_workdays="${WORKDAYS[@]}"
        fi
    else
        new_workdays="${WORKDAYS[@]}"
    fi
    
    # 確認更新
    echo
    echo -e "${YELLOW}新的設定:${NC}"
    echo "簽到: $(printf "%02d:%02d" $new_checkin_hour $new_checkin_minute)"
    echo "簽退: $(printf "%02d:%02d" $new_checkout_hour $new_checkout_minute)"
    echo -n "工作天: "
    for day in $new_workdays; do
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
    
    read -p "確定要更新嗎? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        update_config_file "$new_checkin_hour" "$new_checkin_minute" "$new_checkout_hour" "$new_checkout_minute" "$new_workdays"
        update_plist_files "$new_checkin_hour" "$new_checkin_minute" "$new_checkout_hour" "$new_checkout_minute"
        reload_launchd
        
        echo
        success "設定已更新完成！"
        echo
        echo "新的設定:"
        source "$SCRIPT_DIR/../config/schedule.conf"
        show_config
    else
        info "取消更新"
    fi
}

# 快速更新 (命令行參數)
quick_update() {
    if [[ $# -ne 4 ]]; then
        error "參數錯誤"
        echo "用法: $0 <簽到小時> <簽到分鐘> <簽退小時> <簽退分鐘>"
        echo "範例: $0 9 0 18 30  # 設定 9:00 簽到, 18:30 簽退"
        exit 1
    fi
    
    local new_checkin_hour="$1"
    local new_checkin_minute="$2"
    local new_checkout_hour="$3"
    local new_checkout_minute="$4"
    
    # 驗證參數
    if ! [[ "$new_checkin_hour" =~ ^[0-9]+$ ]] || (( new_checkin_hour < 0 || new_checkin_hour > 23 )); then
        error "簽到小時必須在 0-23 之間"
        exit 1
    fi
    
    if ! [[ "$new_checkin_minute" =~ ^[0-9]+$ ]] || (( new_checkin_minute < 0 || new_checkin_minute > 59 )); then
        error "簽到分鐘必須在 0-59 之間"
        exit 1
    fi
    
    if ! [[ "$new_checkout_hour" =~ ^[0-9]+$ ]] || (( new_checkout_hour < 0 || new_checkout_hour > 23 )); then
        error "簽退小時必須在 0-23 之間"
        exit 1
    fi
    
    if ! [[ "$new_checkout_minute" =~ ^[0-9]+$ ]] || (( new_checkout_minute < 0 || new_checkout_minute > 59 )); then
        error "簽退分鐘必須在 0-59 之間"
        exit 1
    fi
    
    info "更新時間設定..."
    echo "簽到: $(printf "%02d:%02d" $new_checkin_hour $new_checkin_minute)"
    echo "簽退: $(printf "%02d:%02d" $new_checkout_hour $new_checkout_minute)"
    
    update_config_file "$new_checkin_hour" "$new_checkin_minute" "$new_checkout_hour" "$new_checkout_minute" ""
    update_plist_files "$new_checkin_hour" "$new_checkin_minute" "$new_checkout_hour" "$new_checkout_minute"
    reload_launchd
    
    echo
    success "時間設定已更新完成！"
}

# 顯示幫助
show_help() {
    echo "更新定時打卡時間設定"
    echo
    echo "用法:"
    echo "  $0                                    # 互動式更新"
    echo "  $0 <簽到時> <簽到分> <簽退時> <簽退分>   # 快速更新"
    echo "  $0 show                               # 顯示當前設定"
    echo "  $0 help                               # 顯示此幫助"
    echo
    echo "範例:"
    echo "  $0                      # 進入互動式設定"
    echo "  $0 9 0 18 30            # 設定 9:00 簽到, 18:30 簽退"
    echo "  $0 8 45 17 45           # 設定 8:45 簽到, 17:45 簽退"
    echo "  $0 show                 # 查看當前時間設定"
}

# 主函數
main() {
    case "${1:-interactive}" in
        "show")
            show_current_config
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        "interactive")
            interactive_update
            ;;
        *)
            # 如果有4個參數，執行快速更新
            if [[ $# -eq 4 ]]; then
                quick_update "$@"
            else
                error "參數錯誤"
                show_help
                exit 1
            fi
            ;;
    esac
}

# 執行主函數
main "$@"
