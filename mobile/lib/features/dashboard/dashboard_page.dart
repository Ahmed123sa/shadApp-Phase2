import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/locale_provider.dart';
import '../../core/widgets/shad_logo.dart';
import '../../core/widgets/stages_stepper.dart';
import '../contracts/contracts_page.dart';
import '../payments/payments_page.dart';
import '../chat/chat_page.dart';
import '../approvals/approvals_page.dart';
import '../meetings/meetings_page.dart';
import '../subusers/subusers_page.dart';
import '../files/client_files_page.dart';
import '../signature/signature_tab.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  final _api = ApiClient();
  int _unreadNotifs = 0;

  Map<String, dynamic>? _client;
  Map<String, dynamic>? _workspace;
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadClientData();
    _loadNotifs();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadClientData() async {
    final cid = _api.userId;
    if (cid == null) return;
    try {
      final data = await _api.get('/clients/$cid');
      _client = data['client'] as Map<String, dynamic>?;
      _workspace = data['client']?['workspace'] as Map<String, dynamic>?;
      final signedAt = _client?['signed_at'] as String?;
      if (signedAt != null && signedAt.isNotEmpty) {
        _startRefresh();
      }
    } catch (e) {
      _error = 'فشل تحميل البيانات';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _startRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadClientData());
  }

  Future<void> _loadNotifs() async {
    try {
      final data = await _api.get('/notifications');
      _unreadNotifs = (data['unread_count'] as num? ?? 0).toInt();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تسجيل خروج')),
        ],
      ),
    );
    if (confirm == true) {
      _refreshTimer?.cancel();
      await _api.clearToken();
      if (!mounted) return;
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, size: 64, color: ShadColors.error),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: ShadColors.textPrimary, fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadClientData, child: const Text('إعادة المحاولة')),
            ]),
          ),
        ),
      );
    }

    final signedAt = _client?['signed_at'] as String?;
    final isSigned = signedAt != null && signedAt.isNotEmpty;

    if (!isSigned) {
      return _buildPreSignature();
    }

    if (_workspace == null) {
      return _buildPreWorkspace();
    }

    return _buildDashboard();
  }

  Widget _buildPreSignature() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: ShadColors.gold.withAlpha(25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.auto_fix_high, size: 36, color: ShadColors.gold),
            ),
            const SizedBox(height: 24),
            const Text('مرحباً بك في شاد آب',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'PlayfairDisplay')),
            const SizedBox(height: 12),
            Text('يرجى إضافة توقيعك الإلكتروني للبدء',
              style: TextStyle(fontSize: 14, color: ShadColors.textSecondary, fontFamily: 'NotoSansArabic')),
            const SizedBox(height: 8),
            Text('من فضلك قم بإضافة توقيعك الإلكتروني للبدء في استخدام المساحة الخاصة بك',
              style: TextStyle(fontSize: 12, color: ShadColors.textDisabled, fontFamily: 'NotoSansArabic'),
              textAlign: TextAlign.center),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await context.push('/signature');
                  _loadClientData();
                },
                icon: const Icon(Icons.draw, size: 20),
                label: const Text('التوقيع الآن'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ShadColors.crimson,
                  foregroundColor: ShadColors.textOnCrimson,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _logout,
              child: const Text('تسجيل الخروج', style: TextStyle(color: ShadColors.textSecondary)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildPreWorkspace() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: ShadColors.success.withAlpha(25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.check_circle, size: 36, color: ShadColors.success),
            ),
            const SizedBox(height: 24),
            const Text('تم تسجيل توقيعك بنجاح',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'PlayfairDisplay')),
            const SizedBox(height: 12),
            Text('بانتظار إنشاء مساحة العمل',
              style: TextStyle(fontSize: 14, color: ShadColors.textSecondary, fontFamily: 'NotoSansArabic')),
            const SizedBox(height: 8),
            Text('سيتم استلام العقد قريباً.',
              style: TextStyle(fontSize: 12, color: ShadColors.textDisabled, fontFamily: 'NotoSansArabic'),
              textAlign: TextAlign.center),
            const SizedBox(height: 32),
            const SizedBox(
              width: 40, height: 40,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: _logout,
              child: const Text('تسجيل الخروج', style: TextStyle(color: ShadColors.textSecondary)),
            ),
          ]),
        ),
      ),
    );
  }

  void _onStageTap(int stage) {
    final tabMap = {1: 0, 2: 0, 3: 0, 4: 1, 5: 1};
    final tab = tabMap[stage] ?? 0;
    setState(() => _selectedIndex = tab);
  }

  void _goToPayments() {
    setState(() => _selectedIndex = 1);
  }

  Widget _buildStageHeader() {
    final client = _client;
    final ws = _workspace;
    int s = 0;
    if (client != null && ws != null) {
      final contractsList = (ws['contracts'] as List?) ?? [];
      final paymentsList = (ws['payments'] as List?) ?? [];
      final wsStatus = ws['status'] as String? ?? '';
      if (wsStatus == 'active') { s = 6; }
      else {
        if (paymentsList.any((p) => p is Map && p['status'] == 'approved')) { s = 5; }
        else {
          if (contractsList.any((c) => c is Map && (c['status'] == 'company_approved' || c['status'] == 'completed'))) { s = 4; }
          else if (contractsList.any((c) => c is Map && c['status'] == 'client_approved')) { s = 3; }
          else if (contractsList.any((c) => c is Map && c['status'] == 'sent')) { s = 2; }
          else if (client['signed_at'] != null) { s = 1; }
        }
      }
    }
    return StagesStepper(currentStage: s, onStageTap: _onStageTap);
  }

  Widget _buildDashboard() {
    final pages = <Widget>[
      ContractsPage(onGoToPayments: _goToPayments),
      const PaymentsPage(),
      const ApprovalsPage(),
      const ChatPage(),
      const ClientFilesPage(),
      const MeetingsPage(),
      const SignatureTab(),
      const SubUsersPage(),
    ];

    final titles = ['العقود', 'المدفوعات', 'الموافقات', 'الشات', 'الملفات', 'الاجتماعات', 'التوقيع', 'المستخدمين'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        leading: const Padding(
          padding: EdgeInsets.only(left: 8),
          child: ShadLogo(size: 28, showText: false),
        ),
        actions: [
          Stack(children: [
            IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () => context.push('/notifications')),
            if (_unreadNotifs > 0)
              Positioned(
                right: 6, top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: ShadColors.crimson, shape: BoxShape.circle),
                  child: Text('$_unreadNotifs', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
          ]),
          IconButton(
            icon: const Icon(Icons.language, size: 20),
            onPressed: () => LocaleProvider().toggle(),
            tooltip: 'تغيير اللغة',
          ),
          IconButton(icon: const Icon(Icons.settings_outlined, size: 20), onPressed: () => context.push('/settings'), tooltip: 'الإعدادات'),
          IconButton(icon: const Icon(Icons.logout_rounded), onPressed: _logout, tooltip: 'تسجيل الخروج'),
        ],
      ),
      body: Column(
        children: [
          _buildStageHeader(),
          const Divider(height: 1),
          Expanded(child: pages[_selectedIndex]),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: ShadColors.cardBorder)),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (i) => setState(() => _selectedIndex = i),
          indicatorColor: Colors.transparent,
          destinations: [
            NavigationDestination(
              icon: _navIcon(Icons.description_outlined, 0),
              selectedIcon: _navIcon(Icons.description_rounded, 0, selected: true),
              label: 'العقود',
            ),
            NavigationDestination(
              icon: _navIcon(Icons.payments_outlined, 1),
              selectedIcon: _navIcon(Icons.payments_rounded, 1, selected: true),
              label: 'المدفوعات',
            ),
            NavigationDestination(
              icon: _navIcon(Icons.check_circle_outlined, 2),
              selectedIcon: _navIcon(Icons.check_circle_rounded, 2, selected: true),
              label: 'الموافقات',
            ),
            NavigationDestination(
              icon: _navIcon(Icons.chat_outlined, 3),
              selectedIcon: _navIcon(Icons.chat_rounded, 3, selected: true),
              label: 'الشات',
            ),
            NavigationDestination(
              icon: _navIcon(Icons.folder_outlined, 4),
              selectedIcon: _navIcon(Icons.folder_rounded, 4, selected: true),
              label: 'الملفات',
            ),
            NavigationDestination(
              icon: _navIcon(Icons.videocam_outlined, 5),
              selectedIcon: _navIcon(Icons.videocam_rounded, 5, selected: true),
              label: 'الاجتماعات',
            ),
            NavigationDestination(
              icon: _navIcon(Icons.edit_outlined, 6),
              selectedIcon: _navIcon(Icons.edit_rounded, 6, selected: true),
              label: 'التوقيع',
            ),
            NavigationDestination(
              icon: _navIcon(Icons.people_outlined, 7),
              selectedIcon: _navIcon(Icons.people_rounded, 7, selected: true),
              label: 'المستخدمين',
            ),
          ],
        ),
      ),
    );
  }

  Widget _navIcon(IconData icon, int index, {bool selected = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (selected)
          Container(
            height: 2,
            width: 24,
            margin: const EdgeInsets.only(bottom: 4),
            decoration: const BoxDecoration(
              color: ShadColors.gold,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(1)),
            ),
          ),
        Icon(icon, size: 22),
      ],
    );
  }
}



