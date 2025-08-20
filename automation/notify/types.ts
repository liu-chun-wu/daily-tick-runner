// automation/notify/types.ts

/**
 * 通用的通知選項介面
 * 所有通知服務（Discord、LINE 等）都應該使用這個介面
 */
export interface NotifyOpts {
    /** 通知訊息內容 */
    message: string;
    
    /** 截圖檔案名稱 */
    filename?: string;
    
    /** 截圖的 Buffer 資料（優先使用） */
    screenshotBuffer?: Buffer;
    
    /** 截圖檔案路徑（當沒有 Buffer 時的後備方案） */
    screenshotPath?: string;
    
    /** 已上傳的圖片 URL（避免重複上傳） */
    imageUrl?: string;
}