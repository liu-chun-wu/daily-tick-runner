# Repository guidance

Daily Tick Runner is a Node.js 24+ and Playwright 1.61.0 project for authorized attendance automation. GitHub Actions is the only supported scheduler and deployment environment.

## Safety boundary

Never run these commands during routine development, CI verification, or automated review:

- `npm run attendance:checkin`
- `npm run attendance:checkout`
- `npm run notify:test`
- `npm run smoke:notify`

They cause real external side effects. Safe verification commands are:

```bash
npm ci
npm run test:list
npm run test:result
```

`npm test` and `npm run test:smoke` do not click attendance or send notifications, but they do log into the configured target and therefore require an authorized environment.

`npm run smoke:notify` is an explicit side-effecting command. It is permitted only in the manually dispatched `Smoke Latest Image` notification step; pushes, pull requests, and `Build & Promote Image` must never invoke it. It sends a summary and one successful Smoke screenshot only after the safe suite passes. Discord is required for the image upload; configured LINE delivery reuses the returned Discord CDN URL. Missing screenshots or notification failures must fail that manual validation without changing `latest`.

## Runtime contract

Required environment variables:

- `BASE_URL`
- `COMPANY_CODE`
- `AOA_USERNAME`
- `AOA_PASSWORD`
- `AOA_LAT`
- `AOA_LON`

Optional notification variables are `DISCORD_WEBHOOK_URL`, `LINE_CHANNEL_ACCESS_TOKEN`, and `LINE_USER_ID`. Defaults are `TZ=Asia/Taipei`, `LOCALE=zh-TW`, and `LOG_LEVEL=INFO`.

Do not add real URLs, company codes, coordinates, credentials, or GitHub repository owners as fallbacks. Local values belong in `.env`; GitHub values belong in Repository Secrets, not Variables.

## Attendance invariants

- A production attempt clicks the selected attendance button exactly once.
- `chromium-click` retries must remain 0.
- Production workflow must not add a retry wrapper.
- `打卡成功` returns an `AttendanceResult` success.
- `打卡失敗` returns failure; the caller captures evidence and fails.
- Missing or unknown results throw; the caller captures evidence and fails.
- A failed run must never infer that the remote operation did not occur.
- Only a human may decide to launch another production run.

Maintain success, failure, unknown-title, and timeout coverage in `attendance-result.spec.ts`, including click-count assertions.

## Image lifecycle

`Build & Promote Image` must:

1. Build and push the Fork-owned `runner:sha-<commit>`.
2. Run `test:list`, result tests, login, and safe Smoke using that exact image.
3. Promote that same image to `latest` only after success.

Cancellation or failure must leave the existing `latest` unchanged. PRs have no Secrets: they only build locally and run `test:list`, with no target login and no GHCR push.

`Smoke Latest Image` must pull `latest` once, pin its digest for every validation step, and have no image build or package write path. Its success, failure, or cancellation must never change `latest`.

Image names must be derived from lower-case `github.repository`; authentication uses the repository `GITHUB_TOKEN`. Smoke Latest and Production pull `latest` and must not checkout code or install dependencies.

## Versions and files

- Keep `@playwright/test` and `mcr.microsoft.com/playwright` at exactly 1.61.0.
- Keep `package-lock.json` synchronized with `package.json`.
- Keep Node engines at 24+.
- Do not add `undici`; native Node fetch is sufficient.
- Keep `.env*`, `playwright/.auth`, screenshots, reports, and test artifacts out of Docker images.
- Do not reintroduce a local or host scheduler.

## Documentation ownership

- `README.md`: shortest user path and command safety.
- `DEPLOYMENT.md`: the only deployment and scheduling source.
- `ARCHITECTURE.md`: implemented architecture only.
- `DEVELOPMENT.md`: contributor workflow.
- `docs/SECURITY.md` and `docs/TROUBLESHOOTING.md`: operational safety and diagnostics.

When commands, workflows, versions, Secrets, or result behavior changes, update every affected document in the same change.
