import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../widgets/contract_builder.dart';

class ContractsTab extends StatefulWidget {
  final int? workspaceId;
  const ContractsTab({super.key, this.workspaceId});

  @override
  State<ContractsTab> createState() => _ContractsTabState();
}

class _ContractsTabState extends State<ContractsTab> {
  final _api = ApiClient();
  List<dynamic> _contracts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final wsId = widget.workspaceId ?? _api.workspaceId;
    if (wsId == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.get('/workspaces/$wsId/contracts');
      _contracts = safeList(data['contracts']);
    } on ServerException catch (e) {
      _error = e.message;
    } catch (_) {
      if (mounted) _error = AppLocalizations.of(context)!.contractsLoadFailed;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _action(int id, String action, {bool destructive = false}) async {
    if (destructive) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(action == 'archive' ? AppLocalizations.of(context)!.archive : AppLocalizations.of(context)!.completeComplete),
          content: const Text('هل أنت متأكد من هذا الإجراء؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد')),
          ],
        ),
      );
      if (confirm != true) return;
    }
    try {
      await _api.post('/contracts/$id/$action');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.contractUpdated)));
        await _load();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.errorOccurred)));
    }
  }

  Future<void> _editContract(Map<String, dynamic> c) async {
    await ContractBuilder.show(context, contractId: c['id'], contractData: c, onCreated: _load);
  }

  Future<void> _deleteContract(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف العقد'),
        content: const Text('هل أنت متأكد من حذف هذا العقد؟ لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: ShadColors.error), child: const Text('حذف')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.delete('/contracts/$id');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف العقد')));
        _load();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل حذف العقد')));
    }
  }

  Future<void> _companyApproveWithSignature(Map<String, dynamic> contract) async {
    final messenger = ScaffoldMessenger.of(context);
    String? savedSignature;

    try {
      final me = await _api.get('/auth/me');
      final user = me['user'] as Map<String, dynamic>?;
      if (user != null) {
        savedSignature = user['signature_data'] as String?;
      }
    } catch (_) {}

    if (!mounted) return;

    if (savedSignature != null && savedSignature.isNotEmpty) {
      final sig = savedSignature;
      final useSaved = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppLocalizations.of(ctx)!.companyApprove),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('اعتماد عقد: ${contract['title']}', style: ShadTypography.cardBody),
            const SizedBox(height: 16),
            const Text('سيتم استخدام توقيعك المحفوظ:', style: TextStyle(color: ShadColors.textSecondary)),
            const SizedBox(height: 8),
            if (sig.startsWith('http') || sig.startsWith('/storage'))
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  sig.startsWith('http') ? sig : '${_api.baseUrl.replaceAll('/api', '')}$sig',
                  height: 50, fit: BoxFit.contain,
                ),
              )
            else
              Text(sig, style: const TextStyle(fontSize: 24, fontFamily: 'DancingScript')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(ctx)!.cancel)),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppLocalizations.of(ctx)!.confirm)),
          ],
        ),
      );
      if (useSaved != true) return;
      try {
        await _api.post('/contracts/${contract['id']}/company-approve', {});
        if (mounted) {
          messenger.showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.contractUpdated)));
          _load();
        }
      } catch (_) {
        if (mounted) messenger.showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.errorOccurred)));
      }
      return;
    }

    if (!mounted) return;

    final signatureController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx)!.companyApprove),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('اعتماد عقد: ${contract['title']}', style: ShadTypography.cardBody),
            const SizedBox(height: 16),
            TextField(
              controller: signatureController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(ctx)!.companySignature,
                hintText: AppLocalizations.of(ctx)!.signatureHint,
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(ctx)!.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final sig = signatureController.text.trim();
              if (sig.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(AppLocalizations.of(ctx)!.enterSignature)));
                return;
              }
              Navigator.pop(ctx, sig);
            },
            child: Text(AppLocalizations.of(ctx)!.confirm),
          ),
        ],
      ),
    );
    if (result == null) return;
    try {
      await _api.post('/contracts/${contract['id']}/company-approve', {'signature': result});
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.contractUpdated)));
        _load();
      }
    } catch (_) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.errorOccurred)));
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return '—';
    final s = date.toString();
    if (s.isEmpty) return '—';
    try {
      final parsed = DateTime.parse(s);
      return '${parsed.year}/${parsed.month}/${parsed.day}';
    } catch (_) {
      return s.split('T')[0];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSA = _api.role == 'super_admin';
    final Map<String, List<String>> actionsForStatus = {
      'draft': ['send'],
      'edit_requested': ['send'],
      if (isSA) 'client_approved': ['company-approve'],
      if (isSA) 'company_approved': [],
      if (!isSA) 'company_approved': ['archive'],
    };

    if (_loading) return const LoadingState(itemCount: 3);
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    return Stack(children: [
      if (_contracts.isEmpty)
        Center(child: EmptyState(icon: Icons.description_outlined, title: AppLocalizations.of(context)!.noContracts, subtitle: AppLocalizations.of(context)!.noContractsSubtitle))
      else
        RefreshIndicator(
          onRefresh: _load,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: _contracts.length,
            itemBuilder: (_, i) {
              final c = _contracts[i];
              final clauses = c['clauses'] as List<dynamic>? ?? [];
              final rawActions = actionsForStatus[c['status']] ?? [];
              final actions = rawActions.where((a) {
                if (isSA) return a == 'company-approve' || a == 'complete';
                return a != 'company-approve';
              }).toList();
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(c['title'] ?? '', style: ShadTypography.cardTitle),
                          const SizedBox(height: 4),
                          Text('${c['value'] ?? 0} ${c['currency'] as String? ?? 'SAR'} • ${clauses.length} بنود', style: ShadTypography.cardBody.copyWith(color: ShadColors.textSecondary)),
                          const SizedBox(height: 2),
                          Text(
                            '${_formatDate(c['start_date'])} - ${_formatDate(c['end_date'])}',
                            style: ShadTypography.cardBody.copyWith(color: ShadColors.textDisabled, fontSize: 11),
                          ),
                          if ((c['required_documents'] as List?)?.isNotEmpty == true)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text('${(c['required_documents'] as List).length} مستندات مطلوبة', style: ShadTypography.cardBody.copyWith(color: ShadColors.gold, fontSize: 11)),
                            ),
                        ])),
                        StatusBadge(status: c['status'] ?? ''),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 18),
                          onSelected: (action) {
                            if (action == 'edit') _editContract(c);
                            if (action == 'delete') _deleteContract(c['id']);
                            if (action == 'archive') _action(c['id'], 'archive', destructive: true);
                          },
                          itemBuilder: (_) {
                            final items = <PopupMenuEntry<String>>[];
                            if (c['status'] == 'draft' || c['status'] == 'edit_requested') {
                              items.add(const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, size: 18), title: Text('تعديل'), dense: true)));
                              items.add(const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, size: 18, color: ShadColors.error), title: Text('حذف', style: TextStyle(color: ShadColors.error)), dense: true)));
                            }
                            if (c['status'] == 'company_approved') {
                              items.add(const PopupMenuItem(value: 'archive', child: ListTile(leading: Icon(Icons.archive, size: 18), title: Text('أرشفة'), dense: true)));
                            }
                            return items;
                          },
                        ),
                      ]),
                      if (['client_approved', 'company_approved', 'completed'].contains(c['status']) && c['pdf_url'] != null) ...[
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () async {
                            final url = _api.resolveFileUrl(c['pdf_url'] as String);
                            final uri = Uri.tryParse(url);
                            if (uri != null && await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            } else {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل فتح الملف')));
                            }
                          },
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.picture_as_pdf, size: 16, color: ShadColors.error),
                            const SizedBox(width: 4),
                            Text(
                              c['status'] == 'client_approved' ? '📄 عرض العقد الموقع' : '📄 تحميل العقد النهائي',
                              style: ShadTypography.cardBody.copyWith(color: ShadColors.primary, decoration: TextDecoration.underline),
                            ),
                          ]),
                        ),
                      ],
                      if (clauses.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        ExpansionTile(
                          title: Text('${AppLocalizations.of(context)!.viewClauses} (${clauses.length})', style: ShadTypography.cardBody.copyWith(color: ShadColors.primary)),
                          childrenPadding: EdgeInsets.zero,
                          children: clauses.map<Widget>((cl) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Icon(Icons.circle, size: 6, color: ShadColors.textDisabled),
                              const SizedBox(width: 8),
                              Expanded(child: Text(cl['content'] ?? '', style: ShadTypography.cardBody)),
                            ]),
                          )).toList(),
                        ),
                      ],
                      if (actions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, children: actions.map((a) {
                          final isDestructive = a == 'archive' || a == 'complete';
                          final isPrimary = a == 'company-approve' || a == 'send';
                          if (isDestructive) {
                            return OutlinedButton(
                              onPressed: () => _action(c['id'], a, destructive: true),
                              style: OutlinedButton.styleFrom(foregroundColor: ShadColors.textSecondary, side: const BorderSide(color: ShadColors.textDisabled)),
                              child: Text(a == 'archive' ? AppLocalizations.of(context)!.archive : AppLocalizations.of(context)!.completeComplete),
                            );
                          }
                          return ElevatedButton(
                            onPressed: a == 'company-approve' ? () => _companyApproveWithSignature(c) : () => _action(c['id'], a),
                            style: isPrimary ? ElevatedButton.styleFrom(backgroundColor: ShadColors.success) : null,
                            child: Text(a == 'send' ? AppLocalizations.of(context)!.send : a == 'company-approve' ? AppLocalizations.of(context)!.companyApprove : a == 'complete' ? AppLocalizations.of(context)!.completeComplete : a),
                          );
                        }).toList()),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      if (_api.role != 'super_admin')
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: ElevatedButton.icon(
            onPressed: () => ContractBuilder.show(context, onCreated: _load),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('إنشاء عقد جديد'),
          ),
        ),
    ]);
  }
}
