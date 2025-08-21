#!/bin/bash

# 一鍵安裝本機定時打卡
# 作者: Claude Code

set -euo pipefail

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                     本機定時打卡 - 一鍵安裝                         ║"
echo "║                                                                  ║"
echo "║  此工具將設定您的 Mac 自動在指定時間觸發 GitHub Actions 打卡           ║"
echo "║                                                                  ║"
echo "║  執行時間:                                                        ║"
echo "║  • 簽到: 週一到週五 08:30                                          ║"
echo "║  • 簽退: 週一到週五 18:00                                          ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo

# 檢查是否在正確目錄
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -f "$SCRIPT_DIR/setup-local-scheduler.sh" ]]; then
    echo -e "${RED}錯誤: 找不到必要的腳本文件${NC}"
    echo "請確保您在正確的 scripts 目錄中執行此腳本"
    exit 1
fi

echo -e "${YELLOW}⚠️  安裝前確認:${NC}"
echo "1. 您的 Mac 需要保持開機狀態才能執行定時任務"
echo "2. 需要穩定的網路連線來觸發 GitHub Actions"
echo "3. 此工具會在您的系統中安裝 launchd 定時任務"
echo

read -p "您確定要繼續安裝嗎? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}安裝已取消${NC}"
    exit 0
fi

echo
echo -e "${BLUE}開始安裝...${NC}"

# 步驟 1: 檢查系統需求
echo -e "${YELLOW}[1/4]${NC} 檢查系統需求..."
if ! command -v gh &> /dev/null; then
    echo -e "${RED}✗ GitHub CLI 未安裝${NC}"
    echo -e "${BLUE}正在安裝 GitHub CLI...${NC}"
    if command -v brew &> /dev/null; then
        brew install gh
    else
        echo -e "${RED}錯誤: 需要先安裝 Homebrew${NC}"
        echo "請訪問 https://brew.sh/ 安裝 Homebrew"
        exit 1
    fi
fi

if ! gh auth status &> /dev/null; then
    echo -e "${YELLOW}需要登入 GitHub CLI${NC}"
    gh auth login
fi

echo -e "${GREEN}✓ 系統需求檢查完成${NC}"

# 步驟 2: 安裝定時任務
echo -e "${YELLOW}[2/4]${NC} 安裝定時任務..."
"$SCRIPT_DIR/setup-local-scheduler.sh" install
echo -e "${GREEN}✓ 定時任務安裝完成${NC}"

# 步驟 3: 測試腳本
echo -e "${YELLOW}[3/4]${NC} 測試腳本..."
if "$SCRIPT_DIR/auto-punch.sh"; then
    echo -e "${GREEN}✓ 腳本測試成功${NC}"
else
    echo -e "${YELLOW}⚠️  腳本測試未執行 (可能因為時間不在打卡時段內)${NC}"
fi

# 步驟 4: 顯示狀態
echo -e "${YELLOW}[4/4]${NC} 顯示安裝狀態..."
"$SCRIPT_DIR/setup-local-scheduler.sh" status

echo
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗"
echo "║                           安裝完成！                            ║"
echo "╚══════════════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "${BLUE}接下來您可以:${NC}"
echo
echo -e "${CYAN}📊 查看狀態:${NC}"
echo "   ./setup-local-scheduler.sh status"
echo
echo -e "${CYAN}📋 查看日誌:${NC}"
echo "   ./log-viewer.sh latest"
echo "   ./log-viewer.sh monitor    # 即時監控"
echo "   ./log-viewer.sh today      # 今日日誌"
echo
echo -e "${CYAN}⚙️  管理任務:${NC}"
echo "   ./setup-local-scheduler.sh disable   # 暫時停用"
echo "   ./setup-local-scheduler.sh enable    # 重新啟用"
echo "   ./setup-local-scheduler.sh uninstall # 完全移除"
echo
echo -e "${CYAN}🔍 測試執行:${NC}"
echo "   ./auto-punch.sh            # 手動執行一次"
echo
echo -e "${YELLOW}💡 提醒:${NC}"
echo "• Mac 需要保持開機狀態才能執行定時任務"
echo "• 可以透過日誌監控執行狀況"
echo "• 如有問題請查看 README.md 或執行故障排除命令"
echo
echo -e "${GREEN}祝您使用愉快！${NC}"