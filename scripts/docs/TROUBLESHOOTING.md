# 故障排除指南

常見問題的診斷和解決方案。

## 🚨 常見問題

### 1. GitHub CLI 相關問題

#### 問題: GitHub CLI 未安裝
```bash
# 錯誤訊息
command not found: gh
```

**解決方案:**
```bash
# macOS (Homebrew)
brew install gh

# 驗證安裝
gh --version
```

#### 問題: GitHub CLI 未登入
```bash
# 錯誤訊息
gh: Not logged in to github.com
```

**解決方案:**
```bash
# 登入 GitHub
gh auth login

# 驗證狀態
gh auth status
```

#### 問題: 權限不足
```bash
# 錯誤訊息
HTTP 403: Resource not accessible by integration
```

**解決方案:**
1. 確認 token 有 `workflow` 權限
2. 重新登入並選擇正確的權限範圍:
```bash
gh auth login --scopes repo,workflow
```

### 2. 定時任務相關問題

#### 問題: 定時任務未執行
```bash
# 檢查任務狀態
./setup-local-scheduler.sh status
```

**可能原因和解決方案:**

1. **任務未載入**
```bash
# 重新載入任務
./setup-local-scheduler.sh disable
./setup-local-scheduler.sh enable
```

2. **系統日誌檢查**
```bash
# 查看 launchd 日誌
log show --predicate 'subsystem == "com.apple.launchd"' --last 1h | grep daily-tick

# 檢查任務列表
launchctl list | grep daily-tick-runner
```

3. **權限問題**
```bash
# 確保腳本可執行
chmod +x scripts/bin/*.sh
```

#### 問題: Mac 休眠後任務未執行
**解決方案:**
- launchd 會在 Mac 醒來後執行錯過的任務
- 如需立即執行，可手動觸發:
```bash
./auto-punch.sh
```

### 3. 時間設定問題

#### 問題: 時間窗口過寬導致誤判
```bash
# 檢查當前設定
./time-config.sh
```

**解決方案:**
```bash
# 修正為合理範圍
./update-time.sh 8 30 18 0  # 8:30簽到, 18:00簽退

# 檢查修正結果
./time-config.sh
```

#### 問題: 時間修改後未生效
**解決方案:**
```bash
# 確認配置更新
./update-time.sh show

# 重新載入定時任務
./setup-local-scheduler.sh disable
./setup-local-scheduler.sh enable
```

### 4. Workflow 觸發問題

#### 問題: Workflow 名稱錯誤
```bash
# 錯誤訊息
could not find workflow
```

**解決方案:**
```bash
# 列出可用的 workflows
gh workflow list

# 確認腳本中的 WORKFLOW_NAME 設定
grep WORKFLOW_NAME bin/auto-punch.sh
```

#### 問題: 參數值不正確
```bash
# 錯誤訊息
Provided value 'xxx' not in the list of allowed values
```

**解決方案:**
1. 檢查 GitHub Actions workflow 的輸入參數定義
2. 確認 `action_type` 必須是 `checkin` 或 `checkout`

### 5. 日誌相關問題

#### 問題: 日誌檔案過大
```bash
# 檢查日誌大小
du -sh ~/.daily-tick-runner/logs/
```

**解決方案:**
```bash
# 清理舊日誌
./log-viewer.sh cleanup 30  # 保留30天

# 定期清理設定
# 在 crontab 中添加月度清理
crontab -e
# 0 0 1 * * /path/to/scripts/log-viewer.sh cleanup 30
```

#### 問題: 找不到日誌
**解決方案:**
```bash
# 手動建立日誌目錄
mkdir -p ~/.daily-tick-runner/logs

# 檢查腳本權限
ls -la bin/auto-punch.sh
```

### 6. 網路相關問題

#### 問題: 網路連線失敗
```bash
# 錯誤訊息
dial tcp: lookup api.github.com: no such host
```

**解決方案:**
1. 檢查網路連線
2. 確認 DNS 設定
3. 檢查防火牆設定
4. 使用代理的情況下，設定 gh CLI 代理:
```bash
gh config set -h github.com git_protocol https
```

### 7. 權限相關問題

#### 問題: 腳本權限不足
```bash
# 錯誤訊息
Permission denied
```

**解決方案:**
```bash
# 設定所有腳本執行權限
find scripts/ -name "*.sh" -exec chmod +x {} \;

# 檢查權限
ls -la scripts/*.sh
ls -la scripts/bin/*.sh
```

## 🔍 診斷工具

### 系統狀態檢查
```bash
# 完整系統檢查
./setup-local-scheduler.sh status

# GitHub CLI 狀態
gh auth status

# 任務狀態
launchctl list | grep daily-tick-runner
```

### 手動測試
```bash
# 測試時間判斷邏輯
./auto-punch.sh

# 測試 workflow 觸發
gh workflow run "正式排程 - 自動打卡" \
  --field action_type=checkin \
  --field log_level=DEBUG
```

### 日誌分析
```bash
# 查看錯誤記錄
./log-viewer.sh search "ERROR" 7

# 查看最近執行
./log-viewer.sh latest 50

# 即時監控
./log-viewer.sh monitor
```

## 🛠️ 進階診斷

### 檢查時間判斷邏輯
```bash
# 檢查當前時間
date
date +%u  # 星期 (1-7)
date +%H  # 小時

# 檢查時間配置
./time-config.sh

# 手動驗證邏輯
./auto-punch.sh 2>&1 | grep "時間窗口"
```

### 檢查 GitHub Actions 狀態
```bash
# 查看最近的 runs
gh run list --limit 5

# 查看特定 run 的詳情
gh run view <run_id>

# 查看 workflow 定義
gh workflow view "正式排程 - 自動打卡"
```

### 系統日誌診斷
```bash
# macOS 系統日誌
log show --predicate 'eventMessage contains "daily-tick-runner"' --last 1d

# Console.app 搜尋關鍵字
# 打開 Console.app，搜尋 "daily-tick-runner"
```

## 🔄 重置和恢復

### 完全重置系統
```bash
# 1. 卸載現有任務
./setup-local-scheduler.sh uninstall

# 2. 清理日誌 (可選)
rm -rf ~/.daily-tick-runner/logs

# 3. 重新安裝
./quick-install.sh
```

### 備份和恢復設定
```bash
# 備份配置
cp -r config/ config_backup_$(date +%Y%m%d)

# 恢復配置
cp -r config_backup_YYYYMMDD/* config/

# 重新載入
./setup-local-scheduler.sh disable
./setup-local-scheduler.sh enable
```

## 📞 獲取支援

### 收集診斷資訊
```bash
# 系統資訊
system_profiler SPSoftwareDataType
uname -a

# GitHub CLI 版本
gh --version

# 腳本狀態
./setup-local-scheduler.sh status > diagnostic_$(date +%Y%m%d).txt
./log-viewer.sh latest 100 >> diagnostic_$(date +%Y%m%d).txt
```

### 提交問題前的檢查清單
- [ ] 已檢查 GitHub CLI 登入狀態
- [ ] 已確認定時任務載入狀態
- [ ] 已檢查時間設定合理性
- [ ] 已查看最近的錯誤日誌
- [ ] 已手動測試腳本執行
- [ ] 已確認網路連線正常