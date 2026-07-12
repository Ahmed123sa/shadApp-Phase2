import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/locale_provider.dart';
import '../../core/reverb_service.dart';
import '../../core/widgets/shad_logo.dart';

class ClientOnboardingScreen extends StatefulWidget {
  const ClientOnboardingScreen({super.key});

  @override
  State<ClientOnboardingScreen> createState() => _ClientOnboardingScreenState();
}

class _ClientOnboardingScreenState extends State<ClientOnboardingScreen> with WidgetsBindingObserver {
  final _api = ApiClient();

  Map<String, dynamic>? _client;
  Map<String, dynamic>? _workspace;
  bool _loading = true;
  String? _error;
  int _lastStage = 0;
  bool _autoAdvancing = false;
  StreamSubscription? _fcmSubscription;
  final ValueNotifier<int> _contractRefreshNotifier = ValueNotifier<int>(0);

  int _computeStage() {
    final client = _client;
    final ws = _workspace;
    if (client == null || ws == null) return 0;
    final contractsList = safeList(ws['contracts']);
    final paymentsList = safeList(ws['payments']);
    final wsStatus = ws['status'] as String? ?? '';
    if (wsStatus == 'active') return 6;
    if (paymentsList.any((p) => p is Map && p['status'] == 'approved')) return 5;
    if (contractsList.any((c) => c is Map && c['status'] == 'completed')) return 4;
    if (contractsList.any((c) => c is Map && c['status'] == 'archived')) return 4;
    if (contractsList.any((c) => c is Map && c['status'] == 'company_approved')) return 4;
    if (contractsList.any((c) => c is Map && c['status'] == 'client_approved')) return 3;
    if (contractsList.any((c) => c is Map && c['status'] == 'edit_requested')) return 2;
    if (contractsList.any((c) => c is Map && c['status'] == 'sent')) return 2;
    if (client['signed_at'] != null) return 1;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _loadClientData();
    _setupRealtimeNotifications();
    WidgetsBinding.instance.addObserver(this);
  }

  void _setupRealtimeNotifications() {
    final cid = _api.userId;
    if (cid == null) return;
    final reverb = ReverbService();
    reverb.connectForClient(cid);
    reverb.onNotificationReceived = (payload) {
      _loadClientData();
      _contractRefreshNotifier.value++;
      if (!mounted) return;
      final msg = (payload['data'] as Map?)?['message'] as String? ?? (payload['data'] as Map?)?['text'] as String? ?? 'إشعار جديد';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 13)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ));
    };
    reverb.onContractStatusChanged = () {
      _loadClientData();
      _contractRefreshNotifier.value++;
    };
    _fcmSubscription = FirebaseMessaging.onMessage.listen((msg) {
      final type = msg.data['type'] as String? ?? '';
      if (type == 'contract.company_approved' || type == 'contract.completed' || type == 'payment.approved') {
        _loadClientData();
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      _loadClientData();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadClientData();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fcmSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadClientData() async {
    final cid = _api.userId;
    if (cid == null) return;
    try {
      final data = await _api.get('/clients/$cid');
      _client = data['client'] as Map<String, dynamic>?;
      _workspace = data['client']?['workspace'] as Map<String, dynamic>?;
      if (_workspace != null) {
        final wsId = _workspace!['id'] as int?;
        if (wsId != null && wsId != _api.workspaceId) {
          await _api.setUserData(workspace: wsId);
        }
      }
      _checkAutoAdvance();
    } catch (e) {
      _error = 'فشل تحميل البيانات';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _checkAutoAdvance() {
    if (_autoAdvancing) return;
    final currentStage = _computeStage();
    if (currentStage > _lastStage && currentStage > 0) {
      _autoAdvancing = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _autoAdvancing = false;
      });
    }
    _lastStage = currentStage;
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تسجيل خروج')),
        ],
      ),
    );
    if (confirm == true) {
      await _api.clearToken();
      if (!mounted) return;
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, size: 64, color: ShadColors.error),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: ShadColors.textPrimary, fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadClientData, child: const Text('إعادة المحاولة')),
            ]),
          ),
        ),
      );
    }

    final stage = _computeStage();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(stage),
            Expanded(child: _buildStageScreen(stage)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int stage) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          const ShadLogo(size: 28, showText: false),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 22),
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.language, size: 20),
            onPressed: () => LocaleProvider().toggle(),
            tooltip: 'تغيير اللغة',
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 22),
            onPressed: _logout,
            tooltip: 'تسجيل الخروج',
          ),
        ],
      ),
    );
  }

  Widget _buildStageScreen(int stage) {
    switch (stage) {
      case 0:
        return _buildSignatureStage();
      case 1:
        return _buildWaitingStage(
          icon: Icons.downloading,
          iconColor: ShadColors.sent,
          title: 'بانتظار استلام العقد',
          subtitle: 'سيتم إرسال العقد إليك للتوقيع قريباً',
        );
      case 2:
        return _buildContractReviewStage();
      case 3:
        return _buildWaitingStage(
          icon: Icons.verified,
          iconColor: ShadColors.companyApproved,
          title: 'بانتظار اعتماد الشركة',
          subtitle: 'يقوم فريق الشركة بمراجعة طلبك',
        );
      case 4:
        return _buildPaymentStage();
      case 5:
        return _buildWaitingStage(
          icon: Icons.payment,
          iconColor: ShadColors.warning,
          title: 'بانتظار اعتماد الدفع',
          subtitle: 'يقوم فريق الشركة بمراجعة إثبات الدفع',
        );
      case 6:
        return _buildSuccessStage();
      default:
        return _buildSignatureStage();
    }
  }

  Widget _buildSignatureStage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: ShadColors.gold.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.auto_fix_high, size: 36, color: ShadColors.gold),
          ),
          const SizedBox(height: 24),
          const Text(
            'مرحباً بك في شاد آب',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'PlayfairDisplay'),
          ),
          const SizedBox(height: 12),
Text(
  'يرجى إضافة توقيعك الإلكتروني للبدء',
  style: TextStyle(fontSize: 14, color: ShadColors.textSecondary),
),
const SizedBox(height: 8),
Text(
  'من فضلك قم بإضافة توقيعك الإلكتروني للبدء في استخدام المساحة الخاصة بك',
  style: TextStyle(fontSize: 12, color: ShadColors.textDisabled),
  textAlign: TextAlign.center,
),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await context.push('/signature');
                _loadClientData();
              },
              icon: const Icon(Icons.draw, size: 20),
              label: const Text('التوقيع الآن'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ShadColors.crimson,
                foregroundColor: ShadColors.textOnCrimson,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingStage({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 36, color: iconColor),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'PlayfairDisplay'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: ShadColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          const SizedBox(
            width: 40, height: 40,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 32),
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.headset_mic, size: 18),
            label: const Text('تواصل مع الدعم'),
            style: TextButton.styleFrom(foregroundColor: ShadColors.textSecondary),
          ),
        ]),
      ),
    );
  }

  Widget _buildContractReviewStage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: ShadColors.approved.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.description, size: 36, color: ShadColors.approved),
          ),
          const SizedBox(height: 24),
          const Text(
            'تم استلام العقد',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'PlayfairDisplay'),
          ),
          const SizedBox(height: 12),
          Text(
            'يرجى مراجعة العقد وإبداء موافقتك',
            style: TextStyle(fontSize: 14, color: ShadColors.textSecondary),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                final ws = _workspace;
                if (ws != null) {
                  final contracts = safeList(ws['contracts']);
                  if (contracts.isNotEmpty) {
                    final c = contracts.first as Map;
                    _showContractModal(c);
                  }
                }
              },
              icon: const Icon(Icons.visibility, size: 20),
              label: const Text('معاينة العقد'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ShadColors.gold,
                side: const BorderSide(color: ShadColors.gold),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _respondToContract('approved'),
              icon: const Icon(Icons.thumb_up, size: 20),
              label: const Text('موافقة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ShadColors.crimson,
                foregroundColor: ShadColors.textOnCrimson,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _respondToContract('edit_requested'),
            icon: const Icon(Icons.edit_note, size: 18),
            label: const Text('طلب تعديل'),
            style: TextButton.styleFrom(foregroundColor: ShadColors.textSecondary),
          ),
        ],
      ),
    );
  }

  void _showContractModal(Map c) {
    final status = c['status'] as String? ?? '';
    final needsAction = status == 'sent';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c['title'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'PlayfairDisplay')),
                  const SizedBox(height: 4),
                  Text('#${c['id'] ?? ''}', style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
                ]),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
            const SizedBox(height: 16),
            if (c['value'] != null)
              Text('${c['value']} ${c['currency'] as String? ?? 'SAR'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'PlayfairDisplay')),
            const SizedBox(height: 8),
            if (c['start_date'] != null)
              Text('تاريخ البداية: ${(c['start_date'] as String).split('T')[0]}', style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
            if (c['end_date'] != null)
              Text('تاريخ الإنتهاء: ${(c['end_date'] as String).split('T')[0]}', style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
            const SizedBox(height: 16),
            if (c['pdf_url'] != null) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final url = _api.resolveFileUrl(c['pdf_url'] as String);
                    final uri = Uri.tryParse(url);
                    if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: const Text('تحميل العقد (PDF)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ShadColors.gold,
                    side: const BorderSide(color: ShadColors.gold),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (needsAction) ...[
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () { Navigator.pop(context); _respondToContract('approved'); },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('موافقة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ShadColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () { Navigator.pop(context); _respondToContract('edit_requested'); },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('تعديل'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ShadColors.warning,
                      side: const BorderSide(color: ShadColors.warning),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _respondToContract(String action) async {
    final ws = _workspace;
    if (ws == null) return;
    final contracts = safeList(ws['contracts']);
    if (contracts.isEmpty) return;
    final c = contracts.first as Map;
    final contractId = c['id'];
    String? reason;
    if (action == 'edit_requested') {
      final controller = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('التعديلات المطلوبة'),
          content: TextField(controller: controller, maxLines: 3, decoration: const InputDecoration(hintText: 'اذكر التعديلات المطلوبة...')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('تأكيد')),
          ],
        ),
      );
      if (reason == null) return;
    }
    try {
      final body = <String, dynamic>{'action': action};
      if (reason != null && reason.isNotEmpty) body['reason'] = reason;
      await _api.post('/contracts/$contractId/client-action', body);
      _loadClientData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(action == 'approved' ? '✅ تمت الموافقة على العقد' : '📝 تم إرسال طلب التعديل'),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل: $e')));
      }
    }
  }

  Widget _buildPaymentStage() {
    final ws = _workspace;
    double totalAmount = 0;
    if (ws != null) {
      final contracts = safeList(ws['contracts']);
      for (final c in contracts) {
        if (c is Map) {
          totalAmount += (c['value'] as num? ?? 0).toDouble();
        }
      }
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: ShadColors.warning.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.payment, size: 36, color: ShadColors.warning),
          ),
          const SizedBox(height: 24),
          const Text(
            'إتمام الدفع',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'PlayfairDisplay'),
          ),
          const SizedBox(height: 12),
          Text(
            'يرجى تأكيد الدفع لتفعيل مساحة العمل',
            style: TextStyle(fontSize: 14, color: ShadColors.textSecondary, fontFamily: 'NotoSansArabic'),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ShadColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ShadColors.gold.withAlpha(60)),
            ),
            child: Column(children: [
              Text(
                'المبلغ الإجمالي',
                style: TextStyle(fontSize: 12, color: ShadColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                '$totalAmount ريال',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'PlayfairDisplay'),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await context.push('/workspaces/${ws?['id']}/payments');
                _loadClientData();
              },
              icon: const Icon(Icons.check_circle, size: 20),
              label: const Text('تأكيد الدفع'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ShadColors.crimson,
                foregroundColor: ShadColors.textOnCrimson,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessStage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: ShadColors.success.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.check_circle, size: 36, color: ShadColors.success),
          ),
          const SizedBox(height: 24),
          const Text(
            'مساحة العمل جاهزة!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'PlayfairDisplay'),
          ),
          const SizedBox(height: 12),
          Text(
            'تم تفعيل مساحة العمل الخاصة بك بنجاح',
            style: TextStyle(fontSize: 14, color: ShadColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'يمكنك الآن البدء في استخدام جميع الخدمات',
            style: TextStyle(fontSize: 12, color: ShadColors.textDisabled),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _loadClientData();
              },
              icon: const Icon(Icons.arrow_forward, size: 20),
              label: const Text('الدخول إلى مساحة العمل'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ShadColors.crimson,
                foregroundColor: ShadColors.textOnCrimson,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

List safeList(dynamic value) {
  if (value is List) return value;
  if (value is String) return [];
  return [];
}
