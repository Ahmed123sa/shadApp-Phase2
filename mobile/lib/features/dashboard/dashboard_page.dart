import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/locale_provider.dart';
import '../../core/reverb_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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

class _DashboardPageState extends State<DashboardPage> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final _api = ApiClient();
  int _unreadNotifs = 0;
  int _unreadChat = 0;
  final ValueNotifier<int> _contractRefreshNotifier = ValueNotifier<int>(0);

  Map<String, dynamic>? _client;
  Map<String, dynamic>? _workspace;
  bool _loading = true;
  String? _error;
  int _lastStage = 0;
  bool _autoAdvancing = false;
  StreamSubscription? _fcmSubscription;

  int _computeStage() {
    final client = _client;
    final ws = _workspace;
    if (client == null || ws == null) return 0;
    final contractsList = safeList(ws['contracts']);
    final paymentsList = safeList(ws['payments']);
    final wsStatus = ws['status'] as String? ?? '';
    if (wsStatus == 'active') return 6;
    if (paymentsList.any((p) => p is Map && p['status'] == 'approved')) return 5;
    if (contractsList.any((c) => c is Map && c['status'] == 'completed')) return 4;
    if (contractsList.any((c) => c is Map && c['status'] == 'archived')) return 4;
    if (contractsList.any((c) => c is Map && c['status'] == 'company_approved')) return 4;
    if (contractsList.any((c) => c is Map && c['status'] == 'client_approved')) return 3;
    if (contractsList.any((c) => c is Map && c['status'] == 'edit_requested')) return 2;
    if (contractsList.any((c) => c is Map && c['status'] == 'sent')) return 2;
    if (client['signed_at'] != null) return 1;
    return 0;
  }

  int _stageToTab(int stage) {
    final map = {1: 0, 2: 0, 3: 0, 4: 3, 5: 3, 6: 3};
    return map[stage] ?? 0;
  }

  int _tabRequiredStage(int tab) {
    const stages = [1, 4, 4, 4, 6, 6, 0, 6];
    return stages[tab];
  }

  bool _isTabLocked(int tab) {
    return _computeStage() < _tabRequiredStage(tab);
  }

  @override
  void initState() {
    super.initState();
    _loadClientData();
    _loadNotifs();
    _setupRealtimeNotifications();
    WidgetsBinding.instance.addObserver(this);
    _contractRefreshNotifier.addListener(_onChildDataChanged);
  }

  void _onChildDataChanged() {
    if (mounted) _loadClientData();
  }

  void _setupRealtimeNotifications() {
    final cid = _api.userId;
    if (cid == null) return;
    final reverb = ReverbService();
    reverb.connectForClient(cid);
    reverb.onNotificationReceived = (payload) {
      _loadNotifs();
      _contractRefreshNotifier.value++;
      if (!mounted) return;
      final msg = (payload['data'] as Map?)?['message'] as String? ?? (payload['data'] as Map?)?['text'] as String? ?? 'إشعار جديد';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 13)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ));
    };
    reverb.onContractStatusChanged = () {
      _loadClientData();
      _contractRefreshNotifier.value++;
    };
    _fcmSubscription = FirebaseMessaging.onMessage.listen((msg) {
      final type = msg.data['type'] as String? ?? '';
      if (type == 'contract.company_approved' || type == 'contract.completed' || type == 'payment.approved') {
        _loadClientData();
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      _loadClientData();
      _loadNotifs();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadClientData();
      _loadNotifs();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _contractRefreshNotifier.removeListener(_onChildDataChanged);
    _fcmSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadClientData() async {
    final cid = _api.userId;
    if (cid == null) return;
    try {
      final data = await _api.get('/clients/$cid');
      _client = data['client'] as Map<String, dynamic>?;
      _workspace = data['client']?['workspace'] as Map<String, dynamic>?;
      if (_workspace != null) {
        final wsId = _workspace!['id'] as int?;
        if (wsId != null && wsId != _api.workspaceId) {
          await _api.setUserData(workspace: wsId);
        }
      }
      _checkAutoAdvance();
    } catch (e) {
      _error = 'فشل تحميل البيانات';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _checkAutoAdvance() {
    if (_autoAdvancing) return;
    final currentStage = _computeStage();
    // Redirect to a valid tab if current one is locked
    if (_isTabLocked(_selectedIndex)) {
      final targetTab = _stageToTab(currentStage);
      setState(() => _selectedIndex = targetTab);
    }
    // Auto-advance forward
    if (currentStage > _lastStage && currentStage > 0) {
      _autoAdvancing = true;
      final targetTab = _stageToTab(currentStage);
      if (targetTab != _selectedIndex) {
        setState(() => _selectedIndex = targetTab);
      }
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _autoAdvancing = false;
      });
    }
    _lastStage = currentStage;
  }

  Future<void> _loadNotifs() async {
    try {
      final data = await _api.get('/notifications');
      _unreadNotifs = (data['unread_count'] as num? ?? 0).toInt();
    } catch (_) {}
    try {
      final data = await _api.get('/workspaces/${_api.workspaceIdSafe}/chat');
      final messages = safeList(data['messages']);
      _unreadChat = messages.where((m) => m['sender_type'] != 'App\\Models\\Client' && m['read_at'] == null).length;
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

  void _goToPayments() {
    setState(() => _selectedIndex = 1);
  }

  Widget _buildStageHeader() {
    final client = _client;
    final ws = _workspace;
    String currentStatus = 'draft';
    if (client != null && ws != null) {
      final contractsList = safeList(ws['contracts']);
      final paymentsList = safeList(ws['payments']);
      final wsStatus = ws['status'] as String? ?? '';
      if (wsStatus == 'active') { currentStatus = 'completed'; }
      else if (contractsList.any((c) => c is Map && c['status'] == 'completed')) { currentStatus = 'completed'; }
      else if (paymentsList.any((p) => p is Map && p['status'] == 'approved')) { currentStatus = 'payment_approved'; }
      else if (contractsList.any((c) => c is Map && c['status'] == 'company_approved')) { currentStatus = 'payment_approved'; }
      else if (contractsList.any((c) => c is Map && c['status'] == 'client_approved')) { currentStatus = 'company_approved'; }
      else if (contractsList.any((c) => c is Map && c['status'] == 'edit_requested')) { currentStatus = 'edit_requested'; }
      else if (contractsList.any((c) => c is Map && c['status'] == 'sent')) { currentStatus = 'client_approved'; }
      else if (client['signed_at'] != null) { currentStatus = 'sent'; }
    }

    final steps = const [
      StageStep(status: 'signed', label: 'التوقيع', icon: Icons.edit),
      StageStep(status: 'sent', label: 'استلام العقد', icon: Icons.downloading),
      StageStep(status: 'edit_requested', label: 'طلب تعديل', icon: Icons.edit_note),
      StageStep(status: 'client_approved', label: 'موافقة العميل', icon: Icons.thumb_up),
      StageStep(status: 'company_approved', label: 'اعتماد الشركة', icon: Icons.verified),
      StageStep(status: 'payment_approved', label: 'الدفع', icon: Icons.payment),
      StageStep(status: 'completed', label: 'اكتمال', icon: Icons.check_circle),
    ];

    return StagesStepper(currentStatus: currentStatus, steps: steps);
  }

  Widget _buildDashboard() {
    final pages = <Widget>[
      ContractsPage(onGoToPayments: _goToPayments, refreshNotifier: _contractRefreshNotifier),
      const PaymentsPage(),
      const ApprovalsPage(),
      ChatPage(onGoToPayments: _goToPayments),
      const ClientFilesPage(),
      const MeetingsPage(),
      const SignatureTab(),
      const SubUsersPage(),
    ];

    final titles = ['العقود', 'المدفوعات', 'طلبات لاحقة', 'الشات', 'الملفات', 'الاجتماعات', 'التوقيع', 'فريق العمل'];

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
          onDestinationSelected: (i) {
            if (_isTabLocked(i)) {
              final reqStage = _tabRequiredStage(i);
              final stageLabels = ['', 'التوقيع', 'استلام العقد', 'موافقتك', 'اعتماد الشركة', 'إثبات الدفع', 'تفعيل المساحة'];
              final label = stageLabels.length > reqStage ? stageLabels[reqStage] : '';
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('هذا التبويب مقفول — يجب إكمال مرحلة "$label" أولاً'),
                duration: const Duration(seconds: 3),
              ));
              return;
            }
            setState(() => _selectedIndex = i);
          },
          indicatorColor: Colors.transparent,
          destinations: [
            NavigationDestination(
              icon: _navIcon(_isTabLocked(0) ? Icons.lock_outline : Icons.description_outlined, 0),
              selectedIcon: _navIcon(Icons.description_rounded, 0, selected: true),
              label: 'العقود',
            ),
            NavigationDestination(
              icon: _navIcon(_isTabLocked(1) ? Icons.lock_outline : Icons.payments_outlined, 1),
              selectedIcon: _navIcon(Icons.payments_rounded, 1, selected: true),
              label: 'المدفوعات',
            ),
            NavigationDestination(
              icon: _navIcon(_isTabLocked(2) ? Icons.lock_outline : Icons.check_circle_outlined, 2),
              selectedIcon: _navIcon(Icons.check_circle_rounded, 2, selected: true),
              label: 'طلبات لاحقة',
            ),
            NavigationDestination(
              icon: _navIcon(_isTabLocked(3) ? Icons.lock_outline : Icons.chat_outlined, 3, isChat: true),
              selectedIcon: _navIcon(Icons.chat_rounded, 3, selected: true, isChat: true),
              label: 'الشات',
            ),
            NavigationDestination(
              icon: _navIcon(_isTabLocked(4) ? Icons.lock_outline : Icons.folder_outlined, 4),
              selectedIcon: _navIcon(Icons.folder_rounded, 4, selected: true),
              label: 'الملفات',
            ),
            NavigationDestination(
              icon: _navIcon(_isTabLocked(5) ? Icons.lock_outline : Icons.videocam_outlined, 5),
              selectedIcon: _navIcon(Icons.videocam_rounded, 5, selected: true),
              label: 'الاجتماعات',
            ),
            NavigationDestination(
              icon: _navIcon(Icons.edit_outlined, 6),
              selectedIcon: _navIcon(Icons.edit_rounded, 6, selected: true),
              label: 'التوقيع',
            ),
            NavigationDestination(
              icon: _navIcon(_isTabLocked(7) ? Icons.lock_outline : Icons.people_outlined, 7),
              selectedIcon: _navIcon(Icons.people_rounded, 7, selected: true),
              label: 'فريق العمل',
            ),
          ],
        ),
      ),
    );
  }

  Widget _navIcon(IconData icon, int index, {bool selected = false, bool isChat = false}) {
    final isUnlocked = !_isTabLocked(index);
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
        Stack(children: [
          Icon(icon, size: 22,
            color: isChat && isUnlocked && _selectedIndex == 3
              ? ShadColors.gold
              : null),
          if (isChat && _unreadChat > 0 && isUnlocked)
            Positioned(
              right: -6, top: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: ShadColors.gold, shape: BoxShape.circle),
                child: Text('$_unreadChat', style: const TextStyle(fontSize: 7, color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
        ]),
      ],
    );
  }
}



