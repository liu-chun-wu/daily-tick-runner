// automation/utils/stableScreenshot.ts
import { expect, type Page, type TestInfo } from '@playwright/test';

/** 進入出勤打卡頁後，等到畫面穩定可截圖 */
export async function waitForAttendanceReady(page: Page) {
    // 1) DOM ready
    await page.waitForLoadState('domcontentloaded'); // DOM 解析完成
    // 2) 核心 UI 就緒（web-first 斷言自動等待）
    await expect(page.getByRole('button', { name: '簽到' })).toBeVisible();
    await expect(page.getByRole('button', { name: '簽退' })).toBeVisible(); // 
    // 3) 盡量等到沒有網路活動（SPA 有時不會觸發也沒關係）
    try { await page.waitForLoadState('networkidle', { timeout: 2500 }); } catch { }
    // 4) 兩個 requestAnimationFrame，讓 layout/paint 穩一下
    await page.evaluate(() => new Promise<void>(r => requestAnimationFrame(() => requestAnimationFrame(() => r()))));
    // 5) 停掉動畫與轉場，避免截到半張（page.screenshot 沒有 animations 參數，所以用 CSS）
    await page.addStyleTag({
        content: `
      *, *::before, *::after {
        transition-duration: 0s !important;
        animation-duration: 0s !important;
        animation-iteration-count: 1 !important;
        caret-color: transparent !important;
      }`
    });
}

/** 整頁截圖 + 附到報表；回傳輸出檔路徑 */
export async function fullPageScreenshotStable(page: Page, testInfo: TestInfo, name: string) {
    const outPath = testInfo.outputPath(`${name}.png`);
    await page.screenshot({ path: outPath, fullPage: true });        // 整頁截圖 
    await testInfo.attach(`${name}.png`, { path: outPath, contentType: 'image/png' }); // 報表附件 
    return outPath;
}
