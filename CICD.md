下面是一份可直接放在 repo 內（例如 `docs/CI-CD-with-Container.md`）給本地 LLM 執行／參考的說明文件。已內含可複製的 Dockerfile 與 GitHub Actions workflow 範本，並以**容器化 CI**為核心；CD 維持你現有的 GitHub-hosted runner，只需把 job 也切到同一顆映像以統一環境。

---

# 容器化 CI / 協同 CD 指南（自動打卡系統）

> 目標：在 **GitHub Actions** 建立「可重現的容器化 CI」，並把 **既有排程 CD** 也切到同一顆映像，確保本地 / CI / CD 環境一致。
> 依賴：GitHub-hosted runner、GitHub Container Registry（GHCR）。

---

## 為什麼要「容器化 CI」？

* **工作在容器裡跑**：GitHub Actions 支援在 workflow 的 job 上以 `container:` 指定映像，所有步驟都在該容器中執行，避免環境飄移。([GitHub Docs][1])
* **一顆映像打天下**：把時區、字型、Node 版本、端到端測試（若有 Playwright）所需依賴封裝在自有映像，CI/CD 共用。([GitHub Docs][1])
* **快、穩、好維護**：`actions/setup-node` 內建 npm 快取（靠 lockfile），縮短 CI 時間；並以 concurrency 避免同分支重複跑。([GitHub][2], [GitHub Docs][3])

---

## 結構變更（一次性）

```
repo-root/
├─ docker/
│  └─ Dockerfile        # 本專案的 CI/CD 基底映像
├─ .github/
│  └─ workflows/
│     ├─ ci.yml         # PR / Push 的 CI
│     └─ build-image.yml# 建置並推送自有映像到 GHCR
└─ （你現有的排程 CD workflows 維持檔名，稍後只改一行 container）
```

---

## 步驟 1：建立專案自有映像（docker/Dockerfile）

> 若你的端到端測試使用 **Playwright**，以下 Dockerfile 以官方 Playwright 容器為基底（已含三大瀏覽器與系統依賴；自 v1.47 起預設為 Ubuntu 24.04 Noble）。([Playwright][4])

```dockerfile
# docker/Dockerfile
FROM mcr.microsoft.com/playwright:v1.54.0-noble

# 地區與字型（繁中環境常用）
ENV TZ=Asia/Taipei
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      tzdata fonts-noto-cjk && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
# 若使用 Node：先複製 lockfile 以利快取
COPY package*.json ./
RUN npm ci

# 複製程式碼（可依專案調整 .dockerignore）
COPY . .

# Playwright 官方映像已包含瀏覽器與系統依賴，CI 中無需再 install --with-deps
# 參考：https://playwright.dev/docs/docker
```

> 備註：Playwright 在 CI 的官方建議做法是「使用其 Docker 映像 **或** 在 Linux agent 上安裝瀏覽器依賴」。此處採前者。([Playwright][5])

---

## 步驟 2：PR/Push 的 CI（.github/workflows/ci.yml）

* 在 **容器** 中執行（環境一致）。
* 使用 `actions/setup-node` **啟用 npm 快取**（需 lockfile）。([GitHub][2])
* 設定 **concurrency**：同一分支觸發新 commit 時，自動取消舊的工作。([GitHub Docs][3])

```yaml
# .github/workflows/ci.yml
name: CI

on:
  pull_request:
  push:
    branches: [ main ]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true  # 新的跑起來會取消舊的

jobs:
  test:
    runs-on: ubuntu-latest
    container: ghcr.io/liu-chun-wu/daily-tick-runner/runner:latest  # 使用自有映像（含中文字型）
    timeout-minutes: 20

    steps:
      - name: 📥 Checkout repository
        uses: actions/checkout@v4

      - name: 📦 Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'                    # 需有 package-lock.json / yarn.lock 才會生效
          cache-dependency-path: 'package-lock.json'

      - name: 🔧 Install dependencies
        run: npm ci

      - name: 🔍 Lint (optional)
        run: npm run lint --if-present

      # Playwright 瀏覽器和中文字型已在容器中預裝，無需再安裝

      - name: 🔐 Setup and login
        env:
          BASE_URL: ${{ vars.BASE_URL || 'https://erpline.aoacloud.com.tw/' }}
          COMPANY_CODE: ${{ vars.COMPANY_CODE || 'CYBERBIZ' }}
          AOA_USERNAME: ${{ secrets.AOA_USERNAME }}
          AOA_PASSWORD: ${{ secrets.AOA_PASSWORD }}
          AOA_LAT: ${{ vars.AOA_LAT || '25.080869' }}
          AOA_LON: ${{ vars.AOA_LON || '121.569862' }}
          TZ: ${{ vars.TZ || 'Asia/Taipei' }}
          LOCALE: ${{ vars.LOCALE || 'zh-TW' }}
          DISCORD_WEBHOOK_URL: ${{ secrets.DISCORD_WEBHOOK_URL }}
          LINE_CHANNEL_ACCESS_TOKEN: ${{ secrets.LINE_CHANNEL_ACCESS_TOKEN }}
          LINE_USER_ID: ${{ secrets.LINE_USER_ID }}
          LOG_LEVEL: ${{ vars.LOG_LEVEL || 'INFO' }}
        run: |
          echo "🔍 開始環境檢查和登入設置..."
          npx playwright test --project=setup --workers=1

      - name: 📢 Run notify tests (with retry)
        uses: nick-fields/retry@v3
        with:
          timeout_minutes: 15
          max_attempts: 3
          retry_wait_seconds: 60
          retry_on: error
          command: |
            echo "📢 開始執行通知測試..."
            echo "⏰ 執行時間: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
            npx playwright test --project=notify --workers=1 --trace on
        env:
          # 環境變數設定（同上）
      
      - name: 🎯 Run chromium-smoke tests (with retry)
        uses: nick-fields/retry@v3
        with:
          timeout_minutes: 15
          max_attempts: 3
          retry_wait_seconds: 60
          retry_on: error
          command: |
            echo "🎯 開始執行 smoke 測試..."
            echo "⏰ 執行時間: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
            npx playwright test --project=chromium-smoke --workers=1 --trace on
        env:
          # 環境變數設定（同上）

      - name: 📤 Upload test results (if failed)
        uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: test-results-${{ github.run_number }}
          path: |
            test-results/
            playwright-report/
          retention-days: 7

      - name: 📊 Upload traces (if failed)
        uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: traces-${{ github.run_number }}
          path: test-results/**/*.zip
          retention-days: 3

      - name: 🚨 Notify on failure
        if: failure()
        env:
          DISCORD_WEBHOOK_URL: ${{ secrets.DISCORD_WEBHOOK_URL }}
        run: |
          if [ -n "$DISCORD_WEBHOOK_URL" ]; then
            curl -H "Content-Type: application/json" \
                 -d "{\"content\":\"❌ **CI 測試失敗**\\n🔗 查看詳情: https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}\"}" \
                 "$DISCORD_WEBHOOK_URL" || echo "Discord 通知發送失敗"
          fi
```

> 參考：
>
> * Job 在容器中執行的官方語法與行為。([GitHub Docs][1])
> * `actions/setup-node` 的快取機制與 lockfile 要求。([GitHub][2])
> * Playwright CI 三步驟與 `install --with-deps` 說明。([Playwright][5])
> * `concurrency` 取消舊工作（避免重複計算）。([GitHub Docs][3])

---

## 步驟 3：建置並推送「自有映像」到 GHCR（.github/workflows/build-image.yml）

> GHCR 支援用 **`GITHUB_TOKEN`** 在 Actions 中登入／推送，將映像推到 `ghcr.io/<owner>/<repo>`（workflow 要宣告 `packages: write` 權限）。([GitHub Docs][6])

```yaml
# .github/workflows/build-image.yml
name: Build Image

on:
  push:
    branches: [ main ]
  workflow_dispatch:

permissions:
  contents: read
  packages: write  # 允許推送到 GHCR

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}  # GH 建議用 GITHUB_TOKEN
          # 參考：GH Packages/Container registry 與 login action
          # https://docs.github.com/.../publishing-and-installing-a-package-with-github-actions
          # https://github.com/docker/login-action

      - name: Set tags
        id: meta
        run: |
          REPO=ghcr.io/${{ github.repository }}
          SHA=${{ github.sha }}
          echo "image=${REPO}/runner" >> $GITHUB_OUTPUT
          echo "tags=${REPO}/runner:sha-${SHA},${REPO}/runner:latest" >> $GITHUB_OUTPUT

      - name: Build & Push
        uses: docker/build-push-action@v6
        with:
          context: .
          file: docker/Dockerfile
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          provenance: false   # 避免推送過多中繼層（有案例建議） 
          # https://github.com/docker/build-push-action
```

> 參考：
>
> * GHCR 操作與登入方式。([GitHub Docs][7])
> * `docker/build-push-action` 官方說明。([GitHub][8])
> * 使用 `GITHUB_TOKEN` 進行封裝與推送（官方建議）。([GitHub Docs][6])

---

## 步驟 4：讓\*\*既有 CD（排程 workflow）\*\*也跑在同一顆映像

> 不改你的排程與觸發，只要在 job 加上 `container:` 指向 GHCR 的自有映像即可：

```yaml
# 你既有的排程 workflow（只示範 job 片段）
jobs:
  scheduled-run:
    runs-on: ubuntu-latest
    container: ghcr.io/<owner>/<repo>/runner:latest   # 與 CI 同一顆映像
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 18
          cache: npm
      - run: npm ci
      - run: npx playwright test --project=chromium --grep @click
```

> 好處：CI 與 CD 共享相同執行環境，避免「本地 OK / CI OK、CD 爆炸」的環境不一致。([GitHub Docs][1])

---

## 附加強化（建議）

### 1) CodeQL 安全掃描（JS/TS）

在 repo 的 **Security → Code scanning** 啟用 **Default setup**（或使用 workflow），可對 JS/TS 執行安全查核。([GitHub Docs][9])

*最小化 workflow（選擇進階設定時）*：

```yaml
# .github/workflows/codeql.yml（若用 Default setup 可省略）
name: "CodeQL"

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  schedule:
    - cron: '0 3 * * 1'

jobs:
  analyze:
    permissions:
      security-events: write
      contents: read
    uses: github/codeql-action/.github/workflows/codeql.yml@v3
    with:
      languages: javascript-typescript
      # 可切換 default / security-extended 等 query 套件
```

> 參考：Default/Advanced 設定與 JS/TS Query 套件。([GitHub Docs][9])

### 2) Dependabot（安全/版本更新）

加入 `.github/dependabot.yml` 自動開 PR 更新依賴，並在 **Settings → Code security and analysis** 啟用 **Grouped security updates**。([GitHub Docs][10])

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "09:00"
      timezone: "Asia/Taipei"
    open-pull-requests-limit: 5
    groups:
      minor-and-patch:
        applies-to: version-updates
        update-types:
          - "minor"
          - "patch"
```

> 參考：Dependabot 版本更新設定與「Grouped security updates」。([GitHub Docs][10], [The GitHub Blog][11])

---

## 常見問題（快速排除）

* **`setup-node` 快取沒生效？**
  確保 `actions/checkout` 在 **`setup-node` 之前**，因為快取需要 lockfile 作為鍵。([Stack Overflow][12])

* **多次推送導致工作重疊變慢？**
  使用 `concurrency` + `cancel-in-progress: true`，新工作會自動取消舊工作。([GitHub Docs][3], [Stack Overflow][13])

* **GHCR 認證方式？**
  在 GitHub Actions 內推送 GHCR，官方建議使用 `GITHUB_TOKEN`（workflow 權限需 `packages: write`）。([GitHub Docs][6])

* **中文顯示問題？**
  使用自有映像 `ghcr.io/liu-chun-wu/daily-tick-runner/runner:latest` 已包含中文字型。若使用官方 Playwright 映像，需安裝 `fonts-noto-cjk`。

* **Flaky 測試？**
  CI 已配置重試機制（每個測試最多 3 次）。若測試第一次失敗但重試後成功，Playwright 會標記為 "flaky" 但整體仍視為成功。

---

## 推薦落地順序（一步步來）

1. **加入 `ci.yml`**（用 Playwright 官方映像先跑起來）。([Playwright][5])
2. **加入 `build-image.yml`**，把 `docker/Dockerfile` 打成 `ghcr.io/<owner>/<repo>/runner:latest`。([GitHub][8])
3. **修改既有排程 CD**：在 job 加 `container: ghcr.io/<owner>/<repo>/runner:latest`。([GitHub Docs][1])
4. （可選）開啟 **CodeQL** 與 **Dependabot**。([GitHub Docs][9])

---

## 在本地重現 CI 環境（可選）

```bash
# 以與 CI 一樣的映像在本地跑（需 Docker）
docker run --rm -it -v "$PWD":/app -w /app ghcr.io/<owner>/<repo>/runner:latest bash
npm ci
npx playwright test
```

> 若尚未推送自有映像，可先改用 `mcr.microsoft.com/playwright:v1.54.0-noble`。([Playwright][14])

---

## 參考資料（精選）

* 在 **容器** 中執行 GitHub Actions job。([GitHub Docs][1])
* **Concurrency** 設定與取消舊工作。([GitHub Docs][3])
* `actions/setup-node` 內建 npm **快取**。([GitHub][2])
* `docker/build-push-action` 官方文件。([GitHub][8])
* **GHCR** 登入／推送與 `GITHUB_TOKEN` 支援。([GitHub Docs][7])
* **Playwright**：Docker、CI 三步驟、Noble 基底說明。([Playwright][4])
* **CodeQL**（Default/Advanced）與 JS/TS Query 套件。([GitHub Docs][9])
* **Dependabot**（版本更新設定、Grouped security updates）。([GitHub Docs][10], [The GitHub Blog][11])

---

### 後續你可以讓本地 LLM 做的事

* 依此文件自動產生／修改 `ci.yml` 與 `build-image.yml`。
* 比對專案實際需求，調整 Dockerfile（安裝額外 CLI、字型、系統套件）。
* 撰寫 Playwright 測試標籤（如 `@smoke`、`@click`）與報告上傳策略。
* 產生 `dependabot.yml` 與 `codeql.yml`（若不用 Default setup）。

> 以上內容自成一體；複製到 repo 後即可按順序執行。若你想，我也可以幫你把 **現有排程 CD** 檔案直接代入 `container:` 以及必要的 Node 步驟，做成可直接合併的 PR 草稿。

[1]: https://docs.github.com/actions/using-jobs/running-jobs-in-a-container?utm_source=chatgpt.com "Running jobs in a container"
[2]: https://github.com/actions/setup-node?utm_source=chatgpt.com "actions/setup-node"
[3]: https://docs.github.com/en/enterprise-cloud%40latest/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency?utm_source=chatgpt.com "Control the concurrency of workflows and jobs"
[4]: https://playwright.dev/docs/docker?utm_source=chatgpt.com "Docker"
[5]: https://playwright.dev/docs/ci?utm_source=chatgpt.com "Continuous Integration"
[6]: https://docs.github.com/en/packages/managing-github-packages-using-github-actions-workflows/publishing-and-installing-a-package-with-github-actions?utm_source=chatgpt.com "Publishing and installing a package with GitHub Actions"
[7]: https://docs.github.com/packages/working-with-a-github-packages-registry/working-with-the-container-registry?utm_source=chatgpt.com "Working with the Container registry"
[8]: https://github.com/docker/build-push-action?utm_source=chatgpt.com "GitHub Action to build and push Docker images with Buildx"
[9]: https://docs.github.com/code-security/code-scanning/introduction-to-code-scanning/about-code-scanning-with-codeql?utm_source=chatgpt.com "About code scanning with CodeQL"
[10]: https://docs.github.com/en/code-security/dependabot/dependabot-version-updates/configuring-dependabot-version-updates?utm_source=chatgpt.com "Configuring Dependabot version updates"
[11]: https://github.blog/changelog/2024-03-28-dependabot-grouped-security-updates-generally-available/?utm_source=chatgpt.com "Dependabot grouped security updates generally available"
[12]: https://stackoverflow.com/questions/68639588/github-actions-dependencies-lock-file-is-not-found-in-runners-path?utm_source=chatgpt.com "Dependencies lock file is not found in runners/path"
[13]: https://stackoverflow.com/questions/66335225/how-to-cancel-previous-runs-in-the-pr-when-you-push-new-commitsupdate-the-curre?utm_source=chatgpt.com "How to cancel previous runs in the PR when you push new ..."
[14]: https://playwright.dev/docs/release-notes?utm_source=chatgpt.com "Release notes"
