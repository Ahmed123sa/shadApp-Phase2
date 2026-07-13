import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/locale_provider.dart';
import '../../core/reverb_service.dart';
import '../../core/widgets/shad_logo.dart';
import '../contracts/contracts_page.dart';
import '../payments/payments_page.dart';
import '../chat/chat_page.dart';
import '../approvals/approvals_page.dart';
import '../files/client_files_page.dart';
import '../meetings/meetings_page.dart';
import '../subusers/subusers_page.dart';
import '../signature/signature_tab.dart';

class ClientDashboardScreen extends StatefulWidget {
  const ClientDashboardScreen({super.key});

  @override
  State<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends State<ClientDashboardScreen> with WidgetsBindingObserver {
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

  int _tabRequiredStage(int tab) {
    const stages = [1, 4, 4, 4, 6];
    return stages[tab];
  }

  bool _isTabLocked(int tab) {
    return _computeStage() < _tabRequiredStage(tab);
  }

  int _stageToTab(int stage) {
    final map = {1: 0, 2: 0, 3: 0, 4: 3, 5: 3, 6: 3};
    return map[stage] ?? 0;
  }

  void _goToPayments() {
    setState(() => _selectedIndex = 1);
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
    FirebaseMessaging.onMessageOpenedApp.listen((_) {
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
    if (_isTabLocked(_selectedIndex)) {
      final targetTab = _stageToTab(currentStage);
      setState(() => _selectedIndex = targetTab);
    }
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

    return _buildDashboard();
  }

  Widget _buildDashboard() {
    final pages = <Widget>[
      ContractsPage(onGoToPayments: _goToPayments, refreshNotifier: _contractRefreshNotifier),
      const PaymentsPage(),
      ChatPage(onGoToPayments: _goToPayments),
      const ApprovalsPage(),
      const ClientFilesPage(),
    ];

    final titles = ['العقود', 'الدفعة', 'الشات', 'طلبات', 'ملفات', 'الاجتماعات', 'التوقيع', 'فريق العمل'];

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex < titles.length ? titles[_selectedIndex] : '', style: const TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 20, fontWeight: FontWeight.w700, color: ShadColors.gold)),
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'المزيد',
            onSelected: (value) {
              setState(() {
                if (value == 'meetings') _selectedIndex = 5;
                if (value == 'signature') _selectedIndex = 6;
                if (value == 'subusers') _selectedIndex = 7;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'meetings', child: ListTile(leading: Icon(Icons.videocam_outlined), title: Text('الاجتماعات'), dense: true)),
              const PopupMenuItem(value: 'signature', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('التوقيع'), dense: true)),
              const PopupMenuItem(value: 'subusers', child: ListTile(leading: Icon(Icons.people_outlined), title: Text('فريق العمل'), dense: true)),
            ],
          ),
          IconButton(icon: const Icon(Icons.logout_rounded), onPressed: _logout, tooltip: 'تسجيل الخروج'),
        ],
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex >= 5 ? _selectedIndex : _selectedIndex,
            children: [
              ...pages,
              const MeetingsPage(),
              const SignatureTab(),
              const SubUsersPage(),
            ],
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: ShadColors.cardBorder)),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            navigationBarTheme: NavigationBarThemeData(
              indicatorColor: ShadColors.crimson.withAlpha(46),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ShadColors.gold);
                }
                return TextStyle(fontSize: 11, color: ShadColors.textSecondary);
              }),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return IconThemeData(size: 22, color: ShadColors.gold);
                }
                return IconThemeData(size: 22, color: ShadColors.textSecondary);
              }),
            ),
          ),
          child: NavigationBar(
          selectedIndex: _selectedIndex >= 5 ? 0 : _selectedIndex,
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
              label: 'الدفعة',
            ),
            NavigationDestination(
              icon: _navIcon(_isTabLocked(2) ? Icons.lock_outline : Icons.chat_outlined, 2, isChat: true),
              selectedIcon: _navIcon(Icons.chat_rounded, 2, selected: true, isChat: true),
              label: 'الشات',
            ),
            NavigationDestination(
              icon: _navIcon(_isTabLocked(3) ? Icons.lock_outline : Icons.check_circle_outlined, 3),
              selectedIcon: _navIcon(Icons.check_circle_rounded, 3, selected: true),
              label: 'طلبات',
            ),
            NavigationDestination(
              icon: _navIcon(_isTabLocked(4) ? Icons.lock_outline : Icons.folder_outlined, 4),
              selectedIcon: _navIcon(Icons.folder_rounded, 4, selected: true),
              label: 'ملفات',
            ),
          ],
        ),
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
            color: isChat && isUnlocked && _selectedIndex == 2
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

List safeList(dynamic value) {
  if (value is List) return value;
  if (value is String) return [];
  return [];
}
