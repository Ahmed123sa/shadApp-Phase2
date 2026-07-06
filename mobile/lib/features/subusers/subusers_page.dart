import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/loading_state.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/password_field.dart';

class SubUsersPage extends StatefulWidget {
  const SubUsersPage({super.key});

  @override
  State<SubUsersPage> createState() => _SubUsersPageState();
}

class _SubUsersPageState extends State<SubUsersPage> {
  final _api = ApiClient();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  List<dynamic> _subUsers = [];
  bool _loading = true;
  bool _showForm = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cid = _api.userId;
    if (cid == null) return;
    setState(() => _loading = true);
    try {
      final data = await _api.get('/clients/$cid/sub-users');
      _subUsers = data['sub_users'] as List<dynamic>? ?? [];
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (name.isEmpty || email.isEmpty || password.isEmpty) return;
    final cid = _api.userId;
    if (cid == null) return;
    setState(() => _saving = true);
    try {
      final data = await _api.post('/clients/$cid/sub-users', {
        'name': name, 'email': email, 'password': password,
      });
      _subUsers.add(data['sub_user']);
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      setState(() => _showForm = false);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل إنشاء المستخدم')));
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _delete(int id) async {
    try {
      await _api.delete('/sub-users/$id');
      setState(() => _subUsers.removeWhere((u) => u['id'] == id));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل حذف المستخدم')));
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('فريق العمل (${_subUsers.length})', style: ShadTypography.sectionHeader),
          TextButton.icon(
            onPressed: () => setState(() => _showForm = !_showForm),
            icon: Icon(_showForm ? Icons.close : Icons.person_add, size: 18),
            label: Text(_showForm ? 'إلغاء' : '+ إضافة'),
          ),
        ]),
        if (_showForm) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'الاسم', hintText: 'اسم المستخدم'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'البريد الإلكتروني', hintText: 'email@example.com'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                PasswordField(controller: _passwordController, showRequirements: false),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _create,
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('إضافة المستخدم'),
                  ),
                ),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (_subUsers.isEmpty)
          const EmptyState(icon: Icons.people_outline, title: 'لا يوجد مستخدمون تابعون')
        else
          ..._subUsers.map((u) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: ShadColors.black,
                child: Text(_initials(u['name'] as String? ?? '?'),
                    style: const TextStyle(color: ShadColors.gold, fontWeight: FontWeight.bold)),
              ),
              title: Text(u['name'] ?? '', style: ShadTypography.cardTitle),
              subtitle: Text(u['email'] ?? '', style: ShadTypography.caption.copyWith(color: ShadColors.textSecondary)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: ShadColors.error, size: 20),
                onPressed: () => _delete(u['id']),
              ),
            ),
          )),
      ],
    );
  }
}
