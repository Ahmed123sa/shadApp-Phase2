import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/loading_state.dart';
import '../../core/widgets/error_state.dart';

class ContractsPage extends StatefulWidget {
  final VoidCallback? onGoToPayments;
  final ValueNotifier<int>? refreshNotifier;
  const ContractsPage({super.key, this.onGoToPayments, this.refreshNotifier});


  @override
  State<ContractsPage> createState() => _ContractsPageState();
}

class _ContractsPageState extends State<ContractsPage> {
  final _api = ApiClient();
  List<dynamic> _contracts = [];
  bool _loading = true;
  String? _error;
  VoidCallback? _refreshListener;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.refreshNotifier != null) {
      _refreshListener = () { if (mounted) _load(); };
      widget.refreshNotifier!.addListener(_refreshListener!);
    }
  }

  Future<void> _load() async {
    final wsId = _api.workspaceId;
    if (wsId == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.get('/workspaces/$wsId/contracts');
      _contracts = safeList(data['contracts']);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _clientAction(int contractId, String action) async {
    final labels = {
      'approved': 'موافقة',
      'edit_requested': 'طلب تعديل',
    };

    String? reason;

    if (action == 'approved') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('موافقة على العقد'),
          content: const Text('هل أنت متأكد من الموافقة على هذا العقد؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد')),
          ],
        ),
      );
      if (confirm != true) return;
    } else if (action == 'edit_requested') {
      reason = await _showReasonDialog();
      if (reason == null) return;
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${labels[action] ?? action} العقد'),
          content: const Text('هل أنت متأكد؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(labels[action] ?? action)),
          ],
        ),
      );
      if (confirm != true) return;
    }

    try {
      await _api.post('/contracts/$contractId/client-action', {
        'action': action,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ تم ${labels[action] ?? action} العقد')));
        _load();
        widget.refreshNotifier?.value++;
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل تنفيذ الإجراء')));
    }
  }

  Future<String?> _showReasonDialog() async {
    final controller = TextEditingController();
    final label = 'التعديلات المطلوبة';
    final hint = 'اذكر التعديلات المطلوبة...';
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(controller: controller, maxLines: 3, decoration: InputDecoration(hintText: hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('تأكيد')),
        ],
      ),
    );
    return result;
  }

  @override
  void dispose() {
    if (_refreshListener != null && widget.refreshNotifier != null) {
      widget.refreshNotifier!.removeListener(_refreshListener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) { return const LoadingState(); }
    if (_error != null) { return ErrorState(message: _error!, onRetry: _load); }
    if (_contracts.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3)),
          SizedBox(height: 16),
          Text('في انتظار استلام العقد', style: TextStyle(fontSize: 14, color: ShadColors.textSecondary, fontFamily: 'NotoSansArabic')),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ..._contracts.map((c) => _contractCard(c)),
        ],
      ),
    );
  }

  Widget _contractCard(dynamic c) {
    final status = c['status'] as String? ?? '';
    final needsAction = status == 'sent';

    return GestureDetector(
      onTap: () => _showDetailModal(c),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: ShadColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ShadColors.cardBorder),
        ),
        child: Column(children: [
          Row(children: [
            Container(
              width: 3, height: needsAction ? 100 : 72,
              decoration: BoxDecoration(
                color: needsAction ? ShadColors.gold : ShadColors.crimson,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: ShadColors.black,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.description, size: 22, color: ShadColors.gold),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child:                     Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(c['title'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
                      const SizedBox(height: 4),
                      Row(children: [
                        Text('Ref: ${c['id'] ?? ''}', style: const TextStyle(fontSize: 11, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
                        if ((c['required_documents'] as List?)?.isNotEmpty == true) ...[
                          const SizedBox(width: 8),
                          Text('${(c['required_documents'] as List).length} مستندات', style: const TextStyle(fontSize: 11, color: ShadColors.textSecondary, fontFamily: 'NotoSansArabic')),
                        ],
                      ]),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    StatusBadge(status: status),
                    const SizedBox(height: 4),
                    Text('${c['value'] ?? 0} ${c['currency'] as String? ?? 'SAR'}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'PlayfairDisplay')),
                  ]),
                ]),
              ),
            ),
          ]),
          if (needsAction)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(children: [
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: ElevatedButton.icon(
                      onPressed: () => _clientAction(c['id'], 'approved'),
                      icon: const Icon(Icons.check, size: 14),
                      label: const Text('موافقة', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ShadColors.success,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: OutlinedButton.icon(
                      onPressed: () => _clientAction(c['id'], 'edit_requested'),
                      icon: const Icon(Icons.edit, size: 14),
                      label: const Text('تعديل', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ShadColors.warning,
                        side: const BorderSide(color: ShadColors.warning),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                ),

              ]),
            ),
          if (status == 'company_approved')
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: ShadColors.success.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ShadColors.success.withAlpha(40)),
                ),
                child: Column(children: [
                  Row(children: [
                    const Icon(Icons.check_circle, size: 16, color: ShadColors.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('تم اعتماد العقد من الشركة', style: TextStyle(fontSize: 11, color: ShadColors.success, fontFamily: 'NotoSansArabic')),
                    ),
                    if (c['pdf_url'] != null)
                      TextButton(
                        onPressed: () async {
                          final url = _api.resolveFileUrl(c['pdf_url'] as String);
                          final uri = Uri.tryParse(url);
                          final messenger = ScaffoldMessenger.of(context);
                          if (uri != null) {
                            try {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            } catch (_) {
                              messenger.showSnackBar(const SnackBar(content: Text('فشل فتح الملف')));
                            }
                          } else {
                            messenger.showSnackBar(const SnackBar(content: Text('رابط الملف غير صالح')));
                          }
                        },
                        child: const Icon(Icons.download, size: 16, color: ShadColors.success),
                      ),
                  ]),
                  if (widget.onGoToPayments != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => widget.onGoToPayments?.call(),
                        icon: const Icon(Icons.payment, size: 16),
                        label: const Text('💳 انتقال إلى الدفع', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ShadColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ),
                  ],
                ]),
              ),
            ),
        ]),
      ),
    );
  }

  void _showDetailModal(dynamic c) { showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))), builder: (_) => _ContractDetailModal(contract: c, onAction: _clientAction, onRefresh: _load, onGoToPayments: widget.onGoToPayments)); }
}

class _ContractDetailModal extends StatefulWidget {
  final dynamic contract;
  final Future<void> Function(int, String) onAction;
  final VoidCallback onRefresh;   final VoidCallback? onGoToPayments;

  const _ContractDetailModal({
    required this.contract,
    required this.onAction,
    required this.onRefresh,     required this.onGoToPayments,
  });

  @override
  State<_ContractDetailModal> createState() => _ContractDetailModalState();
}

class _ContractDetailModalState extends State<_ContractDetailModal> {
  final _api = ApiClient();
  bool _uploading = false;

  Future<void> _uploadDocument(int contractId, int? definitionId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;
    final pf = result.files.single;
    final wsId = _api.workspaceId;
    if (wsId == null) return;

    setState(() => _uploading = true);
    try {
      final fields = <String, dynamic>{'contract_id': contractId};
      if (definitionId != null) fields['contract_required_document_id'] = definitionId;
      if (kIsWeb) {
        await _api.multipartPost('/workspaces/$wsId/files', fields, bytes: pf.bytes, filename: pf.name);
      } else {
        await _api.multipartPost('/workspaces/$wsId/files', fields, file: File(pf.path!));
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم رفع المستند')));
      widget.onRefresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل رفع المستند: $e')));
    }
    if (mounted) setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.contract;
    final status = c['status'] as String? ?? '';
    final clauses = c['clauses'] as List<dynamic>? ?? [];
    final requiredDocs = c['required_documents'] as List<dynamic>? ?? [];
    final needsAction = status == 'sent';
    final isCompanyApproved = status == 'company_approved';

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 16),
        child: ListView(
          controller: scrollController,
          children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c['title'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'PlayfairDisplay')),
                  const SizedBox(height: 4),
                  Text('Ref: ${c['id'] ?? ''}', style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
                ]),
              ),
              StatusBadge(status: status),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
            const SizedBox(height: 16),

            if (c['value'] != null || c['start_date'] != null || c['end_date'] != null) ...[
              Row(children: [
                if (c['value'] != null)
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('VALUE', style: TextStyle(fontSize: 9, letterSpacing: 1, color: ShadColors.textDisabled, fontFamily: 'Archivo')),
                    Text('${c['value']} ${c['currency'] as String? ?? 'SAR'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'PlayfairDisplay')),
                  ])),
                if (c['start_date'] != null)
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('START', style: TextStyle(fontSize: 9, letterSpacing: 1, color: ShadColors.textDisabled, fontFamily: 'Archivo')),
                    Text((c['start_date'] as String).split('T')[0], style: const TextStyle(fontSize: 13, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
                  ])),
                if (c['end_date'] != null)
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('END', style: TextStyle(fontSize: 9, letterSpacing: 1, color: ShadColors.textDisabled, fontFamily: 'Archivo')),
                    Text((c['end_date'] as String).split('T')[0], style: const TextStyle(fontSize: 13, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
                  ])),
              ]),
              const SizedBox(height: 16),
            ],

            // Clauses
            if (clauses.isNotEmpty) ...[
              Text('بنود العقد', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ShadColors.textPrimary, fontFamily: 'NotoSansArabic')),
              const SizedBox(height: 8),
              ...clauses.map((cl) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ShadColors.card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ShadColors.cardBorder),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.circle, size: 6, color: ShadColors.textDisabled),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(cl['content'] ?? '', style: const TextStyle(fontSize: 13, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
                    if (cl['type'] != null)
                      Text(cl['type'], style: TextStyle(fontSize: 10, color: ShadColors.textDisabled, fontFamily: 'Archivo')),
                  ])),
                ]),
              )),
              const SizedBox(height: 16),
            ],

            // Required documents
            if (requiredDocs.isNotEmpty) ...[
              Text('المستندات المطلوبة', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ShadColors.textPrimary, fontFamily: 'NotoSansArabic')),
              const SizedBox(height: 8),
              ...requiredDocs.map((doc) {
                final docStatus = doc['status'] as String? ?? 'pending';
                final docStatusColor = docStatus == 'approved'
                    ? ShadColors.success
                    : docStatus == 'rejected'
                        ? ShadColors.error
                        : ShadColors.warning;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ShadColors.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ShadColors.cardBorder),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(doc['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: ShadColors.textPrimary, fontFamily: 'Archivo'))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: docStatusColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statusLabels[docStatus] ?? docStatus,
                          style: TextStyle(fontSize: 10, color: docStatusColor, fontWeight: FontWeight.w500, fontFamily: 'Archivo'),
                        ),
                      ),
                    ]),
                    if (doc['rejection_reason'] != null) ...[
                      const SizedBox(height: 4),
                      Text('سبب الرفض: ${doc['rejection_reason']}', style: const TextStyle(fontSize: 11, color: ShadColors.error, fontFamily: 'NotoSansArabic')),
                    ],
                    if (docStatus != 'approved') ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _uploading ? null : () => _uploadDocument(c['id'], doc['id']),
                          icon: _uploading
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.upload_file, size: 16),
                          label: Text(_uploading ? 'جاري الرفع...' : 'رفع المستند'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ShadColors.primary,
                            side: const BorderSide(color: ShadColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                      ),
                    ],
                  ]),
                );
              }),
              const SizedBox(height: 16),
            ],

            // Action buttons (same as card)
            if (needsAction) ...[
              Text('الإجراءات', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ShadColors.textPrimary, fontFamily: 'NotoSansArabic')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await widget.onAction(c['id'], 'approved');
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('موافقة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ShadColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await widget.onAction(c['id'], 'edit_requested');
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('تعديل'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ShadColors.warning,
                      side: const BorderSide(color: ShadColors.warning),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),

              ]),
            ],

            if (isCompanyApproved) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ShadColors.success.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ShadColors.success.withAlpha(40)),
                ),
                child: Column(children: [
                  const Icon(Icons.check_circle, size: 40, color: ShadColors.success),
                  const SizedBox(height: 8),
                  Text('تم اعتماد العقد من قبل الشركة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ShadColors.success, fontFamily: 'NotoSansArabic')),
                  const SizedBox(height: 4),
                  Text('يمكنك التوجه إلى صفحة الدفع لإتمام الدفعة', style: TextStyle(fontSize: 12, color: ShadColors.success, fontFamily: 'NotoSansArabic')),
                  if (c['pdf_url'] != null) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final url = _api.resolveFileUrl(c['pdf_url'] as String);
                        final uri = Uri.tryParse(url);
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل فتح الملف')));
                        }
                      },
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: const Text('تحميل PDF'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ShadColors.success,
                        side: const BorderSide(color: ShadColors.success),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onGoToPayments?.call();
                    },
                    icon: const Icon(Icons.payment, size: 18),
                    label: const Text('💳 انتقال إلى الدفع'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ShadColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ]),
              ),
            ],

            // Status messages for non-actionable statuses (like web)
            if (!needsAction && !isCompanyApproved && status != 'draft') ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ShadColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ShadColors.cardBorder),
                ),
                child: Center(
                  child: Text(
                    status == 'client_approved' ? 'تمت موافقتك على هذا العقد' :
                    status == 'edit_requested' ? 'قمت بطلب تعديل العقد' :
                    status == 'rejected' ? 'قمت برفض هذا العقد' :
                    status == 'completed' ? 'العقد مكتمل' : '',
                    style: TextStyle(fontSize: 13, color: ShadColors.textSecondary, fontFamily: 'NotoSansArabic'),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
