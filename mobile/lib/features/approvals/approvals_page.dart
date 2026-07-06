import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/loading_state.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';

class ApprovalsPage extends StatefulWidget {
  const ApprovalsPage({super.key});

  @override
  State<ApprovalsPage> createState() => _ApprovalsPageState();
}

class _ApprovalsPageState extends State<ApprovalsPage> {
  final _api = ApiClient();
  List<dynamic> _approvals = [];
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
      final data = await _api.get('/workspaces/${_api.workspaceIdSafe}/approvals');
      _approvals = safeList(data['approvals']);
    } catch (_) {
      _approvals = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _respond(int id, String action) async {
    final labels = {
      'approved': AppLocalizations.of(context)!.approve,
      'edit_requested': AppLocalizations.of(context)!.editRequested,
    };
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(labels[action] ?? action),
        content: Text(action == 'approved'
          ? 'سيتم استخدام توقيعك الإلكتروني المحفوظ. هل أنت متأكد؟'
          : 'هل أنت متأكد من ${labels[action] ?? action} هذا الطلب؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(context)!.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'approved' ? ShadColors.success : action == 'rejected' ? ShadColors.error : ShadColors.warning,
            ),
            child: Text(labels[action] ?? action),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.post('/approvals/$id/respond', {'action': action});
      if (mounted) {
        final label = action == 'approved' ? '✅ ${AppLocalizations.of(context)!.approved}' : action == 'rejected' ? '❌ ${AppLocalizations.of(context)!.rejected}' : '✎ ${AppLocalizations.of(context)!.editRequested}';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(label)));
        _load();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_approvals.isEmpty) return const EmptyState(icon: Icons.check_circle_outlined, title: 'لا توجد طلبات موافقة');

    final sorted = List<dynamic>.from(_approvals);
    sorted.sort((a, b) {
      final aCompleted = a['status'] == 'completed' || a['status'] == 'approved';
      final bCompleted = b['status'] == 'completed' || b['status'] == 'approved';
      if (aCompleted && !bCompleted) return 1;
      if (!aCompleted && bCompleted) return -1;
      return 0;
    });

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sorted.length,
        itemBuilder: (_, i) {
          final a = sorted[i];
          final isCompleted = a['status'] == 'completed' || a['status'] == 'approved';
          final hasCertificate = a['certificate'] != null && a['certificate']['pdf_url'] != null;
          final isUrgent = a['is_urgent'] == true;

          return Opacity(
            opacity: isCompleted ? 0.5 : 1.0,
            child: Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(a['title'] ?? '', style: ShadTypography.cardTitle)),
                          if (isUrgent)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: ShadColors.warningLight,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('عاجل', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: ShadColors.warning)),
                            ),
                        ]),
                        if (a['description'] != null) ...[
                          const SizedBox(height: 4),
                          Text(a['description'], style: ShadTypography.cardBody.copyWith(color: ShadColors.textSecondary)),
                        ],
                        const SizedBox(height: 4),
                        Text('${a['reference_no'] ?? ''}', style: ShadTypography.caption.copyWith(color: ShadColors.textDisabled)),
                      ])),
                      StatusBadge(status: a['status'] ?? ''),
                    ]),

                    // Files
                    if (a['files'] != null && (a['files'] as List).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(spacing: 4, runSpacing: 4, children: (a['files'] as List).map<Widget>((f) => ActionChip(
                        avatar: const Icon(Icons.attach_file, size: 14),
                        label: Text(f['name'] ?? 'ملف', style: ShadTypography.caption),
                        onPressed: () {},
                      )).toList()),
                    ],

                    // Certificate
                    if (hasCertificate)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: InkWell(
                          onTap: () async {
                            final pdfUrl = a['certificate']['pdf_url'] as String?;
                            if (pdfUrl != null) {
                              final url = _api.resolveFileUrl(pdfUrl);
                              final uri = Uri.tryParse(url);
                              if (uri != null && await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل فتح الملف')));
                              }
                            }
                          },
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.picture_as_pdf, size: 16, color: ShadColors.error),
                            const SizedBox(width: 4),
                            Text(AppLocalizations.of(context)!.approvals, style: ShadTypography.cardBody.copyWith(color: ShadColors.primary, decoration: TextDecoration.underline)),
                          ]),
                        ),
                      ),

                    // Action buttons
                    if (!isCompleted && a['status'] == 'pending') ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: ElevatedButton(
                          onPressed: () => _respond(a['id'], 'approved'),
                          style: ElevatedButton.styleFrom(backgroundColor: ShadColors.success),
                          child: Text(AppLocalizations.of(context)!.approve),
                        )),
                        const SizedBox(width: 6),
                        Expanded(child: TextButton(
                          onPressed: () => _respond(a['id'], 'edit_requested'),
                          child: Text(AppLocalizations.of(context)!.editRequested),
                        )),
                      ]),
                    ],
                    if (isCompleted)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: ShadColors.successLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('مكتمل', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: ShadColors.success)),
                          ),
                        ]),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
