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

## Fixes Applied (2026-07-17)

| # | Issue | Files Changed |
|---|-------|-------------|
| 1 | AM dashboard redesign — bottom nav (4 tabs AM, 5 tabs SA), stats grid, pending approvals, clients preview | `am_dashboard_page.dart` |
| 2 | Client management design improvements: Home card (remove delete, improve avatar/badge/chips), Clients card (long press → bottom sheet actions), Create form (remove contract_value/notes, add date_of_birth, improve AppBar/button), Detail page (remove notes, add date_of_birth, improve colors) | `am_dashboard_page.dart`, `sa_clients_page.dart`, `create_client_page.dart`, `client_detail_page.dart` |
| 3 | Backend: `date_of_birth` column for clients | Migration `2026_07_17_000002_add_date_of_birth_to_clients.php`, `Client.php`, `ClientController.php`, `StoreClientRequest.php`, `UpdateClientRequest.php` |

## Fixes Applied (2026-07-17 — Web Dashboard Redesign)

| # | Issue | Files Changed |
|---|-------|-------------|
| 1 | Web dashboard redesign — AM + SA views matching HTML design (sidebar, topbar, stat cards, two-column layout, activity feed, managers table) | `layout.tsx`, `page.tsx`, `globals.css` |
| 2 | New components: DashboardStatCard, ActivityFeed, ManagerTableRow | `components/dashboard/DashboardStatCard.tsx`, `components/dashboard/ActivityFeed.tsx`, `components/dashboard/ManagerTableRow.tsx` |
| 3 | Backend: `GET /approvals/pending` endpoint for SA dashboard | `ApprovalController.php`, `routes/api.php` |
| 4 | CSS: Tajawal font, new design tokens (crimson-soft, gold-soft, etc.), removed hardcoded RTL | `globals.css` |
| 5 | Translations: Added 30+ new keys for dashboard redesign | `messages/ar.json`, `messages/en.json` |
| 6 | Fixed PaymentsTab.tsx missing return in load() function | `components/payments/PaymentsTab.tsx` |
| 7 | Dashboard fixes: ws-wrap wrapper, pending approvals card (SA), nav active logic, AM nav items (messages/meetings/payments/files/contracts) with workspace links | `layout.tsx`, `page.tsx` |

## Fixes Applied (2026-07-17 — AM Dashboard Fixes)

| # | Issue | Files Changed |
|---|-------|-------------|
| 1 | Sidebar: "لوحة التحكم" → "الرئيسية" | `messages/ar.json`, `messages/en.json` |
| 2 | Sidebar: removed messages from AM nav, reorganized groups | `layout.tsx` |
| 3 | Sidebar + Topbar: avatar image from `avatar_url` (falls back to initials) | `layout.tsx` |
| 4 | Client card: removed "عقد #X", show `contact_person` instead, removed contract value column, added avatar image | `page.tsx` |
| 5 | Meetings view: fetches from `GET /all-meetings` with full details (title, client, scheduled_at, duration, status icon) + pagination | `page.tsx` |
| 6 | Payments view: fetches from `GET /payments/pending` with client name, amount, method, date/time + pagination | `page.tsx` |
| 7 | Files view: fetches from `GET /all-files` with client, filename, type, size, date + pagination | `page.tsx` |
| 8 | Backend: `GET /all-files` cross-workspace endpoint (AM scoped to their workspaces) | `FileController.php`, `routes/api.php` |
| 9 | Pagination controls in all list views (meetings, payments, files, contracts) | `page.tsx` |

## Cross-Workspace API Endpoints (Backend)

| Endpoint | Method | Auth | Description |
|----------|--------|------|-------------|
| `/all-meetings` | GET | AM + SA | Paginated meetings across workspaces (AM scoped) |
| `/payments/pending` | GET | AM + SA | Paginated pending payments across workspaces (AM scoped) |
| `/all-files` | GET | AM + SA | Paginated file entries across workspaces (AM scoped) |
| `/all-payments` | GET | AM + SA | Paginated all payments across workspaces (AM scoped) |
| `/all-contracts` | GET | AM + SA | Paginated contracts across workspaces |
| `/approvals/pending` | GET | SA only | Pending approvals across all workspaces |

## Fixes Applied (2026-07-17 — 3 Bug Fixes)

| # | Issue | Files Changed |
|---|-------|-------------|
| 1 | Contracts don't show basic/additional type — added `contract_type` to types + column in dashboard contracts table + badge in ContractsTab | `types/index.ts`, `page.tsx`, `ContractsTab.tsx` |
| 2 | Files view "no data" — `FileEntryPolicy` was missing (403 on every request) | `FileEntryPolicy.php` (new), `AuthServiceProvider.php` |
| 3 | `url.startsWith is not a function` crash — `proof_file_url` is array but frontend treated as string | `PaymentsTab.tsx`, `ClientPayments.tsx`, `types/index.ts` |

## Backend Policies

| Model | Policy | Registered |
|-------|--------|-----------|
| Workspace | WorkspacePolicy | ✅ |
| Client | ClientPolicy | ✅ |
| Contract | ContractPolicy | ✅ |
| Payment | PaymentPolicy | ✅ |
| FileEntry | FileEntryPolicy | ✅ (added) |
| Approval | ApprovalPolicy | ✅ |
| Meeting | MeetingPolicy | ✅ |
| SubUser | SubUserPolicy | ✅ |

## Fixes Applied (2026-07-17 — Seed Data + Payments Endpoint)

| # | Issue | Files Changed |
|---|-------|-------------|
| 1 | Seed data: added 3 files, 3 meetings, 2 extra payments (approved + pending) | `DatabaseSeeder.php` |
| 2 | New `GET /all-payments` endpoint — shows ALL payments (not just pending) | `PaymentController.php`, `routes/api.php` |
| 3 | AM sidebar: added Settings group | `layout.tsx` |
