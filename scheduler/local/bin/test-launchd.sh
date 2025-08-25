#!/bin/bash
# 測試 launchd 執行環境

echo "========== LaunchD 測試開始 =========="
echo "時間: $(date)"
echo "用戶: $(whoami)"
echo "當前目錄: $(pwd)"
echo "PATH: $PATH"
echo "參數: $@"
echo "========== LaunchD 測試結束 =========="