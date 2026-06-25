import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _api = ApiClient();
  final _nameController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cid = _api.userId;
    if (cid == null) return;
    try {
      final data = await _api.get('/clients/$cid');
      final client = data['client'] as Map<String, dynamic>? ?? {};
      _nameController.text = (client['contact_person'] as String? ?? '');
      _avatarUrl = client['avatar_url'] as String?;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    final cid = _api.userId;
    if (cid == null) return;
    try {
      await _api.multipartPost('/clients/$cid/profile', {}, file: file, fileField: 'avatar');
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم تغيير الصورة')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل تغيير الصورة')));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final cid = _api.userId;
    if (cid == null) return;
    try {
      await _api.put('/clients/$cid/profile', {'contact_person': _nameController.text.trim()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم الحفظ')));
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل الحفظ')));
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات'),),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: _pickAvatar,
            child: Center(
              child: CircleAvatar(
                radius: 52,
                backgroundColor: ShadColors.cardBorder,
                backgroundImage: _avatarUrl != null
                    ? NetworkImage(_api.resolveFileUrl(_avatarUrl!))
                    : null,
                child: _avatarUrl == null
                    ? const Icon(Icons.person, size: 52, color: ShadColors.textDisabled)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _pickAvatar,
              icon: const Icon(Icons.camera_alt, size: 16),
              label: const Text('تغيير الصورة الشخصية'),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'اسمك الظاهر',
              hintText: 'الاسم الذي سيظهر في الشات',
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('حفظ'),
            ),
          ),
        ],
      ),
    );
  }
}
