import 'package:flutter/material.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/empty_state.dart';

class AuditLogPage extends StatefulWidget {
  const AuditLogPage({super.key});

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  final _api = ApiClient();
  List<dynamic> _logs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.get('/audit-logs');
      _logs = (data['logs'] as List<dynamic>?) ?? [];
    } on ServerException catch (e) {
      _error = e.message;
    } catch (_) {
      if (mounted) _error = AppLocalizations.of(context)!.errorOccurred;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.auditLogs)),
      body: _loading
        ? const LoadingState()
        : _error != null
          ? Center(
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
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: _logs.isEmpty
                ? ListView(children: [Center(child: EmptyState(icon: Icons.history, title: loc.noAuditLogs, subtitle: 'لا توجد نشاطات بعد'))])
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _logs.length,
                    itemBuilder: (_, i) => _auditLogTile(_logs[i]),
                  ),
            ),
    );
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
}
