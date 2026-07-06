import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/locale_provider.dart';
import '../../../core/reverb_service.dart';
import '../../../core/widgets/shad_logo.dart';
import 'package:shadapp_client/generated/app_localizations.dart';

class AmDashboardPage extends StatefulWidget {
  const AmDashboardPage({super.key});

  @override
  State<AmDashboardPage> createState() => _AmDashboardPageState();
}

class _AmDashboardPageState extends State<AmDashboardPage> {
  final _api = ApiClient();
  final _searchController = TextEditingController();
  final _isSA = ApiClient().role == 'super_admin';
  List<dynamic> _allClients = [];
  List<dynamic> _filteredClients = [];
  List<dynamic> _allManagers = [];
  List<dynamic> _pendingPayments = [];
  bool _loading = true;
  int _unreadNotifs = 0;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_filter);
    _setupRealtimeNotifications();
    _pollTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _load();
      _loadNotifs();
    });
  }

  void _setupRealtimeNotifications() {
    final uid = _api.userId;
    if (uid == null) return;
    final reverb = ReverbService();
    reverb.connectForUser(uid);
    reverb.onNotificationReceived = (payload) {
      _loadNotifs();
      _load();
      if (!mounted) return;
      final msg = (payload['data'] as Map?)?['message'] as String? ?? 'إشعار جديد';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 13)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ));
    };
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      if (_isSA) {
        final data = await _api.get('/account-managers');
        _allManagers = data['managers'] as List<dynamic>? ?? [];
      } else {
        final data = await _api.get('/clients');
        _allClients = safeList(data['clients']);
        _filter();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _filter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredClients = query.isEmpty
          ? List.from(_allClients)
          : _allClients.where((c) {
              final name = (c['company_name'] as String? ?? '').toLowerCase();
              final person = (c['contact_person'] as String? ?? '').toLowerCase();
              return name.contains(query) || person.contains(query);
            }).toList();
    });
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
        title: Text(AppLocalizations.of(ctx)!.logout),
        content: Text(AppLocalizations.of(ctx)!.logoutConfirmation),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(ctx)!.cancel)),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppLocalizations.of(ctx)!.logout)),
        ],
      ),
    );
    if (confirm == true) {
      await _api.clearToken();
      if (!mounted) return;
      context.go('/login');
    }
  }

  Future<void> _deleteClient(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف العميل'),
        content: Text('حذف "$name" نهائياً؟ لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: ShadColors.error),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.delete('/clients/$id');
      _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل حذف العميل')));
    }
  }

  void _openClient(Map<String, dynamic> client) async {
    final ws = client['workspace'] as Map<String, dynamic>?;
    if (ws == null) {
      try {
        final created = await _api.post('/workspaces', {'client_id': client['id']});
        final newWs = created['workspace'] as Map<String, dynamic>;
        await _api.setUserData(
          id: client['id'],
          name: client['company_name'],
          workspace: newWs['id'],
        );
        if (!mounted) return;
        context.push('/am/workspace/${newWs['id']}');
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل إنشاء مساحة العمل')));
      }
      return;
    }
    await _api.setUserData(
      id: client['id'],
      name: client['company_name'],
      workspace: ws['id'],
    );
    if (!mounted) return;
    context.push('/am/workspace/${ws['id']}');
  }

  void _showPendingContracts() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PendingListSheet(
        title: AppLocalizations.of(context)!.pendingApprovalContracts,
        fetch: () => _fetchAllContracts(['sent', 'client_approved']),
      ),
    );
  }

  Future<void> _showPendingPayments() async {
    try {
      final data = await _api.get('/payments/pending');
      _pendingPayments = data['payments'] as List<dynamic>? ?? [];
    } catch (_) {
      _pendingPayments = [];
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PendingPaymentsSheet(payments: _pendingPayments),
    );
  }

  void _showPendingApprovals() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PendingListSheet(
        title: AppLocalizations.of(context)!.pendingApprovalRequests,
        fetch: () => _fetchAllApprovals(),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchAllContracts(List<String> statuses) async {
    final results = <Map<String, dynamic>>[];
    try {
      final data = await _api.get('/clients');
      final clients = safeList(data['clients']);
      for (final client in clients) {
        final ws = client['workspace'] as Map<String, dynamic>?;
        if (ws == null) continue;
        try {
          final contractsData = await _api.get('/workspaces/${ws['id']}/contracts');
          final contracts = safeList(contractsData['contracts']);
          for (final c in contracts) {
            if (statuses.contains(c['status'])) {
              results.add({
                'title': c['title'] ?? '',
                'value': c['value'] ?? 0,
                'company': client['company_name'] ?? '',
                'client': client,
              });
            }
          }
        } catch (_) {
          continue;
        }
      }
    } catch (_) {}
    return results;
  }

  Future<List<Map<String, dynamic>>> _fetchAllApprovals() async {
    final results = <Map<String, dynamic>>[];
    try {
      final data = await _api.get('/clients');
      final clients = safeList(data['clients']);
      for (final client in clients) {
        final ws = client['workspace'] as Map<String, dynamic>?;
        if (ws == null) continue;
        try {
          final approvalsData = await _api.get('/workspaces/${ws['id']}/approvals');
          final approvals = safeList(approvalsData['approvals']);
          for (final a in approvals) {
            if (a['status'] == 'pending') {
              results.add({
                'title': a['title'] ?? '',
                'company': client['company_name'] ?? '',
                'client': client,
              });
            }
          }
        } catch (_) {
          continue;
        }
      }
    } catch (_) {}
    return results;
  }

  void _createMeeting() {
    final clients = _allClients.where((c) {
      final ws = c['workspace'] as Map<String, dynamic>?;
      return ws != null;
    }).toList();
    if (clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد عملاء متاحين')));
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _CreateMeetingSheet(clients: clients, onCreated: () {
        Navigator.pop(ctx);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم إنشاء الاجتماع')));
      }),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('d.Contracts', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, fontFamily: 'PlayfairDisplay')),
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
          IconButton(icon: const Icon(Icons.language, size: 20), onPressed: () => LocaleProvider().toggle(), tooltip: 'تغيير اللغة'),
          IconButton(icon: const Icon(Icons.logout_rounded), onPressed: _logout, tooltip: loc.logout),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: _isSA ? [
                _buildQuickStats(),
                const SizedBox(height: 16),
                _buildFeaturedCards(),
                const SizedBox(height: 16),
                Text('Account Managers / مدراء الحسابات', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
                const SizedBox(height: 8),
                if (_allManagers.isNotEmpty)
                  ..._allManagers.map((m) => _managerCard(m)),
                if (_allManagers.isEmpty)
                  _buildEmptyState(),
              ] : [
                _buildSearchBar(),
                const SizedBox(height: 16),
                _buildQuickStats(),
                const SizedBox(height: 16),
                _buildFeaturedCards(),
                const SizedBox(height: 16),
                if (_filteredClients.isEmpty && _searchController.text.isNotEmpty)
                  _buildNoResults()
                else if (_allClients.isEmpty)
                  _buildEmptyState()
                else
                  Text('All Clients / كل العملاء', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
                const SizedBox(height: 8),
                if (_filteredClients.isNotEmpty)
                  ..._filteredClients.map((c) => _clientCard(c)),
              ],
            ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final loc2 = AppLocalizations.of(context)!;
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: loc2.searchClients,
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () { _searchController.clear(); _filter(); },
              )
            : null,
        filled: true,
        fillColor: ShadColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildQuickStats() {
    final loc2 = AppLocalizations.of(context)!;
    final isSA = _api.role == 'super_admin';
    if (isSA) {
      final totalManagers = _allManagers.length;
      final totalClients = _allManagers.fold<int>(0, (sum, m) => sum + ((m['managed_clients_count'] as int? ?? 0)));
      final stats = [
        ('إجمالي المديرين', '$totalManagers', Icons.admin_panel_settings, ShadColors.sent),
        ('إجمالي العملاء', '$totalClients', Icons.people, ShadColors.companyApproved),
      ];
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: stats.map((s) {
          final (label, value, icon, color) = s;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: _statCard(label, value, icon, color),
          );
        }).toList()),
      );
    }
    final totalClients = _allClients.length;
    final activeWorkspaces = _allClients.where((c) {
      final ws = c['workspace'] as Map<String, dynamic>?;
      return ws?['status'] == 'active';
    }).length;
    final pendingPayments = _allClients.where((c) => c['payment_status'] == 'pending').length;
    final signed = _allClients.where((c) => c['signed_at'] != null).length;
    final stats = [
      (loc2.totalClients, '$totalClients', Icons.people, ShadColors.sent),
      (loc2.activeWorkspaces, '$activeWorkspaces', Icons.workspaces, ShadColors.success),
      (loc2.pendingPayments, '$pendingPayments', Icons.payments, ShadColors.warning),
      (loc2.signed, '$signed', Icons.download_done, ShadColors.companyApproved),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: stats.map((s) {
        final (label, value, icon, color) = s;
        return Padding(
          padding: const EdgeInsets.only(left: 8),
          child: _statCard(label, value, icon, color),
        );
      }).toList()),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ShadColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ShadColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: color),
            const Spacer(),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color, fontFamily: 'PlayfairDisplay')),
          ]),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
        ],
      ),
    );
  }

  Future<void> _showAllContracts() async {
    try {
      final data = await _api.get('/all-contracts');
      final contracts = data['contracts'] as List<dynamic>? ?? [];
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => _AllContractsSheet(contracts: contracts),
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل تحميل العقود')));
    }
  }

  Future<void> _showAllMeetings() async {
    try {
      final data = await _api.get('/all-meetings');
      final meetings = data['meetings'] as List<dynamic>? ?? [];
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => _AllMeetingsSheet(meetings: meetings),
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل تحميل الاجتماعات')));
    }
  }

  Widget _buildFeaturedCards() {
    final loc2 = AppLocalizations.of(context)!;
    final isSA = _api.role == 'super_admin';
    return Column(children: [
      if (isSA)
        SizedBox(
          width: double.infinity,
          child: _featuredCard(Icons.payments, 'مدفوعات معلقة', _showPendingPayments),
        ),
      if (isSA)
        const SizedBox(height: 8),
      if (isSA)
        SizedBox(
          width: double.infinity,
          child: _featuredCard(Icons.description, 'كل العقود', _showAllContracts),
        ),
      if (isSA)
        const SizedBox(height: 8),
      if (isSA)
        SizedBox(
          width: double.infinity,
          child: _featuredCard(Icons.videocam, 'كل الاجتماعات', _showAllMeetings),
        ),
      if (isSA)
        const SizedBox(height: 8),
      Row(children: [
        if (isSA)
          Expanded(child: _featuredCard(Icons.manage_accounts, 'إدارة المديرين', () => context.push('/am/managers'))),
        if (!isSA)
          Expanded(child: _featuredCard(Icons.person_add, loc2.createNewClient, () async { await context.push('/am/clients/create'); _load(); })),
        const SizedBox(width: 8),
        Expanded(child: _featuredCard(Icons.pending_actions, loc2.pendingApprovalContracts, _showPendingContracts)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _featuredCard(Icons.notifications, loc2.pendingApprovalRequests, _showPendingApprovals)),
        const SizedBox(width: 8),
        Expanded(child: _featuredCard(Icons.bar_chart, loc2.reports, () => context.push('/am/reports'))),
      ]),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: _featuredCard(Icons.history, 'سجل النشاطات', () => context.push('/am/audit-logs')),
      ),
      const SizedBox(height: 8),
      if (!isSA)
        SizedBox(
          width: double.infinity,
          child: _featuredCard(Icons.add_circle, loc2.createMeeting, _createMeeting),
        ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: _featuredCard(Icons.settings, 'الإعدادات', () => context.push('/am/settings')),
      ),
    ]);
  }

  Widget _featuredCard(IconData icon, String label, VoidCallback? onTap) {
    return Container(
      decoration: BoxDecoration(
        color: ShadColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ShadColors.cardBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(children: [
            Icon(icon, size: 20, color: ShadColors.gold),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: ShadColors.textPrimary, fontFamily: 'Archivo'), overflow: TextOverflow.ellipsis)),
            const Icon(Icons.chevron_left, size: 18, color: ShadColors.textDisabled),
          ]),
        ),
      ),
    );
  }

  void _showManagerClients(Map<String, dynamic> manager) async {
    final managerId = manager['id'] as int;
    try {
      final data = await _api.get('/account-managers/$managerId');
      final clients = data['clients'] as List<dynamic>? ?? [];
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => _ManagerClientsSheet(
          managerName: manager['name'] as String? ?? '',
          clients: clients,
          onClientTap: (client) {
            Navigator.pop(ctx);
            _openClient(client);
          },
        ),
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل تحميل العملاء')));
    }
  }

  Widget _managerCard(Map<String, dynamic> manager) {
    final name = manager['name'] as String? ?? '';
    final email = manager['email'] as String? ?? '';
    final clientCount = manager['managed_clients_count'] as int? ?? 0;
    final avatarUrl = manager['avatar_url'] as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ShadColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ShadColors.cardBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showManagerClients(manager),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: ShadColors.cardBorder,
              backgroundImage: avatarUrl != null ? NetworkImage(_api.resolveFileUrl(avatarUrl)) : null,
              child: avatarUrl == null ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 18, color: ShadColors.textSecondary)) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
                const SizedBox(height: 2),
                Text(email, style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: ShadColors.sent.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$clientCount', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ShadColors.sent, fontFamily: 'PlayfairDisplay')),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _clientCard(Map<String, dynamic> client) {
    final ws = client['workspace'] as Map<String, dynamic>?;
    final wsStatus = ws?['status'] as String? ?? 'inactive';
    final wsActive = wsStatus == 'active';
    final name = client['company_name'] as String? ?? '';
    final person = client['contact_person'] as String? ?? '';
    final clientId = client['id'] as int;
    final paymentStatus = client['payment_status'] as String?;
    final signedAt = client['signed_at'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ShadColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ShadColors.cardBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openClient(client),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(children: [
            Row(children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: ShadColors.black,
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(color: ShadColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Archivo')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
                  const SizedBox(height: 2),
                  Text(person, style: TextStyle(fontSize: 11, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (wsActive ? ShadColors.success : ShadColors.textDisabled).withAlpha(25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  wsActive ? 'Active / نشط' : 'Inactive / غير نشط',
                  style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.3,
                    color: wsActive ? ShadColors.success : ShadColors.textDisabled,
                    fontFamily: 'Archivo',
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _statusChip(signedAt != null ? 'متعاقد' : 'غير متعاقد', signedAt != null ? ShadColors.success : ShadColors.textDisabled),
                _statusChip(
                  paymentStatus == 'approved' ? 'مدفوع' : paymentStatus == 'pending' ? 'معلق' : '—',
                  paymentStatus == 'approved' ? ShadColors.success : paymentStatus == 'pending' ? ShadColors.warning : ShadColors.textDisabled,
                ),
                _statusChip(wsActive ? '✅ تم' : '⏳ لم يتم', wsActive ? ShadColors.success : ShadColors.textDisabled),
              ],
            ),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 22, color: ShadColors.textSecondary),
                onPressed: () async {
                  final changed = await context.push<bool>('/am/clients/${client['id']}');
                  if (changed == true) _load();
                },
                tooltip: 'تفاصيل',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: ShadColors.error),
                onPressed: () => _deleteClient(clientId, name),
                tooltip: 'حذف',
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500, fontFamily: 'Archivo')),
    );
  }

  Widget _buildEmptyState() {
    final loc2 = AppLocalizations.of(context)!;
    final isSA = _api.role == 'super_admin';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(children: [
        const Icon(Icons.people_outline, size: 56, color: ShadColors.textDisabled),
        const SizedBox(height: 16),
        Text(loc2.noClients, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
        const SizedBox(height: 8),
        Text(loc2.noClientsSubtitle, style: TextStyle(fontSize: 14, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
        const SizedBox(height: 24),
        if (!isSA)
          ElevatedButton.icon(
            onPressed: () async { final created = await context.push<bool>('/am/clients/create'); if (created == true) _load(); },
            icon: const Icon(Icons.person_add, size: 18),
            label: Text(loc2.createClient),
          ),
      ]),
    );
  }

  Widget _buildNoResults() {
    final loc2 = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(children: [
        const Icon(Icons.search_off, size: 56, color: ShadColors.textDisabled),
        const SizedBox(height: 16),
        Text(loc2.noResults, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
        const SizedBox(height: 8),
        Text(loc2.noClientWithName, style: TextStyle(fontSize: 14, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
      ]),
    );
  }
}

class _PendingListSheet extends StatefulWidget {
  final String title;
  final Future<List<Map<String, dynamic>>> Function() fetch;
  const _PendingListSheet({required this.title, required this.fetch});

  @override
  State<_PendingListSheet> createState() => _PendingListSheetState();
}

class _PendingListSheetState extends State<_PendingListSheet> {
  List<Map<String, dynamic>>? _items;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await widget.fetch();
    if (mounted) setState(() { _items = items; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.8,
      minChildSize: 0.3,
      expand: false,
      builder: (_, scrollController) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ]),
          const Divider(),
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items == null || _items!.isEmpty
                ? const Center(child: Text('لا توجد عناصر', style: TextStyle(color: ShadColors.textSecondary)))
                : ListView.separated(
                    controller: scrollController,
                    itemCount: _items!.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final item = _items![i];
                      return ListTile(
                        leading: const Icon(Icons.circle, size: 8, color: ShadColors.warning),
                        title: Text(item['title'] ?? '', style: const TextStyle(fontSize: 14, color: ShadColors.textPrimary)),
                        subtitle: Text(item['company'] ?? '', style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
                        onTap: () {
                          final client = item['client'] as Map<String, dynamic>?;
                          final clientId = client?['id'];
                          if (clientId != null) {
                            Navigator.pop(context);
                            context.push('/am/clients/$clientId');
                          }
                        },
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

class _ManagerClientsSheet extends StatelessWidget {
  final String managerName;
  final List<dynamic> clients;
  final void Function(Map<String, dynamic> client) onClientTap;
  const _ManagerClientsSheet({required this.managerName, required this.clients, required this.onClientTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('عملاء $managerName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
          const Spacer(),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ]),
        const Divider(),
        if (clients.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('لا يوجد عملاء', style: TextStyle(color: ShadColors.textSecondary))),
          )
        else
          Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: clients.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final c = clients[i];
                final ws = c['workspace'] as Map<String, dynamic>?;
                return ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: ShadColors.cardBorder,
                    child: Text((c['company_name'] as String? ?? '')[0].toUpperCase(), style: const TextStyle(color: ShadColors.textSecondary)),
                  ),
                  title: Text(c['company_name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: Text(c['contact_person'] ?? '', style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: ws?['status'] == 'active' ? ShadColors.success.withAlpha(25) : ShadColors.cardBorder,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(ws?['status'] == 'active' ? 'نشط' : 'غير مفعل', style: TextStyle(fontSize: 10, color: ws?['status'] == 'active' ? ShadColors.success : ShadColors.textSecondary)),
                  ),
                  onTap: () => onClientTap(c),
                );
              },
            ),
          ),
      ]),
    );
  }
}

class _PendingPaymentsSheet extends StatelessWidget {
  final List<dynamic> payments;
  const _PendingPaymentsSheet({required this.payments});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('مدفوعات معلقة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
          const Spacer(),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ]),
        const Divider(),
        if (payments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('لا توجد مدفوعات معلقة', style: TextStyle(color: ShadColors.textSecondary))),
          )
        else
          Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: payments.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final p = payments[i];
                final client = p['workspace']?['client'] as Map<String, dynamic>?;
                final amount = (p['amount'] as num?)?.toDouble() ?? 0;
                return ListTile(
                  leading: const Icon(Icons.payments, size: 24, color: ShadColors.warning),
                  title: Text(client?['company_name'] as String? ?? 'عميل', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: Text('${p['currency'] ?? 'SAR'} ${amount.toStringAsFixed(2)} • ${p['method_type'] ?? ''}', style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
                  trailing: Text(p['created_at'] != null ? _formatDate(p['created_at']) : '', style: const TextStyle(fontSize: 11, color: ShadColors.textSecondary)),
                );
              },
            ),
          ),
      ]),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.year}/${dt.month}/${dt.day}';
    } catch (_) {
      return '';
    }
  }
}

class _AllContractsSheet extends StatelessWidget {
  final List<dynamic> contracts;
  const _AllContractsSheet({required this.contracts});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('كل العقود', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
          const Spacer(),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ]),
        const Divider(),
        if (contracts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('لا توجد عقود', style: TextStyle(color: ShadColors.textSecondary))),
          )
        else
          Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: contracts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final c = contracts[i];
                final client = c['workspace']?['client'] as Map<String, dynamic>?;
                final status = c['status'] as String? ?? '';
                final statusColor = status == 'completed' ? ShadColors.success : status == 'sent' || status == 'client_approved' ? ShadColors.warning : ShadColors.textSecondary;
                final statusLabel = status == 'draft' ? 'مسودة' : status == 'sent' ? 'مرسل' : status == 'client_approved' ? 'موافقة العميل' : status == 'company_approved' ? 'اعتماد الشركة' : status == 'completed' ? 'مكتمل' : status;
                return ListTile(
                  leading: const Icon(Icons.description, size: 24, color: ShadColors.gold),
                  title: Text(c['title'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: Text(client?['company_name'] as String? ?? '', style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: statusColor.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                    child: Text(statusLabel, style: TextStyle(fontSize: 10, color: statusColor)),
                  ),
                );
              },
            ),
          ),
      ]),
    );
  }
}

class _AllMeetingsSheet extends StatelessWidget {
  final List<dynamic> meetings;
  const _AllMeetingsSheet({required this.meetings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('كل الاجتماعات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
          const Spacer(),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ]),
        const Divider(),
        if (meetings.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('لا توجد اجتماعات', style: TextStyle(color: ShadColors.textSecondary))),
          )
        else
          Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: meetings.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final m = meetings[i];
                final client = m['workspace']?['client'] as Map<String, dynamic>?;
                final status = m['status'] as String? ?? '';
                final statusColor = status == 'completed' ? ShadColors.success : status == 'scheduled' ? ShadColors.sent : ShadColors.textSecondary;
                final statusLabel = status == 'scheduled' ? 'مجدول' : status == 'completed' ? 'مكتمل' : status == 'cancelled' ? 'ملغي' : status;
                String? dateStr;
                try {
                  final dt = DateTime.parse(m['scheduled_at'] ?? '');
                  dateStr = '${dt.year}/${dt.month}/${dt.day}';
                } catch (_) {}
                return ListTile(
                  leading: const Icon(Icons.videocam, size: 24, color: ShadColors.gold),
                  title: Text(m['title'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: Text('${client?['company_name'] ?? ''} • ${dateStr ?? ''}', style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: statusColor.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                    child: Text(statusLabel, style: TextStyle(fontSize: 10, color: statusColor)),
                  ),
                );
              },
            ),
          ),
      ]),
    );
  }
}

class _CreateMeetingSheet extends StatefulWidget {
  final List<dynamic> clients;
  final VoidCallback onCreated;
  const _CreateMeetingSheet({required this.clients, required this.onCreated});

  @override
  State<_CreateMeetingSheet> createState() => _CreateMeetingSheetState();
}

class _CreateMeetingSheetState extends State<_CreateMeetingSheet> {
  final _api = ApiClient();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  int? _duration;
  dynamic _selectedClient;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ws = _selectedClient?['workspace'] as Map<String, dynamic>?;
    if (_titleController.text.trim().isEmpty || ws == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال عنوان الاجتماع واختيار العميل')));
      return;
    }
    setState(() => _saving = true);
    final dt = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime.hour, _selectedTime.minute);
    try {
      await _api.post('/workspaces/${ws['id']}/meetings', {
        'title': _titleController.text.trim(),
        'scheduled_at': dt.toIso8601String(),
        'duration_minutes': _duration ?? 30,
        'notes': _notesController.text.trim(),
      });
      widget.onCreated();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل إنشاء الاجتماع')));
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('إنشاء اجتماع', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
          const Spacer(),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ]),
        const Divider(),
        DropdownButtonFormField(
          decoration: const InputDecoration(labelText: 'العميل *'),
          items: widget.clients.map((c) => DropdownMenuItem(
            value: c,
            child: Text(c['company_name'] ?? ''),
          )).toList(),
          onChanged: (v) => setState(() => _selectedClient = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(labelText: 'عنوان الاجتماع *', hintText: 'مثال: اجتماع المتابعة الأسبوعي'),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: InkWell(
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (d != null) setState(() => _selectedDate = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'التاريخ'),
                child: Text('${_selectedDate.year}/${_selectedDate.month}/${_selectedDate.day}'),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: _selectedTime);
                if (t != null) setState(() => _selectedTime = t);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'الوقت'),
                child: Text('${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}'),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          decoration: const InputDecoration(labelText: 'المدة (دقائق)'),
          initialValue: _duration,
          items: [15, 30, 45, 60, 90, 120].map((d) => DropdownMenuItem(value: d, child: Text('$d دقيقة'))).toList(),
          onChanged: (v) => setState(() => _duration = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          decoration: const InputDecoration(labelText: 'ملاحظات'),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : const Text('إنشاء الاجتماع'),
          ),
        ),
      ]),
    );
  }
}
