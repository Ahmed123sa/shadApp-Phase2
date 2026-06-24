import 'package:go_router/go_router.dart';
import 'api_client.dart';
import '../features/auth/login_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/am/dashboard/am_dashboard_page.dart';
import '../features/am/clients/create_client_page.dart';
import '../features/am/managers/account_managers_page.dart';
import '../features/am/workspace/am_workspace_page.dart';
import '../features/am/reports/reports_page.dart';
import '../features/signature/signature_page.dart';
import '../features/preview/preview_page.dart';
import '../features/notifications/notifications_page.dart';
import '../features/am/reports/audit_log_page.dart';

GoRouter createRouter(ApiClient api, {String initialLocation = '/login'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/preview', builder: (_, __) => const PreviewPage()),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardPage()),
      GoRoute(path: '/signature', builder: (_, __) => const SignaturePage()),
      GoRoute(path: '/am/dashboard', builder: (_, __) => const AmDashboardPage()),
      GoRoute(path: '/am/clients/create', builder: (_, __) => const CreateClientPage()),
      GoRoute(path: '/am/managers', builder: (_, __) => const AccountManagersPage()),
      GoRoute(path: '/am/workspace/:id', builder: (_, state) => const AmWorkspacePage()),
      GoRoute(path: '/am/reports', builder: (_, __) => const ReportsPage()),
      GoRoute(path: '/am/audit-logs', builder: (_, __) => const AuditLogPage()),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsPage()),
    ],
  );
}
