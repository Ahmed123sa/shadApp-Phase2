import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';

class SaClientsPage extends StatefulWidget {
  const SaClientsPage({super.key});

  @override
  State<SaClientsPage> createState() => _SaClientsPageState();
}

class _SaClientsPageState extends State<SaClientsPage> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _allClients = [];
  bool _loading = true;
  int _filterIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.get('/clients');
      final clients = safeList(data['clients']);
      _allClients = clients.cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filteredClients {
    switch (_filterIndex) {
      case 1: return _allClients.where((c) => (c['workspace'] as Map<String, dynamic>?)?['status'] == 'active').toList();
      case 2: return _allClients.where((c) => c['signed_at'] == null).toList();
      case 3: return _allClients.where((c) => c['signed_at'] != null && (c['workspace'] as Map<String, dynamic>?)?['status'] != 'active').toList();
      default: return _allClients;
    }
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
                  const Text('العملاء', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: ShadColors.crimson.withAlpha(30), borderRadius: BorderRadius.circular(10)),
                    child: Text('${_allClients.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'PlayfairDisplay')),
                  ),
                ]),
                const SizedBox(height: 12),
                _buildPillsFilter(),
                const SizedBox(height: 12),
                if (_filteredClients.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text('لا يوجد عملاء', style: TextStyle(fontSize: 13, color: ShadColors.textDisabled, fontFamily: 'Archivo'))),
                  )
                else
                  ..._filteredClients.map((c) => _clientCard(c)),
              ],
            ),
    );
  }

  Widget _buildPillsFilter() {
    final active = _allClients.where((c) => (c['workspace'] as Map<String, dynamic>?)?['status'] == 'active').length;
    final pending = _allClients.where((c) => c['signed_at'] == null).length;
    final review = _allClients.where((c) => c['signed_at'] != null && (c['workspace'] as Map<String, dynamic>?)?['status'] != 'active').length;
    final filters = [
      ('الكل', _allClients.length),
      ('نشط', active),
      ('بانتظار', pending),
      ('مراجعة', review),
    ];
    return Row(
      children: filters.asMap().entries.map((entry) {
        final i = entry.key;
        final (label, count) = entry.value;
        final activeFilter = _filterIndex == i;
        return Padding(
          padding: const EdgeInsets.only(left: 6),
          child: GestureDetector(
            onTap: () => setState(() => _filterIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: activeFilter ? ShadColors.gold.withAlpha(25) : ShadColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: activeFilter ? ShadColors.gold : ShadColors.cardBorder),
              ),
              child: Text('$label ($count)', style: TextStyle(fontSize: 11, fontWeight: activeFilter ? FontWeight.w700 : FontWeight.w500, color: activeFilter ? ShadColors.gold : ShadColors.textSecondary, fontFamily: 'Archivo')),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _clientCard(Map<String, dynamic> client) {
    final ws = client['workspace'] as Map<String, dynamic>?;
    final wsActive = ws?['status'] == 'active';
    final name = client['company_name'] as String? ?? '';
    final person = client['contact_person'] as String? ?? '';
    final signedAt = client['signed_at'] as String?;
    final initials = name.isNotEmpty ? name.substring(0, name.length.clamp(0, 2)).toUpperCase() : '?';

    return GestureDetector(
      onTap: () => _openClient(client),
      child: Container(
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
              child: Text(initials, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'Archivo')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
                const SizedBox(height: 2),
                Text(person, style: const TextStyle(fontSize: 10, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (wsActive ? ShadColors.success : signedAt == null ? ShadColors.gold : ShadColors.sent).withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                wsActive ? 'نشط' : signedAt == null ? 'بانتظار' : 'مراجعة',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: wsActive ? ShadColors.success : signedAt == null ? ShadColors.gold : ShadColors.sent, fontFamily: 'Archivo'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _openClient(Map<String, dynamic> client) async {
    final ws = client['workspace'] as Map<String, dynamic>?;
    if (ws == null) {
      try {
        final created = await _api.post('/workspaces', {'client_id': client['id']});
        final newWs = created['workspace'] as Map<String, dynamic>;
        await _api.setUserData(id: client['id'], name: client['company_name'], workspace: newWs['id']);
        if (!mounted) return;
        context.push('/am/workspace/${newWs['id']}');
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل إنشاء مساحة العمل')));
      }
      return;
    }
    await _api.setUserData(id: client['id'], name: client['company_name'], workspace: ws['id']);
    if (!mounted) return;
    context.push('/am/workspace/${ws['id']}');
  }
}
