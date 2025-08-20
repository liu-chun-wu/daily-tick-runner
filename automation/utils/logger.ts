// automation/utils/logger.ts

/**
 * 統一的日誌工具
 * 提供結構化的日誌輸出，方便後續觀察和調試
 */

enum LogLevel {
    DEBUG = 0,
    INFO = 1,
    WARN = 2,
    ERROR = 3
}

class Logger {
    private static instance: Logger;
    private logLevel: LogLevel = LogLevel.DEBUG;

    private constructor() {
        // 從環境變數設定日誌等級
        const envLevel = process.env.LOG_LEVEL?.toUpperCase();
        switch (envLevel) {
            case 'DEBUG':
                this.logLevel = LogLevel.DEBUG;
                break;
            case 'INFO':
                this.logLevel = LogLevel.INFO;
                break;
            case 'WARN':
                this.logLevel = LogLevel.WARN;
                break;
            case 'ERROR':
                this.logLevel = LogLevel.ERROR;
                break;
            default:
                this.logLevel = LogLevel.INFO;
        }
    }

    static getInstance(): Logger {
        if (!Logger.instance) {
            Logger.instance = new Logger();
        }
        return Logger.instance;
    }

    private formatMessage(level: string, module: string, message: string, data?: any): string {
        const timestamp = new Date().toISOString();
        const baseMessage = `[${timestamp}] [${level}] [${module}] ${message}`;

        if (data !== undefined) {
            return `${baseMessage} ${JSON.stringify(data)}`;
        }
        return baseMessage;
    }

    private shouldLog(level: LogLevel): boolean {
        return level >= this.logLevel;
    }

    debug(module: string, message: string, data?: any): void {
        if (this.shouldLog(LogLevel.DEBUG)) {
            console.debug(this.formatMessage('DEBUG', module, message, data));
        }
    }

    info(module: string, message: string, data?: any): void {
        if (this.shouldLog(LogLevel.INFO)) {
            console.log(this.formatMessage('INFO', module, message, data));
        }
    }

    warn(module: string, message: string, data?: any): void {
        if (this.shouldLog(LogLevel.WARN)) {
            console.warn(this.formatMessage('WARN', module, message, data));
        }
    }

    error(module: string, message: string, error?: Error | any): void {
        if (this.shouldLog(LogLevel.ERROR)) {
            const errorData = error instanceof Error ? {
                name: error.name,
                message: error.message,
                stack: error.stack
            } : error;

            console.error(this.formatMessage('ERROR', module, message, errorData));
        }
    }

    /**
     * 記錄測試步驟開始
     */
    stepStart(module: string, stepName: string, data?: any): void {
        this.info(module, `🚀 開始執行: ${stepName}`, data);
    }

    /**
     * 記錄測試步驟完成
     */
    stepComplete(module: string, stepName: string, duration?: number): void {
        const durationMsg = duration ? ` (耗時: ${duration}ms)` : '';
        this.info(module, `✅ 完成: ${stepName}${durationMsg}`);
    }

    /**
     * 記錄測試步驟失敗
     */
    stepFailed(module: string, stepName: string, error: Error): void {
        this.error(module, `❌ 失敗: ${stepName}`, error);
    }

    /**
     * 記錄通知發送
     */
    notifyStart(module: string, platform: string, hasImage: boolean): void {
        const imageMsg = hasImage ? '(含圖片)' : '(純文字)';
        this.info(module, `📤 開始發送通知至 ${platform} ${imageMsg}`);
    }

    /**
     * 記錄通知成功
     */
    notifySuccess(module: string, platform: string): void {
        this.info(module, `✅ 通知發送成功至 ${platform}`);
    }

    /**
     * 記錄通知失敗
     */
    notifyFailed(module: string, platform: string, error: Error): void {
        this.warn(module, `⚠️ 通知發送失敗至 ${platform} (non-blocking)`, error);
    }
}

// 匯出單例實例
export const logger = Logger.getInstance();

// 匯出便利函數
export const log = {
    debug: (module: string, message: string, data?: any) => logger.debug(module, message, data),
    info: (module: string, message: string, data?: any) => logger.info(module, message, data),
    warn: (module: string, message: string, data?: any) => logger.warn(module, message, data),
    error: (module: string, message: string, error?: Error | any) => logger.error(module, message, error),

    stepStart: (module: string, stepName: string, data?: any) => logger.stepStart(module, stepName, data),
    stepComplete: (module: string, stepName: string, duration?: number) => logger.stepComplete(module, stepName, duration),
    stepFailed: (module: string, stepName: string, error: Error) => logger.stepFailed(module, stepName, error),

    notifyStart: (module: string, platform: string, hasImage: boolean) => logger.notifyStart(module, platform, hasImage),
    notifySuccess: (module: string, platform: string) => logger.notifySuccess(module, platform),
    notifyFailed: (module: string, platform: string, error: Error) => logger.notifyFailed(module, platform, error),
};