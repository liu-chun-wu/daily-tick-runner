import 'dotenv/config';

/**
 * 小工具：檢查環境變數是否存在，沒有就直接 throw
 */
function requireEnv(name: string): string {
    const value = process.env[name]?.trim();
    if (!value) {
        throw new Error(`Missing required environment variable: ${name}`);
    }
    return value;
}

/**
 * 可選的環境變數（不存在時回傳 undefined）
 */
function optionalEnv(name: string): string | undefined {
    return process.env[name]?.trim() || undefined;
}

function parseURL(name: string): string {
    const value = requireEnv(name);
    let parsed: URL;

    try {
        parsed = new URL(value);
    } catch {
        throw new Error(`${name} must be a valid absolute URL`);
    }

    if (!['http:', 'https:'].includes(parsed.protocol)) {
        throw new Error(`${name} must use http or https`);
    }

    return parsed.toString();
}

function parseCoordinate(name: string, min: number, max: number): number {
    const raw = requireEnv(name);
    const value = Number(raw);

    if (!Number.isFinite(value) || value < min || value > max) {
        throw new Error(`${name} must be a number between ${min} and ${max}`);
    }

    return value;
}

const LOG_LEVELS = ['DEBUG', 'INFO', 'WARN', 'ERROR'] as const;
type LogLevel = typeof LOG_LEVELS[number];

function parseLogLevel(): LogLevel {
    const value = (optionalEnv('LOG_LEVEL') || 'INFO').toUpperCase();
    if (!LOG_LEVELS.includes(value as LogLevel)) {
        throw new Error(`LOG_LEVEL must be one of: ${LOG_LEVELS.join(', ')}`);
    }
    return value as LogLevel;
}

/**
 * 匯出環境變數集合
 */
export const env = {
    // 必要的環境變數
    baseURL: parseURL('BASE_URL'),
    companyCode: requireEnv('COMPANY_CODE'),
    username: requireEnv('AOA_USERNAME'),
    password: requireEnv('AOA_PASSWORD'),
    lat: parseCoordinate('AOA_LAT', -90, 90),
    lon: parseCoordinate('AOA_LON', -180, 180),
    timezoneId: optionalEnv('TZ') || 'Asia/Taipei',
    locale: optionalEnv('LOCALE') || 'zh-TW',
    
    // 通知相關（可選）
    discordWebhookUrl: optionalEnv('DISCORD_WEBHOOK_URL'),
    lineChannelAccessToken: optionalEnv('LINE_CHANNEL_ACCESS_TOKEN'),
    lineUserId: optionalEnv('LINE_USER_ID'),
    
    // 測試相關（可選）
    notifyTestImage: optionalEnv('NOTIFY_TEST_IMAGE'),
    ci: optionalEnv('CI'),
    
    // 日誌相關（可選）
    logLevel: parseLogLevel(),
};
