import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';

class PaymentsTab extends StatefulWidget {
  final VoidCallback? onWorkspaceUpdate;
  const PaymentsTab({super.key, this.onWorkspaceUpdate});

  @override
  State<PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<PaymentsTab> {
  final _api = ApiClient();
  List<dynamic> _payments = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final wsId = _api.workspaceId;
    if (wsId == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.get('/workspaces/$wsId/payments');
      _payments = data['payments'] as List<dynamic>? ?? [];
    } catch (_) {
      _error = 'فشل تحميل المدفوعات';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _review(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اعتماد الدفعة'),
        content: const Text('هل أنت متأكد من اعتماد هذه الدفعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final data = await _api.post('/payments/$id/review', {'action': 'approved'});
      if (mounted) {
        final wsActive = data['workspace']?['status'] == 'active';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(wsActive ? '✅ تم اعتماد الدفعة — مساحة العمل نشطة' : '✅ تم اعتماد الدفعة — سيتم تفعيل مساحة العمل عند اكتمال الإجراءات'),
        ));
        _load();
        widget.onWorkspaceUpdate?.call();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState(itemCount: 3);
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_payments.isEmpty) return const EmptyState(icon: Icons.payment_outlined, title: 'لا توجد مدفوعات');

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _payments.length,
        itemBuilder: (_, i) {
          final p = _payments[i];
          final statusColors = {'pending': ShadColors.warning, 'approved': ShadColors.success, 'rejected': ShadColors.error};
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    CircleAvatar(
                      backgroundColor: (statusColors[p['status']] ?? ShadColors.textDisabled).withAlpha(25),
                      child: Icon(
                        p['status'] == 'approved' ? Icons.check_circle : p['status'] == 'rejected' ? Icons.cancel : Icons.hourglass_empty,
                        color: statusColors[p['status']] ?? ShadColors.textDisabled,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${p['amount'] ?? 0} ${p['currency'] as String? ?? 'ر.س'}', style: ShadTypography.cardTitle),
                        Text(p['method_type'] ?? '', style: ShadTypography.caption.copyWith(color: ShadColors.textSecondary)),
                      ]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (statusColors[p['status']] ?? ShadColors.textDisabled).withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusLabels[p['status']] ?? p['status'] ?? '',
                        style: ShadTypography.caption.copyWith(color: statusColors[p['status']] ?? ShadColors.textDisabled),
                      ),
                    ),
                  ]),
                  if (p['proof_file_url'] != null) ...[
                    const SizedBox(height: 8),
                    ...(() {
                      final urls = (p['proof_file_url'] is List) ? (p['proof_file_url'] as List).cast<String>() : [p['proof_file_url'].toString()];
                      return urls.map((url) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: InkWell(
                          onTap: () async {
                            final resolved = _api.resolveFileUrl(url);
                            final uri = Uri.tryParse(resolved);
                            if (uri != null && await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            } else {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل فتح الملف')));
                            }
                          },
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.visibility, size: 16, color: ShadColors.primary),
                            const SizedBox(width: 4),
                            Text('📎 إثبات الدفع', style: ShadTypography.cardBody.copyWith(color: ShadColors.primary, decoration: TextDecoration.underline)),
                          ]),
                        ),
                      ));
                    })(),
                  ],
                  if (p['status'] == 'pending') ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: ElevatedButton(
                        onPressed: () => _review(p['id']),
                        style: ElevatedButton.styleFrom(backgroundColor: ShadColors.success),
                        child: const Text('اعتماد'),
                      )),

                    ]),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
