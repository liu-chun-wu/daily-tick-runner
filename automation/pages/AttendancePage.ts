import { expect, type Locator, type Page } from '@playwright/test';

export type AttendanceResult =
    | { status: 'success'; title: '打卡成功'; detail?: string }
    | { status: 'failure'; title: '打卡失敗'; detail?: string };

export type AttendanceAction = 'checkin' | 'checkout';

export class AttendancePage {
    constructor(private page: Page) { }

    private attendanceButton(action: AttendanceAction): Locator {
        const name = action === 'checkin' ? '簽到' : '簽退';
        return this.page.getByRole('button', { name });
    }

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
        await expect(this.attendanceButton('checkin')).toBeVisible({ timeout: 15000 });
        await expect(this.attendanceButton('checkout')).toBeVisible({ timeout: 15000 });
    }

    async checkIn(resultTimeout = 15000): Promise<AttendanceResult> {
        return this.performAttendance('checkin', resultTimeout);
    }

    async checkOut(resultTimeout = 15000): Promise<AttendanceResult> {
        return this.performAttendance('checkout', resultTimeout);
    }

    private async performAttendance(action: AttendanceAction, resultTimeout: number): Promise<AttendanceResult> {
        const buttonName = action === 'checkin' ? '簽到' : '簽退';
        const button = this.attendanceButton(action);
        const buttonCount = await button.count();
        if (buttonCount !== 1) {
            throw new Error(`Expected exactly one ${buttonName} button, found ${buttonCount}`);
        }
        await expect(button).toBeEnabled({ timeout: 10000 });

        // 真實操作的唯一 click。結果失敗或逾時時，呼叫端不得自動重試。
        await button.click();

        const alert = this.page.locator('.alert-wrapper');
        const titleLocator = this.page.locator('.alert-title');
        const deadline = Date.now() + resultTimeout;
        try {
            await alert.waitFor({ state: 'visible', timeout: resultTimeout });
            const remaining = Math.max(deadline - Date.now(), 1);
            await expect(titleLocator).not.toHaveText(/^\s*$/, { timeout: remaining });
        } catch {
            throw new Error(`Attendance result did not appear within ${resultTimeout}ms`);
        }

        const title = (await titleLocator.textContent())?.trim() || '';
        const detailLocator = this.page.locator('.alert-sub-title');
        const detail = await detailLocator.count()
            ? (await detailLocator.textContent())?.trim() || undefined
            : undefined;

        if (title === '打卡成功') {
            return { status: 'success', title, detail };
        }
        if (title === '打卡失敗') {
            return { status: 'failure', title, detail };
        }

        throw new Error(`Unexpected attendance result title: ${title || '(empty)'}`);
    }
}
