import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/loading_state.dart';
import '../../core/widgets/error_state.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  final _api = ApiClient();
  List<dynamic> _payments = [];
  List<dynamic> _contracts = [];
  List<String> _availableMethods = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all';
  Timer? _refreshTimer;

  static const _currencies = ['SAR', 'USD', 'EUR', 'AED', 'EGP', 'KWD', 'QAR', 'BHD', 'OMR'];
  static const _currencyLabels = {
    'SAR': 'ريال سعودي', 'USD': 'دولار أمريكي', 'EUR': 'يورو',
    'AED': 'درهم إماراتي', 'EGP': 'جنيه مصري', 'KWD': 'دينار كويتي',
    'QAR': 'ريال قطري', 'BHD': 'دينار بحريني', 'OMR': 'ريال عماني',
  };

  String _currency(dynamic p) => p['currency'] as String? ?? 'SAR';

  @override
  void initState() {
    super.initState();
    _load();
    _startRefresh();
  }

  void _startRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  double get _totalPaid {
    return _payments
        .where((p) => p['status'] == 'approved')
        .fold<double>(0, (sum, p) => sum + (num.tryParse(p['amount']?.toString() ?? '')?.toDouble() ?? 0));
  }

  Future<void> _load() async {
    final wsId = _api.workspaceId;
    if (wsId == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.get('/workspaces/$wsId/payments');
      _payments = safeList(data['payments']);
      _availableMethods = (data['available_methods'] as List<dynamic>?)?.cast<String>() ?? [];
    } catch (_) {
      _error = 'فشل تحميل المدفوعات';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadContractsForSuggest() async {
    final wsId = _api.workspaceId;
    if (wsId == null) return;
    try {
      final data = await _api.get('/workspaces/$wsId/contracts');
      _contracts = safeList(data['contracts']);
    } catch (_) {}
  }

  Map<String, dynamic>? get _suggestedContract {
    return _contracts.cast<Map<String, dynamic>?>().firstWhere(
      (c) => c?['status'] == 'company_approved',
      orElse: () => null,
    );
  }

  List<dynamic> get _filteredPayments {
    if (_filter == 'all') return _payments;
    return _payments.where((p) => p['status'] == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    return RefreshIndicator(
      onRefresh: () async { await _load(); await _loadContractsForSuggest(); },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ShadColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ShadColors.cardBorder),
            ),
            child: Column(children: [
              Text('Total Paid', style: TextStyle(fontSize: 12, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
              const SizedBox(height: 8),
              Text('${_totalPaid.toStringAsFixed(2)} ${_payments.isNotEmpty ? _currency(_payments.first) : 'SAR'}', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'PlayfairDisplay')),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _payments.isNotEmpty ? _totalPaid / _payments.fold<double>(0, (s, p) => s + (num.tryParse(p['amount']?.toString() ?? '')?.toDouble() ?? 0)) : 0,
                  minHeight: 6,
                  backgroundColor: ShadColors.cardBorder,
                  valueColor: const AlwaysStoppedAnimation(ShadColors.gold),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          Row(children: [
            Expanded(child: _quickAction(Icons.add_circle, 'Request Payment')),
          ]),
          const SizedBox(height: 20),

          Row(children: [
            _filterChip('All', 'all'),
            const SizedBox(width: 8),
            _filterChip('Approved', 'approved'),
            const SizedBox(width: 8),
            _filterChip('Pending', 'pending'),
            const SizedBox(width: 8),
            _filterChip('Rejected', 'rejected'),
          ]),
          const SizedBox(height: 12),

          if (_filteredPayments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(children: [
                const Icon(Icons.payment_outlined, size: 48, color: ShadColors.textDisabled),
                const SizedBox(height: 12),
                Text('No payments yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
              ]),
            )
          else
            ..._filteredPayments.map((p) => _paymentCard(p)),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? ShadColors.crimson : ShadColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? ShadColors.crimson : ShadColors.cardBorder),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: selected ? ShadColors.textOnCrimson : ShadColors.textSecondary)),
      ),
    );
  }

  void _showRequestPaymentSheet() {
    const methodLabels = {
      'bank_transfer': 'تحويل بنكي',
      'swift': 'تحويل SWIFT',
      'corporate_account': 'حساب الشركة',
      'instapay': 'InstaPay',
      'vodafone_cash': 'Vodafone Cash',
      'mobile_wallet': 'محفظة إلكترونية',
    };

    final available = _availableMethods.isNotEmpty ? _availableMethods : methodLabels.keys.toList();
    final amountCtrl = TextEditingController();
    final selectedMethod = ValueNotifier<String>(available.first);
    final selectedCurrency = ValueNotifier<String>('SAR');
    File? selectedFile;
    bool uploading = false;

    final methods = <String, String>{
      for (final k in available) k: methodLabels[k] ?? k,
    };

    // Auto-suggest: find first company_approved contract
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadContractsForSuggest();
      if (!mounted) return;
      final suggested = _suggestedContract;
      if (suggested != null && _payments.where((p) => p['status'] == 'pending').isEmpty) {
        amountCtrl.text = suggested['value'].toString();
      }
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('طلب دفعة', style: ShadTypography.cardTitle),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
            ]),
            const SizedBox(height: 16),
            ValueListenableBuilder<String>(
              valueListenable: selectedCurrency,
              builder: (_, cur, __) => TextField(
                controller: amountCtrl,
                decoration: InputDecoration(labelText: 'المبلغ *', hintText: '0.00', prefixText: '$cur '),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<String>(
              valueListenable: selectedCurrency,
              builder: (_, cur, __) => DropdownButtonFormField<String>(
                initialValue: cur,
                decoration: const InputDecoration(labelText: 'العملة'),
                items: _currencies.map((c) => DropdownMenuItem(
                  value: c,
                  child: Text('$c — ${_currencyLabels[c] ?? ''}'),
                )).toList(),
                onChanged: (v) { if (v != null) selectedCurrency.value = v; },
              ),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<String>(
              valueListenable: selectedMethod,
              builder: (_, val, __) => DropdownButtonFormField<String>(
                initialValue: val,
                decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                items: methods.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: (v) { if (v != null) selectedMethod.value = v; },
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: false);
                    if (r != null && r.files.isNotEmpty) {
                      setSheetState(() => selectedFile = File(r.files.first.path!));
                    }
                  },
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: Text(selectedFile != null ? 'تم اختيار الملف' : 'إرفاق إثبات الدفع'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  final r = await ImagePicker().pickImage(source: ImageSource.camera);
                  if (r != null) {
                    setSheetState(() => selectedFile = File(r.path));
                  }
                },
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                child: const Icon(Icons.camera_alt, size: 18),
              ),
            ]),
            if (_suggestedContract != null) ...[
              const SizedBox(height: 8),
              Text('مقترح من عقد: ${_suggestedContract!['title']}', style: TextStyle(fontSize: 10, color: ShadColors.textDisabled, fontFamily: 'Archivo')),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: uploading ? null : () async {
                  final amount = double.tryParse(amountCtrl.text);
                  if (amount == null || amount <= 0) {
                    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('يرجى إدخال مبلغ صحيح')));
                    return;
                  }
                  final wsId = _api.workspaceId;
                  if (wsId == null) {
                    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('مساحة العمل غير متاحة')));
                    return;
                  }
                  setSheetState(() => uploading = true);
                  try {
                    final fields = <String, dynamic>{'amount': amount, 'currency': selectedCurrency.value, 'method_type': selectedMethod.value};
                    if (selectedFile != null) {
                      await _api.multipartPost('/workspaces/$wsId/payments', fields, file: selectedFile, fileField: 'proof_file');
                    } else {
                      await _api.post('/workspaces/$wsId/payments', fields);
                    }
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('✅ تم إرسال طلب الدفعة')));
                      Navigator.pop(ctx);
                    }
                    await _load();
                  } catch (_) {
                    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('فشل إرسال الدفعة')));
                  }
                  if (ctx.mounted) setSheetState(() => uploading = false);
                },
                child: uploading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('إرسال الدفعة'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _quickAction(IconData icon, String label) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: label == 'Request Payment' ? _showRequestPaymentSheet : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: ShadColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ShadColors.cardBorder),
        ),
        child: Column(children: [
          Icon(icon, size: 24, color: ShadColors.gold),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
        ]),
      ),
    );
  }

  Widget _paymentCard(dynamic p) {
    final statusColors = {'pending': ShadColors.gold, 'approved': ShadColors.success, 'rejected': ShadColors.error};
    final sc = statusColors[p['status']] ?? ShadColors.textDisabled;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ShadColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ShadColors.cardBorder),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: sc.withAlpha(25), borderRadius: BorderRadius.circular(10)),
          child: Icon(
            p['status'] == 'approved' ? Icons.check_circle : p['status'] == 'rejected' ? Icons.cancel : Icons.hourglass_empty,
            color: sc, size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${p['amount'] ?? 0} ${_currency(p)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
            Text(p['method_type'] ?? '', style: TextStyle(fontSize: 11, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
            if (p['contract_title'] != null) ...[
              const SizedBox(height: 2),
              Text(p['contract_title'], style: TextStyle(fontSize: 10, color: ShadColors.textDisabled, fontFamily: 'Archivo')),
            ],
            if (p['proof_file_url'] != null)
              InkWell(
                onTap: () async {
                  final url = _api.resolveFileUrl(p['proof_file_url'] as String);
                  final uri = Uri.tryParse(url);
                  final messenger = ScaffoldMessenger.of(context);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    messenger.showSnackBar(const SnackBar(content: Text('فشل فتح الملف')));
                  }
                },
                child: Text('📎 إثبات الدفع', style: TextStyle(fontSize: 10, color: ShadColors.primary, fontFamily: 'NotoSansArabic', decoration: TextDecoration.underline)),
              ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: sc.withAlpha(25), borderRadius: BorderRadius.circular(20)),
          child: Text(
            statusLabels[p['status']] ?? p['status'] ?? '',
            style: TextStyle(fontSize: 10, color: sc, fontWeight: FontWeight.w500, fontFamily: 'Archivo'),
          ),
        ),
      ]),
    );
  }
}
