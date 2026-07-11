import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/loading_state.dart';
import '../../core/widgets/empty_state.dart';

class ClientFilesPage extends StatefulWidget {
  const ClientFilesPage({super.key});

  @override
  State<ClientFilesPage> createState() => _ClientFilesPageState();
}

class _ClientFilesPageState extends State<ClientFilesPage> {
  final _api = ApiClient();
  List<dynamic> _files = [];
  List<dynamic> _definitions = [];
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final wsId = _api.workspaceId;
    if (wsId == null) return;
    setState(() => _loading = true);
    try {
      final data = await _api.get('/workspaces/$wsId/files');
      _files = safeList(data['files']);
      _definitions = safeList(data['definitions']);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _upload() async {
    if (_definitions.isEmpty) {
      await _pickAndUpload(null);
      return;
    }
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        int? selectedDef;
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('اختر تعريف المستند', style: ShadTypography.cardTitle),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 12),
              ..._definitions.map((d) {
                final isSelected = selectedDef == d['id'];
                return ListTile(
                  leading: Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: isSelected ? ShadColors.crimson : ShadColors.textDisabled,
                  ),
                  title: Text('${d['name']}${d['is_required'] == true ? ' *' : ''}',
                      style: ShadTypography.cardBody),
                  onTap: () => setSheetState(() => selectedDef = d['id'] as int),
                );
              }),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _pickAndUpload(selectedDef);
                  },
                  child: const Text('اختيار ورفع'),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUpload(int? definitionId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = File(result.files.single.path!);
    final wsId = _api.workspaceId;
    if (wsId == null) return;

    setState(() => _uploading = true);
    try {
      final fields = <String, dynamic>{};
      if (definitionId != null) fields['document_definition_id'] = definitionId;
      await _api.multipartPost('/workspaces/$wsId/files', fields, file: file);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل رفع الملف: $e')));
    }
    if (mounted) setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_definitions.isNotEmpty) ...[
          Text('تعريفات المستندات', style: ShadTypography.sectionHeader),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: _definitions.map<Widget>((d) =>
            Chip(
              label: Text('${d['name']}${d['is_required'] == true ? ' *' : ''}',
                  style: ShadTypography.caption.copyWith(color: ShadColors.textPrimary)),
              backgroundColor: ShadColors.card,
              side: BorderSide(color: d['is_required'] == true ? ShadColors.gold : ShadColors.cardBorder),
            ),
          ).toList()),
          const SizedBox(height: 16),
        ],
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('الملفات المرفوعة', style: ShadTypography.sectionHeader),
          TextButton.icon(
            onPressed: _uploading ? null : _upload,
            icon: _uploading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.upload_file, size: 18),
            label: Text(_uploading ? 'جاري الرفع...' : 'رفع ملف'),
          ),
        ]),
        const SizedBox(height: 8),
        if (_files.isEmpty)
          const EmptyState(icon: Icons.folder_outlined, title: 'لا توجد ملفات')
        else
          ..._files.map((f) {
            final status = f['status'] as String? ?? 'pending';
            final statusColor = status == 'approved'
                ? ShadColors.success
                : status == 'rejected'
                    ? ShadColors.error
                    : ShadColors.warning;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: f['file_url'] != null ? () async {
                  final url = _api.resolveFileUrl(f['file_url'] as String);
                  final uri = Uri.tryParse(url);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل فتح الملف')));
                  }
                } : null,
                leading: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: ShadColors.gold.withAlpha(38),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.attach_file, size: 18, color: ShadColors.gold),
                ),
                title: Text(f['name'] ?? '', style: ShadTypography.cardTitle, overflow: TextOverflow.ellipsis),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (f['definition_name'] != null)
                    Text(f['definition_name'], style: ShadTypography.caption.copyWith(color: ShadColors.primary)),
                  if (f['size'] != null)
                    Text('${(f['size'] / 1024).toStringAsFixed(0)} KB',
                        style: ShadTypography.caption.copyWith(color: ShadColors.textSecondary)),
                  if (f['rejection_reason'] != null)
                    Text('سبب الرفض: ${f['rejection_reason']}',
                        style: ShadTypography.caption.copyWith(color: ShadColors.error)),
                ]),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabels[status] ?? status,
                    style: ShadTypography.caption.copyWith(color: statusColor),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}
