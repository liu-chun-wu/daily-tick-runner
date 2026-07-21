SHELL := /bin/bash
.DEFAULT_GOAL := help

.PHONY: help setup install playwright-install clean test test-list test-result test-smoke smoke-notify notify-test attendance-checkin attendance-checkout test-ui test-debug

help:
	@echo "Daily Tick Runner"
	@echo "  make setup                 安裝相依套件與 Chromium"
	@echo "  make test                  安全 Smoke（不打卡、不發通知）"
	@echo "  make test-list             列出測試，不連線到目標服務"
	@echo "  make test-result           測試成功/失敗/未知/timeout 判斷"
	@echo "  make smoke-notify          安全 Smoke 成功後發送摘要"
	@echo "  make notify-test           發送真實測試通知"
	@echo "  make attendance-checkin    執行一次真實簽到"
	@echo "  make attendance-checkout   執行一次真實簽退"

install:
	npm ci

playwright-install:
	npx playwright install chromium

setup: install playwright-install

clean:
	rm -rf test-results/ playwright-report/ node_modules/.cache/

test:
	npm test

test-list:
	npm run test:list

test-result:
	npm run test:result

test-smoke:
	npm run test:smoke

smoke-notify:
	@echo "WARNING: 此命令會登入目標，Smoke 成功後發送真實通知。"
	npm run smoke:notify

notify-test:
	@echo "WARNING: 此命令會發送真實通知。"
	npm run notify:test

attendance-checkin:
	@echo "WARNING: 此命令會執行一次真實簽到。"
	@read -p "確定繼續？(y/N): " confirm; [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]
	npm run attendance:checkin

attendance-checkout:
	@echo "WARNING: 此命令會執行一次真實簽退。"
	@read -p "確定繼續？(y/N): " confirm; [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]
	npm run attendance:checkout

test-ui:
	npm run test:ui

test-debug:
	npm run test:debug
