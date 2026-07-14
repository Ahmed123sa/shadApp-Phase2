import 'package:flutter/material.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/shad_logo.dart';
import '../../../core/widgets/password_field.dart';

class AccountManagersPage extends StatefulWidget {
  const AccountManagersPage({super.key});

  @override
  State<AccountManagersPage> createState() => _AccountManagersPageState();
}

class _AccountManagersPageState extends State<AccountManagersPage> {
  final _api = ApiClient();
  List<dynamic> _managers = [];
  bool _loading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _errorMsg = null; });
    try {
      final data = await _api.get('/account-managers');
      _managers = data['managers'] as List<dynamic>? ?? [];
    } catch (e) {
      _errorMsg = 'فشل تحميل المديرين';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _showForm({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(text: existing?['name'] as String? ?? '');
    final emailCtrl = TextEditingController(text: existing?['email'] as String? ?? '');
    final phoneCtrl = TextEditingController(text: existing?['phone'] as String? ?? '');
    final passwordCtrl = TextEditingController();
    bool autoPassword = existing == null;
    bool isEdit = existing != null;

    await showDialog(
      context: context,
      builder: (ctx) {
        bool saving = false;
        String? errorMsg;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(isEdit ? 'تعديل مدير' : 'إضافة مدير حساب جديد'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (errorMsg != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: ShadColors.errorLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(errorMsg ?? '', style: const TextStyle(color: ShadColors.error, fontSize: 12)),
                  ),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'الاسم', hintText: 'Mohamed Ali'),
                  enabled: !saving,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'البريد الإلكتروني', hintText: 'manager@domain.com'),
                  keyboardType: TextInputType.emailAddress,
                  enabled: !saving,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'رقم الهاتف', hintText: '+966501234567'),
                  keyboardType: TextInputType.phone,
                  enabled: !saving,
                ),
                if (!isEdit) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    const Text('كلمة المرور: ', style: TextStyle(fontSize: 14)),
                    const Spacer(),
                    FilterChip(
                      label: const Text('تلقائي', style: TextStyle(fontSize: 12)),
                      selected: autoPassword,
                      onSelected: saving ? null : (_) => setDialogState(() => autoPassword = true),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('يدوي', style: TextStyle(fontSize: 12)),
                      selected: !autoPassword,
                      onSelected: saving ? null : (_) => setDialogState(() => autoPassword = false),
                    ),
                  ]),
                  if (!autoPassword) ...[
                    const SizedBox(height: 12),
                    PasswordField(controller: passwordCtrl),
                  ],
                ],
                if (isEdit) ...[
                  const SizedBox(height: 12),
                  PasswordField(
                    controller: passwordCtrl,
                    labelText: 'كلمة المرور الجديدة',
                    hintText: 'اتركه فارغاً لعدم التغيير',
                    required: false,
                  ),
                ],
              ]),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (nameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty) {
                          setDialogState(() => errorMsg = 'الاسم والبريد الإلكتروني مطلوبان');
                          return;
                        }
                        setDialogState(() { saving = true; errorMsg = null; });
                        try {
                          if (isEdit) {
                            final payload = <String, dynamic>{
                              'name': nameCtrl.text.trim(),
                              'email': emailCtrl.text.trim(),
                              'phone': phoneCtrl.text.trim(),
                            };
                            if (passwordCtrl.text.trim().isNotEmpty) {
                              payload['password'] = passwordCtrl.text.trim();
                            }
                            await _api.put('/account-managers/${existing['id']}', payload);
                          } else {
                            final payload = <String, dynamic>{
                              'name': nameCtrl.text.trim(),
                              'email': emailCtrl.text.trim(),
                              'phone': phoneCtrl.text.trim(),
                            };
                            if (!autoPassword) {
                              payload['password'] = passwordCtrl.text.trim();
                            }
                            await _api.post('/account-managers', payload);
                          }
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          _load();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(isEdit ? 'تم تحديث المدير' : 'تم إنشاء المدير'),
                          ));
                        } catch (e) {
                          final msg = e is ValidationException || e is AuthException || e is ServerException
                              ? e.toString()
                              : (isEdit ? 'فشل تحديث المدير' : 'فشل إنشاء المدير');
                          setDialogState(() { saving = false; errorMsg = msg; });
                        }
                      },
                child: saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text(isEdit ? 'تحديث' : 'إضافة'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _delete(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف مدير'),
        content: Text('هل أنت متأكد من حذف "$name"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.delete('/account-managers/$id');
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل حذف المدير')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ShadLogo(size: 24, showText: false),
            const SizedBox(width: 8),
            const Text('إدارة المديرين', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, fontFamily: 'PlayfairDisplay')),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => _showForm()),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _errorMsg != null
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_errorMsg!, style: const TextStyle(color: ShadColors.error)),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _load, child: const Text('إعادة المحاولة')),
              ]),
            )
          : _managers.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.people_outline, size: 56, color: ShadColors.textDisabled),
                  const SizedBox(height: 16),
                  const Text('لا يوجد مديرين بعد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ShadColors.textPrimary)),
                  const SizedBox(height: 8),
                  const Text('اضغط على + لإضافة مدير جديد', style: TextStyle(fontSize: 14, color: ShadColors.textSecondary)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showForm(),
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('إضافة مدير'),
                  ),
                ]),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _managers.length,
                  itemBuilder: (_, i) {
                    final m = _managers[i] as Map<String, dynamic>;
                    final name = m['name'] as String? ?? '';
                    final email = m['email'] as String? ?? '';
                    final mgrId = int.tryParse(m['id']?.toString() ?? '') ?? 0;
                    final clientCount = int.tryParse(m['managed_clients_count']?.toString() ?? '') ?? 0;
                    final phone = m['phone'] as String?;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: ShadColors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ShadColors.cardBorder),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: ShadColors.black,
                          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(color: ShadColors.textPrimary, fontWeight: FontWeight.bold, fontFamily: 'Archivo')),
                        ),
                        title: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('$email · $clientCount عميل', style: TextStyle(fontSize: 11, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
                          if (phone != null && phone.isNotEmpty)
                            Text(phone, style: TextStyle(fontSize: 10, color: ShadColors.textDisabled, fontFamily: 'Archivo')),
                        ]),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20, color: ShadColors.gold),
                            onPressed: () => _showForm(existing: m),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20, color: ShadColors.error),
                            onPressed: () => _delete(mgrId, name),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
              ),
    );
  }
}
