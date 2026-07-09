# Project Map — ShadApp

## Backend (Laravel)

### Notifications
- **12 Notification classes** in `backend/app/Notifications/` — all extended with `implements ShouldQueue`
- **FcmChannel** — custom channel for Firebase push; updated to clean up unregistered tokens
- **ContractReminderNotification** / **MeetingReminderNotification** — defined but now activated via commands

### Commands
- `app/Console/Commands/SendContractReminders.php` — sends contract reminders daily at 09:00
- `app/Console/Commands/SendMeetingReminders.php` — sends meeting reminders every 30 min

### Scheduling
- `routes/console.php` — contains `Schedule::command(...)` entries for the two reminders

### Broadcasting
- `app/Providers/BroadcastServiceProvider.php` — `Broadcast::routes()` now uses `prefix => 'api'`

### Configuration
- `config/broadcasting.php` — Reverb config
- `config/services.php` — FCM (server key, sender ID, service account path)
- `config/queue.php` — default `database`
- `config/cors.php` — CORS (allowed_origins: `['*']`)
- `config/sanctum.php` — token expiration: `null` (never expires), `stateful` domains configured

### API Security
- Rate limiting (`throttle:5,1`) on auth endpoints: `/auth/register`, `/auth/login`, `/auth/client/login`
- File uploads restricted to `mimes:pdf,jpg,jpeg,png,doc,docx,xls,xlsx,zip`

## Dashboard (Next.js)

### Middleware
- `src/middleware.ts` — active middleware: i18n (next-intl) + `/storage/*` proxy to Laravel backend
- `i18n/middleware.ts` — i18n middleware (imported by `src/middleware.ts`)

### Auth
- Staff: `localStorage['token']` + `localStorage['user']`
- Client: `localStorage['client_token']` + `localStorage['client']`

## Mobile (Flutter)

### Real-time
- `core/reverb_service.dart` — WebSocket via env-based scheme (supports `ws://` and `wss://`)

## CI/CD
- `.github/workflows/backend.yml` — GitHub Actions: runs PHPUnit on push/PR to master (with Postgres service)

## Fixes Applied (2026-07-06)

| # | Issue | Files Changed |
|---|-------|-------------|
| 5 | Broadcasting auth path mismatch | `BroadcastServiceProvider.php` |
| 3 | Unregistered token cleanup in FcmChannel | `FcmChannel.php` |
| 2 | Notifications not queued | All 12 `*Notification.php` classes |
| 6 | Missing `.env.example` | Created `.env.example` |
| 4 | Reminder notifications not activated | Created 2 Commands + updated `console.php` |

## Fixes Applied (2026-07-07)

| # | Issue | Files Changed |
|---|-------|-------------|
| 1.1 | Rate limiting on auth endpoints | `routes/api.php` |
| 1.2 | MIME type restriction on file uploads | `Domains/File/FileController.php` |
| 2.2 | Storage proxy not working (middleware) | Created `src/middleware.ts` |
| 2.3 | Old `.bak` file in repo | Deleted `src/proxy.ts.bak` |
| 5.1 | Mobile WebSocket hardcoded `ws://` | `core/reverb_service.dart` |
| 3.1 | No CI/CD | Created `.github/workflows/backend.yml` |

## Deployment Config
- `backend/supervisor/shadapp-worker.conf` — Supervisor config for `queue:work` (2 processes, auto-restart)
- `backend/supervisor/setup.sh` — Run on server to install Supervisor config + cron entry automatically

## Still Needed
- **iOS**: `GoogleService-Info.plist` — requires Apple Developer account
- **Server setup**: Run `bash backend/supervisor/setup.sh` on the production server
  - Equivalent manual commands:
    1. `sudo cp backend/supervisor/shadapp-worker.conf /etc/supervisor/conf.d/ && sudo supervisorctl reread && sudo supervisorctl update && sudo supervisorctl start shadapp-worker:*`
    2. Add `* * * * * cd /path/to/project && php artisan schedule:run >> /dev/null 2>&1` to crontab
- **Dashboard**: Move tokens from `localStorage` to httpOnly cookies (XSS protection)
- **README**: No README files in any sub-project or root
- **Docker**: No docker-compose or Dockerfiles
