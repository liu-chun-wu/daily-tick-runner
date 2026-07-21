# docker/Dockerfile
FROM mcr.microsoft.com/playwright:v1.61.0-noble

ARG SOURCE_URL
LABEL org.opencontainers.image.source=$SOURCE_URL

# The official image already contains the matching Playwright browsers.
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
RUN node -e "if (Number(process.versions.node.split('.')[0]) < 24) throw new Error('Node.js 24+ is required')"

# 地區與字型（繁中環境常用）
ENV TZ=Asia/Taipei
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      tzdata fonts-noto-cjk && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 先複製 lockfile 以利快取
COPY package*.json ./
RUN npm ci

# 複製程式碼（可依專案調整 .dockerignore）
COPY . .

# Local Compose may run with the host UID/GID. Keep only ephemeral output
# directories writable; no authentication state is baked into the image.
RUN mkdir -p playwright/.auth test-results playwright-report && \
    chmod -R a+rwx playwright test-results playwright-report

CMD ["npm", "run", "test:list"]
