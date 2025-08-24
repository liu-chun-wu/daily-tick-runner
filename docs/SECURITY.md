# 安全指南

本文檔說明 Daily Tick Runner 的安全最佳實踐和注意事項。

## 📋 目錄

- [密鑰管理](#密鑰管理)
- [環境變數安全](#環境變數安全)
- [GitHub Secrets](#github-secrets)
- [本地開發安全](#本地開發安全)
- [認證與會話](#認證與會話)
- [日誌安全](#日誌安全)
- [網路安全](#網路安全)
- [安全檢查清單](#安全檢查清單)

## 密鑰管理

### 基本原則

1. **永不提交密鑰到版本控制**
   ```bash
   # .gitignore 必須包含
   .env
   .env.local
   .env.*.local
   playwright/.auth/
   ```

2. **使用強密碼**
   - 至少 12 個字元
   - 包含大小寫字母、數字和特殊符號
   - 避免使用個人資訊

3. **定期輪換**
   - 每 90 天更換一次密碼
   - 發現洩漏立即更換
   - 記錄更換日期

### 密鑰儲存層級

```
生產環境：GitHub Secrets / 密鑰管理服務
    ↓
開發環境：環境變數 / .env 檔案
    ↓
執行時期：記憶體（避免寫入磁碟）
```

## 環境變數安全

### 設定環境變數

```bash
# 使用 .env 檔案（開發環境）
cp .env.example .env
chmod 600 .env  # 限制檔案權限

# 直接設定（不留歷史記錄）
read -s AOA_PASSWORD
export AOA_PASSWORD
```

### 驗證環境變數

```typescript
// config/env.ts
function validateEnv() {
  const required = ['AOA_USERNAME', 'AOA_PASSWORD', 'COMPANY_CODE'];
  const missing = required.filter(key => !process.env[key]);
  
  if (missing.length > 0) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }
  
  // 不要記錄實際值
  console.log('Environment variables validated ✓');
}
```

### 避免洩漏

```typescript
// ❌ 錯誤：記錄密碼
console.log(`Logging in with password: ${password}`);

// ✅ 正確：只記錄狀態
console.log('Attempting login...');

// ❌ 錯誤：錯誤訊息包含密碼
throw new Error(`Login failed with credentials: ${username}/${password}`);

// ✅ 正確：通用錯誤訊息
throw new Error('Login failed: Invalid credentials');
```

## GitHub Secrets

### 設定 Secrets

1. **Repository Secrets**
   - Settings → Secrets and variables → Actions
   - 使用描述性名稱（如 `AOA_PASSWORD`）
   - 定期檢查和更新

2. **Organization Secrets**
   - 用於多個 repository 共享
   - 限制存取範圍

3. **Environment Secrets**
   - 用於不同環境（dev/staging/prod）
   - 需要審核的部署

### 使用 Secrets

```yaml
# .github/workflows/production.yml
env:
  AOA_USERNAME: ${{ secrets.AOA_USERNAME }}
  AOA_PASSWORD: ${{ secrets.AOA_PASSWORD }}
  
# 不要在日誌中顯示
- name: Login
  run: |
    echo "::add-mask::${{ secrets.AOA_PASSWORD }}"
    npm run test:login
```

### Secrets 掃描

GitHub 會自動掃描並警告洩漏的密鑰：
- API keys
- Access tokens
- Private keys

如收到警告，立即：
1. 撤銷洩漏的密鑰
2. 產生新密鑰
3. 更新所有使用處

## 本地開發安全

### 檔案權限

```bash
# 限制敏感檔案權限
chmod 600 .env
chmod 600 playwright/.auth/*

# 檢查權限
ls -la .env
# -rw------- 1 user group 256 Jan 1 00:00 .env
```

### Git 安全

```bash
# 防止意外提交
git config --global core.excludesfile ~/.gitignore_global

# 檢查是否有敏感資料
git diff --cached | grep -E "(password|token|secret|key)"

# 使用 pre-commit hooks
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
if git diff --cached | grep -E "(AOA_PASSWORD|TOKEN|SECRET)"; then
  echo "Error: Attempting to commit sensitive data"
  exit 1
fi
EOF
chmod +x .git/hooks/pre-commit
```

### 清理歷史

如果不小心提交了密鑰：

```bash
# 使用 BFG Repo-Cleaner
bfg --delete-files .env
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# 或使用 git filter-branch
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch .env" \
  --prune-empty --tag-name-filter cat -- --all
```

## 認證與會話

### Storage State 安全

```typescript
// 加密儲存（選用）
import crypto from 'crypto';

function encryptStorageState(state: any, password: string) {
  const cipher = crypto.createCipher('aes-256-cbc', password);
  let encrypted = cipher.update(JSON.stringify(state), 'utf8', 'hex');
  encrypted += cipher.final('hex');
  return encrypted;
}

// 設定過期時間
function isStorageStateValid(statePath: string): boolean {
  const stats = fs.statSync(statePath);
  const age = Date.now() - stats.mtimeMs;
  return age < 24 * 60 * 60 * 1000; // 24 小時
}
```

### 多因素認證處理

如果系統需要 MFA：

1. **服務帳號豁免**
   - 申請自動化專用帳號
   - 設定 IP 白名單

2. **TOTP 整合**
   ```typescript
   import * as OTPAuth from 'otpauth';
   
   const totp = new OTPAuth.TOTP({
     secret: process.env.TOTP_SECRET,
     algorithm: 'SHA1',
     digits: 6,
     period: 30,
   });
   
   const code = totp.generate();
   ```

## 日誌安全

### 敏感資料過濾

```typescript
class SecureLogger {
  private sensitivePatterns = [
    /password=\S+/gi,
    /token=\S+/gi,
    /Authorization:\s*Bearer\s+\S+/gi,
    /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/g, // email
  ];
  
  log(message: string) {
    let sanitized = message;
    for (const pattern of this.sensitivePatterns) {
      sanitized = sanitized.replace(pattern, '[REDACTED]');
    }
    console.log(sanitized);
  }
}
```

### 日誌保留策略

```bash
# 定期清理日誌
find ~/.daily-tick-runner/logs -name "*.log" -mtime +30 -delete

# 壓縮舊日誌
gzip ~/.daily-tick-runner/logs/*.log

# 加密敏感日誌
openssl enc -aes-256-cbc -salt -in sensitive.log -out sensitive.log.enc
```

### 審計日誌

```typescript
interface AuditLog {
  timestamp: Date;
  user: string;
  action: string;
  result: 'success' | 'failure';
  ip?: string;
  metadata?: Record<string, any>;
}

function logAudit(entry: AuditLog) {
  // 不記錄密碼，只記錄動作
  const sanitized = {
    ...entry,
    user: hashUsername(entry.user),
    metadata: filterSensitive(entry.metadata),
  };
  
  fs.appendFileSync('audit.log', JSON.stringify(sanitized) + '\n');
}
```

## 網路安全

### HTTPS 強制

```typescript
// playwright.config.ts
use: {
  baseURL: 'https://erpline.aoacloud.com.tw',  // 使用 HTTPS
  ignoreHTTPSErrors: false,  // 生產環境不忽略 SSL 錯誤
}
```

### 代理設定

```typescript
// 使用代理時的安全設定
use: {
  proxy: {
    server: process.env.PROXY_SERVER,
    username: process.env.PROXY_USER,
    password: process.env.PROXY_PASS,
  },
}
```

### 請求安全

```typescript
// 設定安全標頭
await page.setExtraHTTPHeaders({
  'X-Requested-With': 'XMLHttpRequest',
  'User-Agent': 'DailyTickRunner/1.0',
});

// 限制請求來源
await page.route('**/*', route => {
  const url = route.request().url();
  if (isAllowedDomain(url)) {
    route.continue();
  } else {
    route.abort();
  }
});
```

## 安全檢查清單

### 開發階段

- [ ] 環境變數設定正確
- [ ] .gitignore 包含所有敏感檔案
- [ ] 沒有硬編碼的密碼
- [ ] 日誌不包含敏感資訊
- [ ] 使用 HTTPS 連線
- [ ] Storage State 有適當保護

### 部署前

- [ ] 所有 Secrets 已設定
- [ ] 移除 debug 程式碼
- [ ] 清理測試資料
- [ ] 檢查檔案權限
- [ ] 更新相依套件
- [ ] 執行安全掃描

### 執行時

- [ ] 定期檢查執行日誌
- [ ] 監控異常登入
- [ ] 確認通知正常運作
- [ ] 檢查資源使用量
- [ ] 審查存取記錄

### 維護期

- [ ] 定期更換密碼
- [ ] 更新安全修補
- [ ] 清理舊日誌
- [ ] 審查權限設定
- [ ] 檢查備份完整性

## 安全工具

### 依賴掃描

```bash
# npm audit
npm audit
npm audit fix

# Snyk
npx snyk test
npx snyk monitor

# OWASP Dependency Check
dependency-check --scan . --format HTML
```

### 密鑰掃描

```bash
# GitLeaks
gitleaks detect --source . --verbose

# TruffleHog
trufflehog git file://. --json

# git-secrets
git secrets --install
git secrets --scan
```

### 程式碼分析

```bash
# ESLint security plugin
npm install --save-dev eslint-plugin-security
# .eslintrc.json
{
  "plugins": ["security"],
  "extends": ["plugin:security/recommended"]
}

# Semgrep
semgrep --config=auto .
```

## 事件響應

### 密鑰洩漏處理

1. **立即行動**
   - 撤銷洩漏的密鑰
   - 產生新密鑰
   - 更新所有使用處

2. **調查範圍**
   - 檢查存取日誌
   - 確認影響範圍
   - 找出洩漏原因

3. **預防措施**
   - 加強存取控制
   - 增加監控警報
   - 更新安全流程

### 帳號被鎖定

1. **確認原因**
   - 多次登入失敗
   - 異常活動偵測
   - 密碼過期

2. **解決步驟**
   - 聯繫 IT 支援
   - 重設密碼
   - 更新自動化設定

3. **預防措施**
   - 實作重試邏輯
   - 監控登入狀態
   - 設定警報通知

## 合規性

### GDPR 考量

- 最小化個人資料收集
- 實作資料刪除機制
- 提供資料匯出功能
- 記錄資料處理活動

### 企業政策

- 遵守公司 IT 政策
- 符合密碼複雜度要求
- 遵循存取控制規範
- 配合安全審計

## 相關資源

### 安全標準

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CWE Top 25](https://cwe.mitre.org/top25/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)

### 最佳實踐

- [OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/)
- [12-Factor App](https://12factor.net/)
- [Google Security Best Practices](https://cloud.google.com/security/best-practices)

### 工具與服務

- [GitHub Security](https://github.com/security)
- [Snyk](https://snyk.io/)
- [GitGuardian](https://www.gitguardian.com/)

## 聯絡資訊

發現安全問題請通過以下方式回報：

- Email: security@example.com
- GitHub Security Advisory: [建立安全建議](https://github.com/YOUR_USERNAME/daily-tick-runner/security/advisories/new)

請勿在公開 Issue 中揭露安全漏洞。