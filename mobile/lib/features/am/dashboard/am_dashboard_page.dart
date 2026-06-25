import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/locale_provider.dart';
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
  List<dynamic> _allClients = [];
  List<dynamic> _filteredClients = [];
  bool _loading = true;
  int _unreadNotifs = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_filter);
    _startRefresh();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.get('/clients');
      _allClients = data['clients'] as List<dynamic>? ?? [];
      _filter();
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

  void _startRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) { _load(); _loadNotifs(); });
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
        fetch: () => _fetchAllContracts('sent'),
      ),
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

  Future<List<Map<String, dynamic>>> _fetchAllContracts(String status) async {
    final results = <Map<String, dynamic>>[];
    try {
      final data = await _api.get('/clients');
      final clients = data['clients'] as List<dynamic>? ?? [];
      for (final client in clients) {
        final ws = client['workspace'] as Map<String, dynamic>?;
        if (ws == null) continue;
        final wsId = ws['id'];
        final contractsData = await _api.get('/workspaces/$wsId/contracts');
        final contracts = contractsData['contracts'] as List<dynamic>? ?? [];
        for (final c in contracts) {
          if (c['status'] == status) {
            results.add({
              'title': c['title'] ?? '',
              'value': c['value'] ?? 0,
              'company': client['company_name'] ?? '',
              'client': client,
            });
          }
        }
      }
    } catch (_) {}
    return results;
  }

  Future<List<Map<String, dynamic>>> _fetchAllApprovals() async {
    final results = <Map<String, dynamic>>[];
    try {
      final data = await _api.get('/clients');
      final clients = data['clients'] as List<dynamic>? ?? [];
      for (final client in clients) {
        final ws = client['workspace'] as Map<String, dynamic>?;
        if (ws == null) continue;
        final wsId = ws['id'];
        final approvalsData = await _api.get('/workspaces/$wsId/approvals');
        final approvals = approvalsData['approvals'] as List<dynamic>? ?? [];
        for (final a in approvals) {
          if (a['status'] == 'pending') {
            results.add({
              'title': a['title'] ?? '',
              'company': client['company_name'] ?? '',
              'client': client,
            });
          }
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
    _refreshTimer?.cancel();
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
              children: [
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

  Widget _buildFeaturedCards() {
    final loc2 = AppLocalizations.of(context)!;
    final isSA = _api.role == 'super_admin';
    return Column(children: [
      Row(children: [
        if (isSA)
          Expanded(child: _featuredCard(Icons.manage_accounts, 'إدارة المديرين', () => context.push('/am/managers'))),
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
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              InkWell(
                onTap: () async {
                  final changed = await context.push<bool>('/am/clients/${client['id']}');
                  if (changed == true) _load();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.edit, size: 14, color: ShadColors.gold),
                    const SizedBox(width: 4),
                    const Text('تفاصيل', style: TextStyle(fontSize: 11, color: ShadColors.gold, fontFamily: 'Archivo')),
                  ]),
                ),
              ),
              InkWell(
                onTap: () => _deleteClient(clientId, name),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.delete_outline, size: 14, color: ShadColors.error),
                    const SizedBox(width: 4),
                    const Text('حذف', style: TextStyle(fontSize: 11, color: ShadColors.error, fontFamily: 'Archivo')),
                  ]),
                ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(children: [
        const Icon(Icons.people_outline, size: 56, color: ShadColors.textDisabled),
        const SizedBox(height: 16),
        Text(loc2.noClients, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
        const SizedBox(height: 8),
        Text(loc2.noClientsSubtitle, style: TextStyle(fontSize: 14, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
        const SizedBox(height: 24),
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
                      );
                    },
                  ),
          ),
        ]),
      ),
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
