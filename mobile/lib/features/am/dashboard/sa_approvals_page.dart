import 'package:flutter/material.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';

class SaApprovalsPage extends StatefulWidget {
  const SaApprovalsPage({super.key});

  @override
  State<SaApprovalsPage> createState() => _SaApprovalsPageState();
}

class _SaApprovalsPageState extends State<SaApprovalsPage> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _contracts = [];
  List<Map<String, dynamic>> _payments = [];
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
      _contracts = await _fetchContracts(['sent', 'client_approved']);
      try {
        final pData = await _api.get('/payments/pending');
        final raw = pData['payments'] as List<dynamic>? ?? [];
        _payments = raw.cast<Map<String, dynamic>>();
      } catch (_) {
        _payments = [];
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<List<Map<String, dynamic>>> _fetchContracts(List<String> statuses) async {
    final results = <Map<String, dynamic>>[];
    try {
      final data = await _api.get('/clients');
      final clients = _safeList(data['clients']);
      for (final client in clients) {
        final ws = client['workspace'] as Map<String, dynamic>?;
        if (ws == null) continue;
        try {
          final contractsData = await _api.get('/workspaces/${ws['id']}/contracts');
          final contracts = _safeList(contractsData['contracts']);
          for (final c in contracts) {
            if (statuses.contains(c['status'])) {
              results.add({
                'title': c['title'] ?? '',
                'value': c['value'] ?? 0,
                'company': client['company_name'] ?? '',
                'client': client,
                'type': 'contract',
              });
            }
          }
        } catch (_) {
          continue;
        }
      }
    } catch (_) {}
    return results;
  }

  List<dynamic> _safeList(dynamic v) => v is List ? v : [];

  List<Map<String, dynamic>> get _filteredItems {
    switch (_filterIndex) {
      case 1: return _contracts;
      case 2: return _payments.cast<Map<String, dynamic>>();
      default: return [..._contracts, ..._payments.cast<Map<String, dynamic>>()];
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _contracts.length + _payments.length;
    return RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(children: [
                  Text('الموافقات المعلّقة', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: ShadColors.crimson.withAlpha(30), borderRadius: BorderRadius.circular(10)),
                    child: Text('$total', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'PlayfairDisplay')),
                  ),
                ]),
                const SizedBox(height: 12),
                _buildPillsFilter(total),
                const SizedBox(height: 12),
                if (_filteredItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text('لا توجد موافقات معلّقة', style: TextStyle(fontSize: 13, color: ShadColors.textDisabled, fontFamily: 'Archivo'))),
                  )
                else
                  ..._filteredItems.map((item) => _approvalCard(item)),
              ],
            ),
    );
  }

  Widget _buildPillsFilter(int total) {
    final filters = [
      ('الكل', total),
      ('عقود', _contracts.length),
      ('دفعات', _payments.length),
    ];
    return Row(
      children: filters.asMap().entries.map((entry) {
        final i = entry.key;
        final (label, count) = entry.value;
        final active = _filterIndex == i;
        return Padding(
          padding: const EdgeInsets.only(left: 6),
          child: GestureDetector(
            onTap: () => setState(() => _filterIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: active ? ShadColors.gold.withAlpha(25) : ShadColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: active ? ShadColors.gold : ShadColors.cardBorder),
              ),
              child: Text('$label ($count)', style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? ShadColors.gold : ShadColors.textSecondary, fontFamily: 'Archivo')),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _approvalCard(Map<String, dynamic> item) {
    final isContract = item['type'] == 'contract';
    final title = isContract ? 'اعتماد عقد — ${item['title']}' : 'اعتماد دفعة — ${item['company'] ?? ''}';
    final subtitle = isContract
        ? '${item['company']} • ${(item['value'] as num?)?.toInt() ?? 0} ج.م'
        : '${item['currency'] ?? ''} ${(item['amount'] as num?)?.toDouble().toStringAsFixed(0) ?? '0'}';

    return GestureDetector(
      onTap: () => _showDetail(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: ShadColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ShadColors.cardBorder),
        ),
        child: Row(children: [
          Container(
            width: 3,
            height: 56,
            decoration: BoxDecoration(
              color: isContract ? ShadColors.gold : ShadColors.sent,
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'Archivo'))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isContract ? ShadColors.gold : ShadColors.sent).withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(isContract ? 'عقد' : 'دفعة', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: isContract ? ShadColors.gold : ShadColors.sent, fontFamily: 'Archivo')),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  void _showDetail(Map<String, dynamic> item) {
    final isContract = item['type'] == 'contract';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.3,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: ShadColors.cardBorder, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(isContract ? 'تفاصيل العقد' : 'تفاصيل الدفعة', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
              const SizedBox(height: 16),
              _detailRow('العنوان', item['title'] ?? ''),
              _detailRow('الشركة', item['company'] ?? ''),
              if (isContract)
                _detailRow('القيمة', '${(item['value'] as num?)?.toInt() ?? 0} ج.م')
              else ...[
                _detailRow('المبلغ', '${item['currency'] ?? ''} ${(item['amount'] as num?)?.toDouble().toStringAsFixed(0) ?? '0'}'),
                _detailRow('طريقة الدفع', item['method_type'] ?? ''),
              ],
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: ShadColors.gold, foregroundColor: ShadColors.background),
                    child: const Text('اعتماد', style: TextStyle(fontFamily: 'Archivo')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: ShadColors.error)),
                    child: const Text('رفض', style: TextStyle(color: ShadColors.error, fontFamily: 'Archivo')),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Text(label, style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
        const Spacer(),
        Flexible(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ShadColors.textPrimary, fontFamily: 'Archivo'), textAlign: TextAlign.end)),
      ]),
    );
  }
}
