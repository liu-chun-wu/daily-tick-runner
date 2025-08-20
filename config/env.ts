import 'dotenv/config';

/**
 * 小工具：檢查環境變數是否存在，沒有就直接 throw
 */
function requireEnv(name: string): string {
    const value = process.env[name];
    if (!value) {
        throw new Error(`❌ Missing environment variable: ${name}`);
    }
    return value;
}

/**
 * 可選的環境變數（不存在時回傳 undefined）
 */
function optionalEnv(name: string): string | undefined {
    return process.env[name];
}

/**
 * 匯出環境變數集合
 */
export const env = {
    // 必要的環境變數
    baseURL: requireEnv('BASE_URL'),
    companyCode: requireEnv('COMPANY_CODE'),
    username: requireEnv('AOA_USERNAME'),
    password: requireEnv('AOA_PASSWORD'),
    lat: Number(requireEnv('AOA_LAT')),
    lon: Number(requireEnv('AOA_LON')),
    timezoneId: requireEnv('TZ'),
    locale: requireEnv('LOCALE'),
    
    // 通知相關（可選）
    discordWebhookUrl: optionalEnv('DISCORD_WEBHOOK_URL'),
    lineChannelAccessToken: optionalEnv('LINE_CHANNEL_ACCESS_TOKEN'),
    lineUserId: optionalEnv('LINE_USER_ID'),
    
    // 測試相關（可選）
    notifyTestImage: optionalEnv('NOTIFY_TEST_IMAGE'),
    ci: optionalEnv('CI'),
    
    // 日誌相關（可選）
    logLevel: optionalEnv('LOG_LEVEL') || 'INFO',
};
