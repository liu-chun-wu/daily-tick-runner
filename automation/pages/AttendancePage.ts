import { Page, expect } from '@playwright/test';

export class AttendancePage {
    constructor(private page: Page) { }

    async goto() {
        // 依賴 config 的 baseURL，這裡的 '/' 會展開成你的 BASE_URL
        await this.page.goto('/'); // ← 關鍵：先把空白頁導到首頁
        
        // 等待頁面完全載入
        await this.page.waitForLoadState('networkidle');
        
        // 首頁卡片：<ion-col><p>出勤打卡</p>。用 :has-text() 鎖在 ion-col 節點上。
        const card = this.page.locator('ion-col:has-text("出勤打卡")');
        await expect(card).toBeVisible({ timeout: 15000 });        // 延長等待時間
        
        // 確保卡片完全載入後才點擊
        await this.page.waitForTimeout(1000);
        await card.click();
        
        // 等待導航完成
        await this.page.waitForLoadState('networkidle');
        
        // 到頁面後，簽到/簽退按鈕都應可見（使用 getByRole('button', {name})）。
        await expect(this.page.getByRole('button', { name: '簽到' })).toBeVisible({ timeout: 15000 });
        await expect(this.page.getByRole('button', { name: '簽退' })).toBeVisible({ timeout: 15000 });
    }

    async checkIn() {
        // 確保按鈕可以點擊
        const checkInButton = this.page.getByRole('button', { name: '簽到' });
        await expect(checkInButton).toBeEnabled({ timeout: 10000 });
        
        // 等待一下確保頁面穩定
        await this.page.waitForTimeout(500);
        
        await checkInButton.click();
        
        // 煙霧層級：至少確認按鈕仍可互動（避免 click 被遮罩）。
        await expect(this.page.getByRole('button', { name: '簽到' })).toBeVisible();
    }

    async checkOut() {
        // 確保按鈕可以點擊
        const checkOutButton = this.page.getByRole('button', { name: '簽退' });
        await expect(checkOutButton).toBeEnabled({ timeout: 10000 });
        
        // 等待一下確保頁面穩定
        await this.page.waitForTimeout(500);
        
        await checkOutButton.click();
        
        await expect(this.page.getByRole('button', { name: '簽退' })).toBeVisible();
    }
}