import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/status_badge.dart';

class ApprovalsTab extends StatefulWidget {
  final int? workspaceId;
  const ApprovalsTab({super.key, this.workspaceId});

  @override
  State<ApprovalsTab> createState() => _ApprovalsTabState();
}

class _ApprovalsTabState extends State<ApprovalsTab> {
  final _api = ApiClient();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  List<dynamic> _approvals = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  List<File> _selectedFiles = [];
  List<String> _selectedFileNames = [];

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
      final data = await _api.get('/workspaces/$wsId/approvals');
      _approvals = safeList(data['approvals']);
    } catch (_) {
      _error = 'فشل تحميل طلبات الموافقة';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any, allowMultiple: true);
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFiles = result.files.where((f) => f.path != null).map((f) => File(f.path!)).toList();
        _selectedFileNames = result.files.map((f) => f.name).toList();
      });
    }
  }

  Future<void> _create() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || widget.workspaceId == null) return;
    setState(() => _sending = true);
    try {
      final fields = <String, dynamic>{
        'title': title,
        'description': _descController.text.trim(),
      };
      if (_selectedFiles.isNotEmpty) {
        await _api.multipartPostMultiple('/workspaces/${widget.workspaceId}/approvals', fields, files: _selectedFiles, fileField: 'files[]');
      } else {
        await _api.post('/workspaces/${widget.workspaceId}/approvals', fields);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم إرسال طلب الموافقة')));
        _titleController.clear();
        _descController.clear();
        setState(() { _selectedFiles = []; _selectedFileNames = []; });
        _load();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل إرسال الطلب')));
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _respond(int id, String action, String? reason) async {
    try {
      await _api.post('/approvals/$id/respond', {
        'action': action,
        if (reason != null) 'reason': reason,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(action == 'approved' ? '✅ تمت الموافقة' : '✎ تم طلب تعديل'),
        ));
        _load();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل تنفيذ الإجراء')));
    }
  }

  Future<void> _showEditRequestDialog(int id) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('طلب تعديل'),
          content: TextField(controller: c, maxLines: 3, decoration: const InputDecoration(hintText: 'اذكر التعديلات المطلوبة...')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('إرسال الطلب')),
          ],
        );
      },
    );
    if (reason != null && mounted) _respond(id, 'edit_requested', reason.isEmpty ? null : reason);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final isSA = _api.role == 'super_admin';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!isSA)
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('إنشاء طلب موافقة', style: ShadTypography.cardTitle),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'عنوان الطلب *', hintText: 'مثال: اعتماد التصميم النهائي'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descController,
                    decoration: const InputDecoration(labelText: 'الوصف', hintText: 'تفاصيل إضافية...'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: Icon(Icons.attach_file, size: 18),
                    label: Text(_selectedFileNames.isNotEmpty ? '${_selectedFileNames.length} ملفات' : 'إرفاق ملفات'),
                  ),
                  if (_selectedFileNames.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(spacing: 4, runSpacing: 2, children: _selectedFileNames.map((n) => Chip(
                        label: Text(n, style: const TextStyle(fontSize: 10)),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () {
                          final idx = _selectedFileNames.indexOf(n);
                          setState(() {
                            _selectedFiles.removeAt(idx);
                            _selectedFileNames.removeAt(idx);
                          });
                        },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      )).toList()),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _sending ? null : _create,
                      child: _sending
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('إرسال طلب موافقة'),
                    ),
                  ),
                ]),
              ),
            ),
          Text('الطلبات السابقة', style: ShadTypography.sectionHeader),
          const SizedBox(height: 8),
          if (_approvals.isEmpty)
            const EmptyState(icon: Icons.check_circle_outlined, title: 'لا توجد طلبات موافقة')
          else
            ..._approvals.map((a) {
              final hasCertificate = a['certificate'] != null && a['certificate']['pdf_url'] != null;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(a['title'] ?? '', style: ShadTypography.cardTitle),
                        if (a['description'] != null) ...[
                          const SizedBox(height: 4),
                          Text(a['description'], style: ShadTypography.cardBody.copyWith(color: ShadColors.textSecondary)),
                        ],
                        const SizedBox(height: 4),
                        Text('المرجع: ${a['reference_no'] ?? ''}', style: ShadTypography.caption.copyWith(color: ShadColors.textDisabled)),
                      ])),
                      StatusBadge(status: a['status'] ?? ''),
                    ]),
                    if (hasCertificate)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: InkWell(
                          onTap: () async {
                            final url = _api.resolveFileUrl(a['certificate']['pdf_url'] as String);
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
                            Text('شهادة الموافقة', style: ShadTypography.cardBody.copyWith(color: ShadColors.primary, decoration: TextDecoration.underline)),
                          ]),
                        ),
                      ),
                    if (a['action_taken'] == true) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: a['action_result'] == 'approved' ? ShadColors.successLight : ShadColors.errorLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          Icon(
                            a['action_result'] == 'approved' ? Icons.check_circle : Icons.cancel,
                            size: 16, color: a['action_result'] == 'approved' ? ShadColors.success : ShadColors.error,
                          ),
                          const SizedBox(width: 6),
                          Expanded(child: Text(
                            a['reason'] != null ? '${a['action_result'] == 'approved' ? 'مقبول' : 'مرفوض'}: ${a['reason']}' : a['action_result'] == 'approved' ? 'تمت الموافقة' : 'تم الرفض',
                            style: ShadTypography.cardBody.copyWith(color: a['action_result'] == 'approved' ? ShadColors.success : ShadColors.error, fontSize: 12),
                          )),
                        ]),
                      ),
                      if (a['responded_at'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('تاريخ الرد: ${a['responded_at']}', style: ShadTypography.caption.copyWith(color: ShadColors.textDisabled)),
                        ),
                    ],
                    if (a['status'] == 'pending' && !isSA && a['requested_by'] != _api.userId)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(children: [
                          Row(children: [
                            Expanded(child: ElevatedButton(
                              onPressed: () => _respond(a['id'], 'approved', null),
                              style: ElevatedButton.styleFrom(backgroundColor: ShadColors.success),
                              child: const Text('موافقة'),
                            )),

                          ]),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => _showEditRequestDialog(a['id']),
                              child: const Text('✎ طلب تعديل'),
                            ),
                          ),
                        ]),
                      ),
                  ]),
                ),
              );
            }),
        ],
      ),
    );
  }
}
