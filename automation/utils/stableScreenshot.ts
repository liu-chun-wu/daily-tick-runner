// automation/utils/stableScreenshot.ts
import { expect, type Page, type TestInfo } from '@playwright/test';
import { log } from './logger';

/** 進入出勤打卡頁後，等到畫面穩定可截圖 */
export async function waitForAttendanceReady(page: Page) {
    log.debug('Screenshot', '開始等待頁面穩定');
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
    
    log.debug('Screenshot', '頁面穩定完成，可以進行截圖');
}

/** 整頁截圖並回傳 Buffer（純截圖，不處理儲存） */
export async function captureFullPageScreenshot(page: Page): Promise<Buffer> {
    log.debug('Screenshot', '開始撷取全頁截圖');
    const buffer = await page.screenshot({ fullPage: true });
    log.info('Screenshot', `截圖完成，大小: ${(buffer.length / 1024).toFixed(2)} KB`);
    return buffer;
}

/** 整頁截圖 + 附到報表；回傳 Buffer 與輸出路徑 */
export async function fullPageScreenshotStable(page: Page, testInfo: TestInfo, name: string) {
    log.info('Screenshot', `開始截圖並儲存: ${name}`);
    
    // 截圖取得 Buffer
    const screenshotBuffer = await captureFullPageScreenshot(page);
    
    // 儲存到檔案
    const outPath = testInfo.outputPath(`${name}`);
    await page.screenshot({ path: outPath, fullPage: true });
    
    // 附加到測試報表
    await testInfo.attach(name, { path: outPath, contentType: 'image/png' });
    
    log.info('Screenshot', `截圖儲存完成: ${outPath}`);
    return { screenshotBuffer, outPath };
}
