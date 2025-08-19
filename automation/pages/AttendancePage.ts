import { Page, expect } from '@playwright/test';

export class AttendancePage {
    constructor(private page: Page) { }

    async goto() {
        // 依賴 config 的 baseURL，這裡的 '/' 會展開成你的 BASE_URL
        await this.page.goto('/'); // ← 關鍵：先把空白頁導到首頁
        // 首頁卡片：<ion-col><p>出勤打卡</p>。用 :has-text() 鎖在 ion-col 節點上。:contentReference[oaicite:5]{index=5}
        const card = this.page.locator('ion-col:has-text("出勤打卡")');
        await expect(card).toBeVisible();        // Web-first assertion 會自動等待
        await card.click();
        // 到頁面後，簽到/簽退按鈕都應可見（使用 getByRole('button', {name})）。:contentReference[oaicite:6]{index=6}
        await expect(this.page.getByRole('button', { name: '簽到' })).toBeVisible();
        await expect(this.page.getByRole('button', { name: '簽退' })).toBeVisible();
    }

    async checkIn() {
        await this.page.getByRole('button', { name: '簽到' }).click();
        // 煙霧層級：至少確認按鈕仍可互動（避免 click 被遮罩）。
        await expect(this.page.getByRole('button', { name: '簽到' })).toBeVisible();
    }

    async checkOut() {
        await this.page.getByRole('button', { name: '簽退' }).click();
        await expect(this.page.getByRole('button', { name: '簽退' })).toBeVisible();
    }
}
