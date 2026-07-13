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
  List<dynamic> _contracts = [];
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
      final results = await Future.wait<Map<String, dynamic>>([
        _api.get('/workspaces/$wsId/payments'),
        _api.get('/workspaces/$wsId/contracts'),
      ]);
      _payments = (results[0]['payments'] as List<dynamic>?) ?? [];
      final rawContracts = results[1]['contracts'];
      _contracts = rawContracts is List ? rawContracts : (rawContracts is Map ? (rawContracts['data'] ?? []) as List : []);
    } catch (_) {
      _error = 'فشل تحميل المدفوعات';
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _payableContracts {
    return _contracts.cast<Map<String, dynamic>?>().where(
      (c) => c?['status'] == 'company_approved' || c?['status'] == 'completed',
    ).whereType<Map<String, dynamic>>().toList();
  }

  double get _totalPaid {
    return _payments
        .where((p) => p['status'] == 'approved')
        .fold<double>(0, (sum, p) => sum + (num.tryParse(p['amount']?.toString() ?? '')?.toDouble() ?? 0));
  }

  double get _grandTotal {
    final contracts = _payableContracts;
    if (contracts.isNotEmpty) {
      return contracts.fold<double>(0, (sum, c) => sum + (num.tryParse(c['value']?.toString() ?? '')?.toDouble() ?? 0));
    }
    return _payments.fold<double>(0, (s, p) => s + (num.tryParse(p['amount']?.toString() ?? '')?.toDouble() ?? 0));
  }

  String get _contractCurrency {
    final contracts = _payableContracts;
    return (contracts.isNotEmpty ? (contracts.first['currency'] as String?) : null) ?? 'SAR';
  }

  String _installmentLabel(int index) {
    const labels = ['الأولى', 'الثانية', 'الثالثة', 'الرابعة', 'الخامسة', 'السادسة', 'السابعة', 'الثامنة', 'التاسعة', 'العاشرة'];
    return index < labels.length ? 'دفعة ${labels[index]}' : 'دفعة ${index + 1}';
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
        itemCount: _payments.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) {
            final grandTotal = _grandTotal;
            final contractCur = _contractCurrency;
            final progress = grandTotal > 0 ? (_totalPaid / grandTotal).clamp(0.0, 1.0) : 0.0;
            final isFullyPaid = _totalPaid >= grandTotal && grandTotal > 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ShadColors.cardBorder),
              ),
              child: Column(children: [
                if (isFullyPaid) ...[
                  const Icon(Icons.check_circle, size: 28, color: ShadColors.success),
                  const SizedBox(height: 6),
                  const Text('تم الدفع بالكامل', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ShadColors.success)),
                  const SizedBox(height: 4),
                  Text('${_totalPaid.toStringAsFixed(2)} $contractCur', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'PlayfairDisplay')),
                ] else ...[
                  Text('إجمالي المدفوع', style: TextStyle(fontSize: 12, color: ShadColors.gold)),
                  const SizedBox(height: 6),
                  Text('${_totalPaid.toStringAsFixed(2)} $contractCur', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'PlayfairDisplay')),
                  const SizedBox(height: 4),
                  Text('من أصل ${grandTotal.toStringAsFixed(2)} $contractCur — متبقي ${(grandTotal - _totalPaid).toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: ShadColors.textDisabled)),
                ],
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: ShadColors.cardBorder,
                    valueColor: AlwaysStoppedAnimation(isFullyPaid ? ShadColors.success : ShadColors.gold),
                  ),
                ),
              ]),
            );
          }
          final p = _payments[i - 1];
          final isPending = p['status'] == 'pending';
          final isApproved = p['status'] == 'approved';
          final statusColor = isApproved ? ShadColors.success : isPending ? ShadColors.gold : ShadColors.textDisabled;
          final statusText = isApproved ? 'تمت الموافقة' : isPending ? 'قيد الانتظار' : p['status'] ?? '';

          final methodLabels = {'bank_transfer': 'تحويل بنكي', 'swift': 'SWIFT', 'corporate_account': 'حساب شركة', 'instapay': 'Instapay', 'vodafone_cash': 'فودافون كاش', 'mobile_wallet': 'محفظة موبايل'};

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: ShadColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isPending ? ShadColors.gold : ShadColors.cardBorder, width: isPending ? 1.5 : 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── القسم العلوي ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_installmentLabel(i - 1), style: TextStyle(fontSize: 11, color: ShadColors.gold, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('${p['amount'] ?? 0} ${p['currency'] as String? ?? 'SAR'}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'PlayfairDisplay')),
                    const SizedBox(height: 4),
                    Row(children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(statusText, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w500)),
                    ]),
                  ]),
                ),

                // ── الفاصل ──
                Divider(height: 1, color: ShadColors.cardBorder),

                // ── القسم السفلي ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if ((p['method_type'] ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          Text('💳 ', style: TextStyle(fontSize: 12)),
                          Text(methodLabels[p['method_type']] ?? p['method_type'] ?? '', style: TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
                        ]),
                      ),
                    if (p['contract'] is Map && p['contract']['title'] != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          Text('📄 ', style: TextStyle(fontSize: 12)),
                          Text(p['contract']['title'], style: TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
                        ]),
                      ),
                    if (p['proof_file_url'] != null)
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
                            child: Row(children: [
                              Text('📎 ', style: TextStyle(fontSize: 12)),
                              Text('عرض إثبات الدفع', style: TextStyle(fontSize: 12, color: ShadColors.gold)),
                            ]),
                          ),
                        ));
                      })(),
                    // ── زر الاعتماد (للـ AM بس) ──
                    if (isPending) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _review(p['id']),
                          style: ElevatedButton.styleFrom(backgroundColor: ShadColors.success),
                          child: const Text('اعتماد'),
                        ),
                      ),
                    ],
                  ]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

List safeList(dynamic value) {
  if (value is List) return value;
  return [];
}
