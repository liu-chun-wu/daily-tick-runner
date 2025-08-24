# docker/Dockerfile
FROM mcr.microsoft.com/playwright:v1.49.0-noble

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

# Playwright 官方映像已包含瀏覽器與系統依賴，CI 中無需再 install --with-deps
# 參考：https://playwright.dev/docs/docker