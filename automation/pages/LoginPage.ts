import { Page, expect } from '@playwright/test';

type Creds = { companyCode: string; username: string; password: string };

export class LoginPage {
    constructor(private page: Page) { }

    // 依你的 DOM：placeholder=公司代號/帳號/密碼；登入按鈕文字=登入
    private get companyCodeInput() { return this.page.getByPlaceholder('公司代號'); } // 推薦用 getByPlaceholder :contentReference[oaicite:2]{index=2}
    private get usernameInput() { return this.page.getByPlaceholder('帳號'); }
    private get passwordInput() { return this.page.getByPlaceholder('密碼'); }
    private get submitBtn() { return this.page.getByRole('button', { name: '登入' }); } // 以可存取性 role 定位按鈕 :contentReference[oaicite:3]{index=3}

    async login({ companyCode, username, password }: Creds) {
        await this.companyCodeInput.fill(companyCode);
        await this.usernameInput.fill(username);
        await this.passwordInput.fill(password);
        await this.submitBtn.click();

        // 登入後首頁會看到「出勤打卡」卡片（ion-col）。避免裸用 :has-text，搭配標籤限定。:contentReference[oaicite:4]{index=4}
        await expect(this.page.locator('ion-col:has-text("出勤打卡")')).toBeVisible();
    }
}
