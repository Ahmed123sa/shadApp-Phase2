import 'package:flutter/material.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/shad_logo.dart';
import 'chat_tab.dart';
import 'files_tab.dart';
import 'contracts_tab.dart';
import 'payments_tab.dart';
import 'approvals_tab.dart';
import 'meetings_tab.dart';
import 'calendar_tab.dart';
import '../widgets/contract_builder.dart';

class AmWorkspacePage extends StatefulWidget {
  final int initialTabIndex;
  const AmWorkspacePage({super.key, this.initialTabIndex = 0});

  @override
  State<AmWorkspacePage> createState() => _AmWorkspacePageState();
}

class _AmWorkspacePageState extends State<AmWorkspacePage> with SingleTickerProviderStateMixin {
  final _api = ApiClient();
  String? _wsStatus;
  String? _wsContactPerson;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this, initialIndex: widget.initialTabIndex.clamp(0, 6));
    _fetchWorkspace();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchWorkspace() async {
    if (_api.workspaceId == null) return;
    try {
      final data = await _api.get('/workspaces/${_api.workspaceIdSafe}');
      if (!mounted) return;
      setState(() {
        _wsStatus = (data['workspace'] as Map<String, dynamic>?)?['status'] as String?;
        _wsContactPerson = ((data['workspace'] as Map<String, dynamic>?)?['client'] as Map<String, dynamic>?)?['contact_person'] as String?;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ShadLogo(size: 24, showText: false),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ApiClient().userName ?? 'Workspace / مساحة العمل',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'PlayfairDisplay')),
                  if (_wsStatus != null || _wsContactPerson != null)
                    Text(
                      [_wsContactPerson, _wsStatus != null ? (_wsStatus == 'active' ? '🟢 نشط' : '🔴 غير نشط') : null]
                          .whereType<String>()
                          .join(' · '),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_api.role != 'super_admin')
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'إنشاء عقد سريع',
              onPressed: () => ContractBuilder.show(context),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: ShadColors.gold,
          indicatorWeight: 3,
          labelColor: ShadColors.textPrimary,
          unselectedLabelColor: ShadColors.textSecondary,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Archivo'),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          tabs: const [
            Tab(text: 'المحادثة'),
            Tab(text: 'الملفات'),
            Tab(text: 'العقود'),
            Tab(text: 'المدفوعات'),
            Tab(text: 'الموافقات'),
            Tab(text: 'الاجتماعات'),
            Tab(text: 'التقويم'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ChatTab(wsStatus: _wsStatus),
          FilesTab(),
          ContractsTab(),
          PaymentsTab(onWorkspaceUpdate: _fetchWorkspace),
          ApprovalsTab(),
          MeetingsTab(),
          CalendarTab(),
        ],
      ),
    );
  }
}
