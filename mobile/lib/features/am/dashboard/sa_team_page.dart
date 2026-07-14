import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';

class SaTeamPage extends StatefulWidget {
  const SaTeamPage({super.key});

  @override
  State<SaTeamPage> createState() => _SaTeamPageState();
}

class _SaTeamPageState extends State<SaTeamPage> {
  final _api = ApiClient();
  List<dynamic> _managers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.get('/account-managers');
      _managers = data['managers'] as List<dynamic>? ?? [];
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(children: [
                  const Text('الفريق', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: ShadColors.crimson.withAlpha(30), borderRadius: BorderRadius.circular(10)),
                    child: Text('${_managers.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'PlayfairDisplay')),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.push('/am/managers'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: ShadColors.gold.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                      child: const Row(children: [
                        Icon(Icons.settings, size: 12, color: ShadColors.gold),
                        SizedBox(width: 4),
                        Text('إدارة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'Archivo')),
                      ]),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                if (_managers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text('لا يوجد مديرين', style: TextStyle(fontSize: 13, color: ShadColors.textDisabled, fontFamily: 'Archivo'))),
                  )
                else
                  ..._managers.map((m) => _managerCard(m)),
              ],
            ),
    );
  }

  Widget _managerCard(Map<String, dynamic> manager) {
    final name = manager['name'] as String? ?? '';
    final email = manager['email'] as String? ?? '';
    final clientCount = int.tryParse(manager['managed_clients_count']?.toString() ?? '') ?? 0;
    final avatarUrl = manager['avatar_url'] as String?;
    final initials = name.isNotEmpty ? name.substring(0, name.length.clamp(0, 2)).toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ShadColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ShadColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: ShadColors.crimson,
            backgroundImage: avatarUrl != null ? NetworkImage(_api.resolveFileUrl(avatarUrl)) : null,
            child: avatarUrl == null ? Text(initials, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'Archivo')) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
              const SizedBox(height: 2),
              Text(email, style: const TextStyle(fontSize: 10, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: ShadColors.sent.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.people, size: 12, color: ShadColors.sent),
              const SizedBox(width: 4),
              Text('$clientCount', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ShadColors.sent, fontFamily: 'PlayfairDisplay')),
            ]),
          ),
        ]),
      ),
    );
  }
}
