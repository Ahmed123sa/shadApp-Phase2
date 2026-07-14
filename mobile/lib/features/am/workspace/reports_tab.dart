import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/empty_state.dart';

class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  final _api = ApiClient();
  Map<String, dynamic>? _stats;
  List<dynamic> _logs = [];
  bool _loading = true;

  double _toDouble(dynamic value) => num.tryParse(value?.toString() ?? '')?.toDouble() ?? 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final reportsFuture = _api.get('/reports').catchError((e) {
        return <String, dynamic>{'error': true, 'message': e.toString()};
      });
      final logsFuture = _api.get('/audit-logs').catchError((e) {
        return <String, dynamic>{'logs': []};
      });

      final results = await Future.wait([reportsFuture, logsFuture]);
      final reportsResult = results[0];
      final logsResult = results[1];

      if (reportsResult['error'] == true) {
        _error = reportsResult['message']?.toString() ?? 'خطأ في تحميل التقارير';
      } else {
        _stats = reportsResult;
      }
      _logs = safeList(logsResult['logs']);
    } catch (e) {
      if (mounted) _error = AppLocalizations.of(context)!.errorOccurred;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: ShadColors.error, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: ShadTypography.cardBody.copyWith(color: ShadColors.error)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('إعادة المحاولة')),
          ],
        ),
      );
    }

    final loc = AppLocalizations.of(context)!;
    final contractsByStatus = _stats?['contracts_by_status'] as Map<String, dynamic>? ?? {};
    final paymentsByMonth = _stats?['payments_by_month'] as Map<String, dynamic>? ?? {};
    final approvalStats = _stats?['approval_stats'] as Map<String, dynamic>? ?? {};

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(loc.reportsStatistics, style: ShadTypography.sectionHeader),
          const SizedBox(height: 16),
          _summaryRow(),
          const SizedBox(height: 24),
          if (contractsByStatus.isNotEmpty) ...[
            _sectionHeader(loc.contractsByStatus, Icons.bar_chart),
            const SizedBox(height: 8),
            SizedBox(height: 200, child: _contractsBarChart(contractsByStatus)),
            const SizedBox(height: 24),
          ],
          if (paymentsByMonth.isNotEmpty) ...[
            _sectionHeader(loc.paymentsByMonth, Icons.show_chart),
            const SizedBox(height: 8),
            SizedBox(height: 200, child: _paymentsLineChart(paymentsByMonth)),
            const SizedBox(height: 24),
          ],
          if (approvalStats.isNotEmpty) ...[
            _sectionHeader(loc.approvalStats, Icons.pie_chart),
            const SizedBox(height: 8),
            SizedBox(height: 200, child: _approvalPieChart(approvalStats)),
            const SizedBox(height: 24),
          ],
          _sectionHeader(loc.auditLogs, Icons.history),
          const SizedBox(height: 8),
          if (_logs.isEmpty)
            EmptyState(icon: Icons.history, title: loc.noAuditLogs)
          else
            ..._logs.map((log) => _auditLogTile(log)),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 18, color: ShadColors.gold),
      const SizedBox(width: 8),
      Text(title, style: ShadTypography.sectionHeader.copyWith(color: ShadColors.gold)),
    ]);
  }

  Widget _summaryRow() {
    final loc = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _summaryCard(loc.totalClients_, '${_stats?['total_clients'] ?? 0}', ShadColors.sent),
        _summaryCard(loc.activeWorkspaces, '${_stats?['active_workspaces'] ?? 0}', ShadColors.success),
        _summaryCard(loc.pendingPayments, '${_stats?['pending_payments'] ?? 0}', ShadColors.warning),
        _summaryCard(loc.pendingApprovalRequests, '${_stats?['pending_approvals'] ?? 0}', ShadColors.error),
        _summaryCard(loc.recentLogins, '${_stats?['recent_logins'] ?? 0}', ShadColors.companyApproved),
      ]),
    );
  }

  Widget _summaryCard(String label, String value, Color color) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ShadColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ShadColors.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: ShadTypography.largeTitle.copyWith(color: color, fontSize: 28)),
        const SizedBox(height: 4),
        Text(label, style: ShadTypography.caption.copyWith(color: ShadColors.textSecondary)),
      ]),
    );
  }

  Widget _contractsBarChart(Map<String, dynamic> data) {
    final statusOrder = ['draft', 'sent', 'client_approved', 'company_approved', 'completed', 'archived', 'client_rejected', 'edit_requested'];
    final entries = statusOrder.where((s) => data.containsKey(s)).map((s) => MapEntry(s, _toDouble(data[s]))).toList();
    if (entries.isEmpty) return _emptyChart(loc: AppLocalizations.of(context)!);
    final maxY = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxY * 1.3,
      barTouchData: BarTouchData(enabled: true, touchTooltipData: BarTouchTooltipData(
        getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem('${entries[groupIndex].value.toInt()}', const TextStyle(color: Colors.white, fontSize: 12)),
      )),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, getTitlesWidget: (v, _) {
            final idx = v.toInt();
            if (idx < 0 || idx >= entries.length) return const SizedBox();
            return Padding(padding: const EdgeInsets.only(top: 4), child: Text(_statusShortLabel(entries[idx].key), style: const TextStyle(color: ShadColors.textSecondary, fontSize: 9)));
          }, reservedSize: 28,
        )),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(color: ShadColors.textDisabled, fontSize: 10)))),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY > 0 ? maxY / 4 : 1),
      barGroups: entries.asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [
        BarChartRodData(toY: e.value.value, color: _statusColor(e.value.key), width: 20, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
      ])).toList(),
    ));
  }

  Widget _paymentsLineChart(Map<String, dynamic> data) {
    final entries = data.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    if (entries.isEmpty) return _emptyChart(loc: AppLocalizations.of(context)!);
    final flatSpots = entries.asMap().entries.map((e) => FlSpot(e.key.toDouble(), _toDouble(e.value.value))).toList();

    return LineChart(LineChartData(
      lineBarsData: [LineChartBarData(
        spots: flatSpots, isCurved: true, color: ShadColors.gold, barWidth: 3,
        belowBarData: BarAreaData(show: true, color: ShadColors.gold.withValues(alpha: 0.1)),
        dotData: FlDotData(show: true, getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(radius: 3, color: ShadColors.gold, strokeWidth: 0)),
      )],
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 28, interval: 1,
          getTitlesWidget: (v, _) {
            final idx = v.toInt();
            if (idx < 0 || idx >= entries.length) return const SizedBox();
            final parts = entries[idx].key.split('-');
            final label = parts.length >= 2 ? '${parts[1]}/${parts[0].substring(2)}' : entries[idx].key;
            return Padding(padding: const EdgeInsets.only(top: 4), child: Text(label, style: const TextStyle(color: ShadColors.textSecondary, fontSize: 9)));
          },
        )),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(color: ShadColors.textDisabled, fontSize: 10)))),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      gridData: FlGridData(show: true, drawVerticalLine: false),
    ));
  }

  Widget _approvalPieChart(Map<String, dynamic> data) {
    final colors = [ShadColors.success, ShadColors.error, ShadColors.warning];
    final labels = ['approved', 'rejected', 'pending'];
    final entries = labels.where((k) => data.containsKey(k) && _toDouble(data[k]) > 0).toList();
    if (entries.isEmpty) return _emptyChart(loc: AppLocalizations.of(context)!);
    final total = entries.fold<double>(0, (s, k) => s + _toDouble(data[k]));

    return Row(children: [
      Expanded(child: PieChart(PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: entries.asMap().entries.map((e) => PieChartSectionData(
          value: _toDouble(data[e.value]),
          color: colors[labels.indexOf(e.value)],
          radius: 50,
          title: '${(_toDouble(data[e.value]) / total * 100).toInt()}%',
          titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        )).toList(),
      ))),
      Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _pieLegend(ShadColors.success, labels[0], data),
        const SizedBox(height: 8),
        _pieLegend(ShadColors.error, labels[1], data),
        const SizedBox(height: 8),
        _pieLegend(ShadColors.warning, labels[2], data),
      ]),
    ]);
  }

  Widget _pieLegend(Color color, String label, Map<String, dynamic> data) {
    final loc = AppLocalizations.of(context)!;
    final value = data[label] ?? 0;
    final texts = {
      'approved': loc.approved,
      'rejected': loc.rejected,
      'pending': loc.pending,
    };
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 6),
      Text('${texts[label] ?? label}: $value', style: const TextStyle(color: ShadColors.textSecondary, fontSize: 12)),
    ]);
  }

  Widget _emptyChart({required AppLocalizations loc}) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.bar_chart, color: ShadColors.textDisabled, size: 40),
      const SizedBox(height: 8),
      Text(loc.noData, style: const TextStyle(color: ShadColors.textDisabled)),
    ]));
  }

  Widget _auditLogTile(Map<String, dynamic> log) {
    final action = log['action'] as String? ?? '';
    final createdAt = log['created_at'] as String? ?? '';
    final user = log['user'] as Map<String, dynamic>?;
    final userName = user?['name'] as String? ?? '';
    final date = createdAt.length >= 16 ? createdAt.substring(0, 16).replaceAll('T', ' ') : createdAt;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.circle, size: 8, color: _auditColor(action)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_auditLabel(action), style: ShadTypography.cardBody.copyWith(fontSize: 13)),
            const SizedBox(height: 2),
            Row(children: [
              if (userName.isNotEmpty) Text('$userName • ', style: const TextStyle(color: ShadColors.textDisabled, fontSize: 11)),
              Text(date, style: const TextStyle(color: ShadColors.textDisabled, fontSize: 11)),
            ]),
          ])),
        ]),
      ),
    );
  }

  Color _auditColor(String action) {
    if (action.contains('approved') || action.contains('completed') || action.contains('activated')) return ShadColors.success;
    if (action.contains('rejected') || action.contains('deleted')) return ShadColors.error;
    if (action.contains('sent') || action.contains('created') || action.contains('uploaded')) return ShadColors.sent;
    if (action.contains('archived')) return ShadColors.archived;
    return ShadColors.textSecondary;
  }

  String _auditLabel(String action) {
    final labels = {
      'contract.created': 'إنشاء عقد',
      'contract.sent': 'إرسال عقد',
      'contract.client_approved': 'اعتماد العميل للعقد',
      'contract.client_rejected': 'رفض العميل للعقد',
      'contract.edit_requested': 'طلب تعديل العقد',
      'contract.company_approved': 'اعتماد الشركة للعقد',
      'contract.completed': 'إكمال العقد',
      'contract.archived': 'أرشفة العقد',
      'workspace.created': 'إنشاء مساحة عمل',
      'workspace.activated': 'تفعيل مساحة العمل',
      'approval.created': 'إنشاء طلب موافقة',
      'approval.approved': 'تمت الموافقة',
      'approval.rejected': 'تم الرفض',
      'approval.edit_requested': 'طلب تعديل الموافقة',
      'file.uploaded': 'رفع ملف',
      'file.approved': 'الموافقة على الملف',
      'file.rejected': 'رفض الملف',
      'login': 'تسجيل دخول',
    };
    return labels[action] ?? action;
  }

  Color _statusColor(String status) {
    return statusColors[status] ?? ShadColors.textSecondary;
  }

  String _statusShortLabel(String status) {
    final labels = {
      'draft': 'مسودة',
      'sent': 'مرسل',
      'client_approved': 'العميل',
      'company_approved': 'الشركة',
      'completed': 'مكتمل',
      'archived': 'مؤرشف',
      'client_rejected': 'مرفوض',
      'edit_requested': 'تعديل',
    };
    return labels[status] ?? status;
  }
}
