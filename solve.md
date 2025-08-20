可以，**你的情境（只要當下查看、不需保存 >24h）用 Discord 的附件連結當作 LINE 圖片訊息的 URL 是可行的**。做法是：把截圖先用 Discord Webhook 上傳，拿到 Discord 回傳的「附件簽名連結」，再把這個連結丟給 LINE Messaging API 的 `image` 訊息（`originalContentUrl`/`previewImageUrl` 都放同一個 URL）。LINE 只要求是可直接存取的 **HTTPS** 連結即可。([LINE Developers][1])

不過要知道 **Discord 的附件連結是會過期的**（URL 會帶 `ex`、`is`、`hm` 等簽名參數；官方安全調整後，連結大約 24 小時失效），過期後 LINE 端就載不到圖了——你說只要「當下」看得到，這樣正好符合。([BleepingComputer][2], [Hacker News][3])

---

# 實作步驟（Playwright smoke 測試友善）

**流程圖**

1. 取得截圖 `Buffer`
2. 上傳到 Discord Webhook（**帶 `?wait=true`**）→ 取得回應 JSON
3. 從回應的 `attachments[0].url` 取出「簽名連結」
4. 呼叫 LINE `pushMessage` 發 `image`，兩個 URL 都塞上面那個連結

> 為什麼 `?wait=true`：Discord 的 Webhook 端點會依 `wait` 決定是否回傳「完整訊息 JSON」（含 `attachments`），要拿附件連結就加上它。([discord.com][4], [Stack Overflow][5], [birdie0.github.io][6])

**TypeScript 範例（Node 18+）**

```ts
// discord-upload.ts
import { Blob } from 'buffer';
import fetch from 'node-fetch'; // Node 18 可用 global fetch，視你的專案而定

export async function uploadToDiscordAndGetUrl(
  webhookUrl: string,
  imageBuffer: Buffer,
  filename = 'screenshot.png',
  content = 'Smoke 截圖'
): Promise<string> {
  const url = webhookUrl.includes('?') ? `${webhookUrl}&wait=true` : `${webhookUrl}?wait=true`;

  const form = new FormData();
  // payload_json 可同時帶文字等欄位
  form.append(
    'payload_json',
    JSON.stringify({
      content,
      // 附件宣告（對應 files[0]）
      attachments: [{ id: 0, filename }],
    })
  );
  // 對應上面 attachments.id
  const blob = new Blob([imageBuffer], { type: 'image/png' });
  // 參數名稱慣例：files[0]
  form.append('files[0]', blob, filename);

  const res = await fetch(url, { method: 'POST', body: form as any });
  if (!res.ok) {
    throw new Error(`Discord upload failed: ${res.status} ${res.statusText}`);
  }
  const msg = await res.json() as {
    attachments?: Array<{ url: string }>;
  };

  const cdnUrl = msg.attachments?.[0]?.url;
  if (!cdnUrl) throw new Error('No attachment url returned from Discord');
  return cdnUrl; // 這是簽名 CDN 連結（~24h 有效）
}
```

```ts
// line.ts（關鍵片段）
import { Client } from '@line/bot-sdk';
import { uploadToDiscordAndGetUrl } from './discord-upload';

const line = new Client({ channelAccessToken: process.env.LINE_CHANNEL_ACCESS_TOKEN! });

export async function notifyLineWithDiscordImage({
  to,
  text,
  imageBuffer,
}: {
  to: string;            // userId / roomId / groupId
  text: string;          // 先發文字
  imageBuffer?: Buffer;  // 要附的截圖
}) {
  // 1) 先送文字（就算圖片失敗至少有訊息）
  await line.pushMessage(to, { type: 'text', text });

  if (!imageBuffer) return;

  // 2) 丟到 Discord 拿 CDN 連結（約 24h 內有效）
  const discordUrl = await uploadToDiscordAndGetUrl(
    process.env.DISCORD_WEBHOOK_URL!,
    imageBuffer,
    'smoke-screenshot.png',
    text
  );

  // 3) 用 LINE 發 image（兩個 URL 都要是 HTTPS）
  await line.pushMessage(to, {
    type: 'image',
    originalContentUrl: discordUrl,
    previewImageUrl:    discordUrl,
  });
}
```

**重點說明**

* LINE 的圖片訊息只要求 **HTTPS** 直連；不會幫你代管檔案。上面做法完全符合官方說明。([LINE Developers][1])
* Discord Webhook 檔案上傳需 **multipart/form-data**；常見做法是用 `payload_json` 搭配 `files[0]` 等欄位。([birdie0.github.io][7])
* Webhook URL **加上 `?wait=true`**，就能拿到訊息 JSON（含 `attachments[*].url`），讓你立即把連結餵給 LINE。([discord.com][4], [Stack Overflow][5])
* Discord 的附件連結 **約 24 小時後失效**（安全調整），過期後 LINE 端圖片會壞，但你說只要當下看，OK。([BleepingComputer][2])

---

# 實務建議（讓 smoke 更穩）

* **只在需要時發圖**：加旗標 `ENABLE_IMAGE_NOTIFY=true` 再發圖；否則只發文字＋（可選）Playwright Trace 連結，避免偶發失敗。
* **線上環境再換 S3/R2**（若未來需要長期可讀、留存通知歷史），本地或 CI 就用 Discord 快速查看。
* **速率控制**：若大量測試同時推送，遇到 429 要做退避（LINE/Discord 都可能回 429；一般遵守 `Retry-After` 即可）。([LINE Developers][8], [MDN Web Docs][9])

如果你願意，我可以把你現有的 `line.ts`/smoke 測試的「通知步驟」改成上面的結構（**文字必送、圖片經 Discord、LINE 只吃 URL**），並加一個環境變數開關來控制是否附圖。

[1]: https://developers.line.biz/en/docs/messaging-api/message-types/?utm_source=chatgpt.com "Message types | LINE Developers"
[2]: https://www.bleepingcomputer.com/news/security/discord-will-switch-to-temporary-file-links-to-block-malware-delivery/?utm_source=chatgpt.com "Discord will switch to temporary file links to block malware ..."
[3]: https://news.ycombinator.com/item?id=37697698&utm_source=chatgpt.com "if you haven't noticed, copying a link for a file now appends ..."
[4]: https://discord.com/developers/docs/resources/webhook?utm_source=chatgpt.com "Webhook Resource | Documentation"
[5]: https://stackoverflow.com/questions/67423330/edit-discord-message-from-webhook?utm_source=chatgpt.com "Edit discord message from webhook"
[6]: https://birdie0.github.io/discord-webhooks-guide/other/edit_webhook_message.html?utm_source=chatgpt.com "Edit Webhook Message - Discord Webhooks Guide"
[7]: https://birdie0.github.io/discord-webhooks-guide/structure/file.html?utm_source=chatgpt.com "file - Discord Webhooks Guide"
[8]: https://developers.line.biz/en/docs/messaging-api/development-guidelines/?utm_source=chatgpt.com "Messaging API development guidelines - LINE Developers"
[9]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status/429?utm_source=chatgpt.com "429 Too Many Requests - HTTP - MDN"
