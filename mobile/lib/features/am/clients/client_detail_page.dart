import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/password_field.dart';

class ClientDetailPage extends StatefulWidget {
  final int clientId;
  const ClientDetailPage({super.key, required this.clientId});

  @override
  State<ClientDetailPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends State<ClientDetailPage> {
  final _api = ApiClient();
  final _nameCtrl = TextEditingController();
  final _personCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _industryCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  DateTime? _dateOfBirth;
  bool _loading = true;
  bool _saving = false;
  String? _avatarUrl;
  String? _status;
  List<dynamic> _subUsers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _personCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _countryCtrl.dispose();
    _industryCtrl.dispose();
    _passwordCtrl.dispose();
    _dateOfBirthController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _api.get('/clients/${widget.clientId}');
      final client = data['client'] as Map<String, dynamic>? ?? {};
      _nameCtrl.text = (client['company_name'] as String? ?? '');
      _personCtrl.text = (client['contact_person'] as String? ?? '');
      _phoneCtrl.text = (client['phone'] as String? ?? '');
      _countryCtrl.text = (client['country'] as String? ?? '');
      _industryCtrl.text = (client['industry'] as String? ?? '');
      _dateOfBirthController.text = (client['date_of_birth'] as String? ?? '');
      _emailCtrl.text = (client['email'] as String? ?? '');
      _status = client['status'] as String? ?? 'inactive';
      _avatarUrl = client['avatar_url'] as String?;
      _subUsers = client['sub_users'] as List<dynamic>? ?? [];
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    try {
      await _api.multipartPost('/clients/${widget.clientId}/profile', {}, file: file, fileField: 'avatar');
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم تغيير الصورة')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل تغيير الصورة: $e')));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _api.put('/clients/${widget.clientId}', {
        'company_name': _nameCtrl.text.trim(),
        'contact_person': _personCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'country': _countryCtrl.text.trim(),
        'industry': _industryCtrl.text.trim(),
        if (_dateOfBirth != null) 'date_of_birth': _dateOfBirth!.toIso8601String(),
        if (_passwordCtrl.text.trim().isNotEmpty) 'password': _passwordCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم حفظ التعديلات')));
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
      appBar: AppBar(
        centerTitle: true,
        title: const Text('تعديل العميل', style: TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 18, fontWeight: FontWeight.w700, color: ShadColors.gold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickAvatar,
              child: CircleAvatar(
                radius: 44,
                backgroundColor: ShadColors.crimson,
                backgroundImage: _avatarUrl != null
                    ? NetworkImage(_api.resolveFileUrl(_avatarUrl!))
                    : null,
                child: _avatarUrl == null
                    ? const Icon(Icons.business, size: 44, color: ShadColors.gold)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _pickAvatar,
              icon: const Icon(Icons.camera_alt, size: 16, color: ShadColors.gold),
              label: const Text('تغيير الصورة', style: TextStyle(color: ShadColors.gold)),
            ),
          ),
          const SizedBox(height: 16),

          TextField(controller: _emailCtrl, decoration: InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: const Icon(Icons.email, size: 18, color: ShadColors.gold), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: ShadColors.gold))), keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr),
          const SizedBox(height: 12),

          if (_status != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _status == 'active' ? ShadColors.success.withAlpha(25) : ShadColors.textDisabled.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _status == 'active' ? 'نشط' : 'غير نشط',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _status == 'active' ? ShadColors.success : ShadColors.textDisabled),
              ),
            ),
          const SizedBox(height: 16),

          TextField(controller: _nameCtrl, decoration: InputDecoration(labelText: 'اسم الشركة', prefixIcon: const Icon(Icons.business, size: 18, color: ShadColors.gold), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: ShadColors.gold)))),
          const SizedBox(height: 12),
          TextField(controller: _personCtrl, decoration: InputDecoration(labelText: 'الشخص المسؤول', prefixIcon: const Icon(Icons.person, size: 18, color: ShadColors.gold), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: ShadColors.gold)))),
          const SizedBox(height: 12),
          TextField(controller: _phoneCtrl, decoration: InputDecoration(labelText: 'رقم الهاتف', prefixIcon: const Icon(Icons.phone, size: 18, color: ShadColors.gold), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: ShadColors.gold))), keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          TextField(controller: _countryCtrl, decoration: InputDecoration(labelText: 'البلد', prefixIcon: const Icon(Icons.location_on, size: 18, color: ShadColors.gold), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: ShadColors.gold)))),
          const SizedBox(height: 12),
          TextField(controller: _industryCtrl, decoration: InputDecoration(labelText: 'المجال', prefixIcon: const Icon(Icons.work, size: 18, color: ShadColors.gold), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: ShadColors.gold)))),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _dateOfBirth ?? DateTime(2000),
                firstDate: DateTime(1950),
                lastDate: DateTime.now(),
              );
              if (d != null) setState(() {
                _dateOfBirth = d;
                _dateOfBirthController.text = '${d.year}/${d.month}/${d.day}';
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'تاريخ الميلاد',
                prefixIcon: const Icon(Icons.calendar_today, size: 18, color: ShadColors.gold),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: ShadColors.gold)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_dateOfBirthController.text.isNotEmpty ? _dateOfBirthController.text : 'اختر التاريخ',
                      style: TextStyle(fontSize: 14, color: _dateOfBirthController.text.isNotEmpty ? ShadColors.textPrimary : ShadColors.textDisabled)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Divider(),
          const SizedBox(height: 8),
          Text('إعادة تعيين كلمة المرور', style: ShadTypography.cardTitle),
          const SizedBox(height: 8),
          PasswordField(
            controller: _passwordCtrl,
            labelText: 'كلمة مرور جديدة',
            hintText: 'اتركه فارغاً إذا لم ترد التغيير',
            required: false,
          ),
          const SizedBox(height: 16),

          if (_subUsers.isNotEmpty) ...[
            const Divider(),
            const SizedBox(height: 8),
            Text('المستخدمين الفرعيين', style: ShadTypography.cardTitle),
            const SizedBox(height: 8),
            ..._subUsers.map((su) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ShadColors.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ShadColors.cardBorder),
              ),
              child: Row(children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: ShadColors.cardBorder,
                  child: Text(
                    (su['name'] as String? ?? '?')[0].toUpperCase(),
                    style: const TextStyle(color: ShadColors.textPrimary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(su['name'] ?? '', style: const TextStyle(color: ShadColors.textPrimary))),
                Text(su['email'] ?? '', style: const TextStyle(color: ShadColors.textSecondary, fontSize: 12)),
              ]),
            )),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: ShadColors.crimson),
              child: _saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('حفظ التعديلات'),
            ),
          ),
        ],
      ),
    );
  }
}
