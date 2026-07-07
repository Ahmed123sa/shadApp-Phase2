# Project Map — ShadApp

## Backend (Laravel)

### Notifications
- **12 Notification classes** in `backend/app/Notifications/` — all extended with `implements ShouldQueue`
- **FcmChannel** — custom channel for Firebase push; updated to clean up unregistered tokens
- **ContractReminderNotification** / **MeetingReminderNotification** — defined but now activated via commands

### Commands (new)
- `app/Console/Commands/SendContractReminders.php` — sends contract reminders daily at 09:00
- `app/Console/Commands/SendMeetingReminders.php` — sends meeting reminders every 30 min

### Scheduling
- `routes/console.php` — now contains `Schedule::command(...)` entries for the two reminders

### Broadcasting
- `app/Providers/BroadcastServiceProvider.php` — `Broadcast::routes()` now uses `prefix => 'api'`

### Configuration
- `config/broadcasting.php` — Reverb config
- `config/services.php` — FCM (server key, sender ID, service account path)
- `config/queue.php` — default `database`

## Fixes Applied (2026-07-06)

| # | Issue | Files Changed |
|---|-------|-------------|
| 5 | Broadcasting auth path mismatch | `BroadcastServiceProvider.php` |
| 3 | Unregistered token cleanup in FcmChannel | `FcmChannel.php` |
| 2 | Notifications not queued | All 12 `*Notification.php` classes |
| 6 | Missing `.env.example` | Created `.env.example` |
| 4 | Reminder notifications not activated | Created 2 Commands + updated `console.php` |

## Deployment Config
- `backend/supervisor/shadapp-worker.conf` — Supervisor config for `queue:work` (2 processes, auto-restart)
- `backend/supervisor/setup.sh` — Run on server to install Supervisor config + cron entry automatically

## Still Needed
- **Issue #1**: iOS `GoogleService-Info.plist` — requires Apple Developer account
- **Server setup**: Run `bash backend/supervisor/setup.sh` on the production server
  - Equivalent manual commands:
    1. `sudo cp backend/supervisor/shadapp-worker.conf /etc/supervisor/conf.d/ && sudo supervisorctl reread && sudo supervisorctl update && sudo supervisorctl start shadapp-worker:*`
    2. Add `* * * * * cd /path/to/project && php artisan schedule:run >> /dev/null 2>&1` to crontab
