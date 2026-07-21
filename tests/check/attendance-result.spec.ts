import { expect, test, type Page } from '@playwright/test';
import { AttendancePage } from '../../automation/pages/AttendancePage';

async function renderAttendance(page: Page, title?: string, detail = '') {
    await page.setContent(`
        <button type="button">簽到</button>
        <button type="button">簽退</button>
        <script>
            window.clickCount = 0;
            for (const button of document.querySelectorAll('button')) {
                button.addEventListener('click', () => {
                    window.clickCount += 1;
                    ${title === undefined ? '' : `document.body.insertAdjacentHTML('beforeend', '<div class="alert-wrapper"><div class="alert-title">${title}</div><div class="alert-sub-title">${detail}</div></div>');`}
                });
            }
        </script>
    `);
}

async function clickCount(page: Page) {
    return page.evaluate(() => (window as typeof window & { clickCount: number }).clickCount);
}

test('成功 alert 回傳 success，且只點一次', { tag: '@result' }, async ({ page }) => {
    await renderAttendance(page, '打卡成功', '08:30:00');
    const result = await new AttendancePage(page).checkIn(100);

    expect(result).toEqual({ status: 'success', title: '打卡成功', detail: '08:30:00' });
    expect(await clickCount(page)).toBe(1);
});

test('失敗 alert 回傳 failure，且不重新點擊', { tag: '@result' }, async ({ page }) => {
    await renderAttendance(page, '打卡失敗', '超出允許範圍');
    const result = await new AttendancePage(page).checkOut(100);

    expect(result).toEqual({ status: 'failure', title: '打卡失敗', detail: '超出允許範圍' });
    expect(await clickCount(page)).toBe(1);
});

test('未知標題拋出例外，且只點一次', { tag: '@result' }, async ({ page }) => {
    await renderAttendance(page, '請稍後再試');
    await expect(new AttendancePage(page).checkIn(100)).rejects.toThrow('Unexpected attendance result title');
    expect(await clickCount(page)).toBe(1);
});

test('沒有結果時 timeout，且只點一次', { tag: '@result' }, async ({ page }) => {
    await renderAttendance(page);
    await expect(new AttendancePage(page).checkOut(50)).rejects.toThrow('Attendance result did not appear within 50ms');
    expect(await clickCount(page)).toBe(1);
});
