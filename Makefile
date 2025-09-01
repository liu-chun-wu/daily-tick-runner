# Daily Tick Runner - Makefile
# 統一管理開發、測試和本地排程器的所有任務

.PHONY: help install clean test-setup test-smoke test-click test-notify test-all test-ui test-debug
.PHONY: scheduler-install scheduler-uninstall scheduler-status scheduler-diagnose scheduler-wake scheduler-dispatch scheduler-logs scheduler-update-time
.PHONY: setup

# 捕捉所有未定義的目標，允許將參數傳遞給 make 命令
# 這讓我們可以使用像 'make scheduler-dispatch checkin test DEBUG' 這樣的語法
%:
	@:

# 顏色定義
GREEN=\033[0;32m
YELLOW=\033[1;33m
BLUE=\033[0;34m
CYAN=\033[0;36m
RED=\033[0;31m
NC=\033[0m

# 專案根目錄
PROJECT_ROOT := $(shell pwd)
SCHEDULER_MANAGE := $(PROJECT_ROOT)/scheduler/local/manage

# 默認目標
.DEFAULT_GOAL := help

# 顯示幫助信息
help:
	@echo "$(CYAN)╔════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║                   Daily Tick Runner - Makefile                 ║$(NC)"
	@echo "$(CYAN)║                                                                ║$(NC)"
	@echo "$(CYAN)║               統一管理開發、測試和本地排程器的所有任務.        ║$(NC)"
	@echo "$(CYAN)╚════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(YELLOW)📦 安裝和設置:$(NC)"
	@echo "  make install               安裝 npm 依賴"
	@echo "  make playwright-install    安裝 Playwright 瀏覽器"
	@echo "  make setup                 完整環境設置 (npm + playwright)"
	@echo "  make clean                 清理測試結果和快取"
	@echo ""
	@echo "$(BLUE)🧪 測試相關:$(NC)"
	@echo "  make test-setup            環境設置和認證測試"
	@echo "  make test-smoke            UI 驗證測試 (不實際點擊)"
	@echo "  make test-click            實際操作測試 (會執行打卡)"
	@echo "  make test-notify           通知系統測試"
	@echo "  make test-all              執行所有測試"
	@echo "  make test-ui               互動式測試界面"
	@echo "  make test-debug            除錯模式測試"
	@echo ""
	@echo "$(GREEN)⏰ 本地排程器:$(NC)"
	@echo "  make scheduler-install     安裝定時打卡排程"
	@echo "  make scheduler-uninstall   卸載定時打卡排程"
	@echo "  make scheduler-status      查看排程狀態"
	@echo "  make scheduler-diagnose    診斷系統配置和延遲問題"
	@echo "  make scheduler-wake [ACTION]     管理系統喚醒排程 (show/setup/remove)"
	@echo "  make scheduler-dispatch [ARGS]   直接觸發 workflow"
	@echo "  make scheduler-logs [SUBCMD]     查看日誌 (latest/today/monitor/etc.)"
	@echo "  make scheduler-update-time 更新執行時間設定"
	@echo ""
	@echo "$(YELLOW)💡 範例用法:$(NC)"
	@echo "  make setup                           # 完整環境設置"
	@echo "  make test-smoke                      # 安全的 UI 測試"
	@echo "  make scheduler-install               # 安裝排程器"
	@echo "  make scheduler-status                # 查看排程狀態"
	@echo ""
	@echo "$(CYAN)📌 參數化命令範例:$(NC)"
	@echo "  make scheduler-dispatch checkin              # 觸發測試簽到 (DEBUG)"
	@echo "  make scheduler-dispatch checkout production  # 觸發正式簽退"
	@echo "  make scheduler-dispatch both test INFO       # 觸發簽到+簽退 (INFO)"
	@echo "  make scheduler-logs latest 100               # 查看最新 100 行"
	@echo "  make scheduler-logs search ERROR             # 搜尋錯誤訊息"
	@echo "  make scheduler-wake setup                    # 設置系統喚醒"
	@echo ""

# ============================================================================
# 安裝和設置
# ============================================================================

install:
	@echo "$(BLUE)[INFO]$(NC) 安裝 npm 依賴..."
	npm install

playwright-install:
	@echo "$(BLUE)[INFO]$(NC) 安裝 Playwright 瀏覽器..."
	npx playwright install chromium

setup: install playwright-install
	@echo "$(GREEN)[SUCCESS]$(NC) 環境設置完成！"
	@echo "$(YELLOW)[TIP]$(NC) 執行 'make test-smoke' 進行安全測試"

clean:
	@echo "$(BLUE)[INFO]$(NC) 清理測試結果和快取..."
	rm -rf test-results/ playwright-report/ node_modules/.cache/
	@echo "$(GREEN)[SUCCESS]$(NC) 清理完成"

# ============================================================================
# 測試相關
# ============================================================================

test-setup:
	@echo "$(BLUE)[INFO]$(NC) 執行環境設置和認證測試..."
	npm run test:setup

test-smoke:
	@echo "$(BLUE)[INFO]$(NC) 執行 UI 驗證測試 (安全模式)..."
	npm run test:smoke

test-click:
	@echo "$(RED)[WARNING]$(NC) 執行實際操作測試 (會真實打卡)..."
	@read -p "確定要執行實際打卡測試嗎？(y/N): " confirm && \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		npm run test:click; \
	else \
		echo "$(YELLOW)[INFO]$(NC) 測試已取消"; \
	fi

test-notify:
	@echo "$(BLUE)[INFO]$(NC) 執行通知系統測試..."
	npm run test:notify

test-all:
	@echo "$(BLUE)[INFO]$(NC) 執行所有測試..."
	npm run test:all

test-ui:
	@echo "$(BLUE)[INFO]$(NC) 啟動互動式測試界面..."
	npm run test:ui

test-debug:
	@echo "$(BLUE)[INFO]$(NC) 啟動除錯模式..."
	npm run test:debug

# ============================================================================
# 本地排程器 - 直接呼叫 manage 腳本
# ============================================================================

scheduler-install:
	@echo "$(BLUE)[INFO]$(NC) 安裝本地定時打卡排程..."
	$(SCHEDULER_MANAGE) install

scheduler-uninstall:
	@echo "$(BLUE)[INFO]$(NC) 卸載本地定時打卡排程..."
	$(SCHEDULER_MANAGE) uninstall

scheduler-status:
	@$(SCHEDULER_MANAGE) status

scheduler-diagnose:
	@$(SCHEDULER_MANAGE) diagnose $(filter-out $@,$(MAKECMDGOALS)) $(ARGS)

scheduler-wake:
	@$(SCHEDULER_MANAGE) wake $(filter-out $@,$(MAKECMDGOALS)) $(ARGS)

scheduler-dispatch:
	@$(SCHEDULER_MANAGE) dispatch $(filter-out $@,$(MAKECMDGOALS)) $(ARGS)

scheduler-logs:
	@$(SCHEDULER_MANAGE) logs $(filter-out $@,$(MAKECMDGOALS)) $(ARGS)

scheduler-update-time:
	@$(SCHEDULER_MANAGE) update-time $(filter-out $@,$(MAKECMDGOALS)) $(ARGS)

# ============================================================================
# 特殊目標 - 支援參數傳遞 (保留以支援舊語法)
# ============================================================================

# 支援 make scheduler-logs-latest 50 的語法 (向後相容)
scheduler-logs-%:
	@$(SCHEDULER_MANAGE) logs $* $(filter-out $@,$(MAKECMDGOALS)) $(ARGS)

# 支援 make scheduler-wake-setup 的語法 (向後相容)
scheduler-wake-%:
	@$(SCHEDULER_MANAGE) wake $* $(filter-out $@,$(MAKECMDGOALS))

# 支援 make scheduler-dispatch-checkin 的語法 (向後相容)
scheduler-dispatch-%:
	@$(SCHEDULER_MANAGE) dispatch $* $(filter-out $@,$(MAKECMDGOALS)) $(ARGS)