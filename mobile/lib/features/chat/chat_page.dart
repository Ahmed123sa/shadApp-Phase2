import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../core/reverb_service.dart';
import '../../core/theme.dart';
import '../../core/widgets/chat_contract_card.dart';
import 'package:shadapp_client/generated/app_localizations.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _api = ApiClient();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<dynamic> _messages = [];
  bool _loading = true;
  bool _workspaceActive = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _checkWorkspace();
    _load();
    _startPolling();
    final wsId = _api.workspaceIdSafe;
    final reverb = ReverbService();
    reverb.onMessageReceived = (payload) {
      final msg = payload['message'] as Map<String, dynamic>?;
      if (msg != null && mounted) {
        setState(() => _messages.add(msg));
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    };
    reverb.connect(wsId);
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    final cid = _api.userId;
    if (cid != null) {
      ReverbService().connectForClient(cid);
    } else {
      ReverbService().disconnect();
    }
    super.dispose();
  }

  Future<void> _checkWorkspace() async {
    try {
      final data = await _api.get('/workspaces/${_api.workspaceIdSafe}');
      final status = (data['workspace'] as Map<String, dynamic>?)?['status'] as String? ?? '';
      if (mounted) setState(() => _workspaceActive = status == 'active');
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final data = await _api.get('/workspaces/${_api.workspaceIdSafe}/chat');
      _messages = safeList(data['messages']);
    } catch (_) {}
    if (mounted) {
      setState(() => _loading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    try {
      await _api.post('/workspaces/${_api.workspaceIdSafe}/chat', {'message': text});
      _load();
    } catch (_) {}
  }

  Future<void> _sendWithAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx', 'xls', 'xlsx'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = File(result.files.single.path!);
    try {
      await _api.multipartPost('/workspaces/${_api.workspaceIdSafe}/chat', {}, file: file, fileField: 'attachment');
      _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل إرسال المرفق')));
    }
  }

  Future<void> _approve(int contractId) async {
    try {
      await _api.post('/contracts/$contractId/client-action', {'action': 'approved'});
      _load();
    } catch (_) {}
  }

  Future<void> _respondToMessage(int msgId, String action) async {
    try {
      await _api.post('/chat/$msgId/respond', {'action': action});
      _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل تنفيذ الإجراء')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_workspaceActive) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_outline, size: 64, color: ShadColors.textDisabled),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.noMessagesYet, style: ShadTypography.cardTitle),
            const SizedBox(height: 8),
            Text('المحادثة غير متاحة — في انتظار تفعيل المساحة بعد الدفع',
                style: ShadTypography.cardBody.copyWith(color: ShadColors.textSecondary)),
          ]),
        ),
      );
    }

    return Column(children: [
      Expanded(
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _messages.isEmpty
              ? Center(child: Text(AppLocalizations.of(context)!.noMessagesYet, style: ShadTypography.cardBody.copyWith(color: ShadColors.textSecondary)))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final m = _messages[i];
                    final isClient = m['sender_type'] == 'App\\Models\\Client';
                    final isPending = m['requires_action'] == true && m['action_taken'] != true;
                    final contract = m['contract'] as Map<String, dynamic>?;
                    final hasContract = contract != null;

                    if (hasContract) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: isClient ? MainAxisAlignment.end : MainAxisAlignment.start,
                          children: [
                            if (!isClient) const SizedBox(width: 40),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: isClient ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  if (m['message'] != null && m['message'].toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(m['message'], style: ShadTypography.cardBody.copyWith(color: ShadColors.textSecondary)),
                                    ),
                                  if (m['created_at'] != null && (m['message'] != null && m['message'].toString().isNotEmpty))
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(_formatTime(m['created_at'] as String?),
                                        style: ShadTypography.chatTimestamp.copyWith(fontSize: 9, color: ShadColors.textDisabled)),
                                    ),
                                  ChatContractCard(
                                    contract: contract,
                                    isClient: isClient,
                                    onViewClauses: () {
                                      showModalBottomSheet(
                                        context: context,
                                        builder: (_) => _ClausesSheet(clauses: contract['clauses'] as List<dynamic>? ?? []),
                                      );
                                    },
                                    onApprove: isClient && contract['status'] == 'sent' ? () => _approve(contract['id']) : null,

                                  ),
                                ],
                              ),
                            ),
                            if (isClient) const SizedBox(width: 40),
                          ],
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: isClient ? MainAxisAlignment.end : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isClient) const SizedBox(width: 40),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isClient ? ShadColors.primary : ShadColors.secondary,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(isClient ? 16 : 4),
                                  bottomRight: Radius.circular(isClient ? 4 : 16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isClient && m['sender'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(m['sender']['name'] ?? '', style: ShadTypography.chatTimestamp.copyWith(color: ShadColors.primary)),
                                    ),
                                  if (m['type'] == 'file' && m['file_url'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: InkWell(
                                        onTap: () async {
                                          final url = _api.resolveFileUrl(m['file_url'] as String);
                                          final uri = Uri.tryParse(url);
                                          if (uri != null && await canLaunchUrl(uri)) {
                                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                                          } else {
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل فتح الملف')));
                                          }
                                        },
                                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                                          const Icon(Icons.attach_file, size: 16),
                                          const SizedBox(width: 4),
                                          Flexible(child: Text('📎 ${AppLocalizations.of(context)!.attachment}', style: ShadTypography.chatBubble.copyWith(color: isClient ? Colors.white70 : ShadColors.primary, decoration: TextDecoration.underline), overflow: TextOverflow.ellipsis)),
                                        ]),
                                      ),
                                    ),
                                  Text(m['message'] ?? '', style: ShadTypography.chatBubble.copyWith(color: isClient ? Colors.white : ShadColors.textPrimary)),
                                  if (m['created_at'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(_formatTime(m['created_at'] as String?),
                                        style: ShadTypography.chatTimestamp.copyWith(color: isClient ? Colors.white54 : ShadColors.textDisabled, fontSize: 9)),
                                    ),
                                  if (isPending)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text('🏷️ ${AppLocalizations.of(context)!.pendingYourApproval}', style: ShadTypography.chatTimestamp.copyWith(color: ShadColors.warning)),
                                        const SizedBox(height: 4),
                                        Row(mainAxisSize: MainAxisSize.min, children: [
                                          _actionChip('موافقة', ShadColors.success, () => _respondToMessage(m['id'], 'approved')),
                                          const SizedBox(width: 4),
                                          _actionChip('تعديل', ShadColors.warning, () => _respondToMessage(m['id'], 'edit_requested')),

                                        ]),
                                      ]),
                                    ),
                                  if (m['action_taken'] == true)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        m['action_result'] == 'approved' ? '✅ ${AppLocalizations.of(context)!.approved}' : m['action_result'] == 'rejected' ? '❌ ${AppLocalizations.of(context)!.rejected}' : '✎ ${AppLocalizations.of(context)!.editRequested}',
                                        style: ShadTypography.chatTimestamp.copyWith(
                                          color: m['action_result'] == 'approved' ? ShadColors.success : m['action_result'] == 'rejected' ? ShadColors.error : ShadColors.warning,
                                        ),
                                      ),
                                    ),
                                  if (m['approval']?['certificate']?['pdf_url'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: InkWell(
                                        onTap: () async {
                                          final url = _api.resolveFileUrl(m['approval']['certificate']['pdf_url'] as String);
                                          final uri = Uri.tryParse(url);
                                          if (uri != null && await canLaunchUrl(uri)) {
                                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                                          } else {
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل فتح الملف')));
                                          }
                                        },
                                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                                          const Icon(Icons.picture_as_pdf, size: 14, color: ShadColors.error),
                                          const SizedBox(width: 4),
                                          Text('📄 تحميل شهادة الموافقة', style: ShadTypography.chatTimestamp.copyWith(color: ShadColors.primary, decoration: TextDecoration.underline)),
                                        ]),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (isClient) const SizedBox(width: 40),
                        ],
                      ),
                    );
                  },
                ),
      ),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: ShadColors.card, border: const Border(top: BorderSide(color: ShadColors.divider))),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.attach_file, size: 22),
            onPressed: _sendWithAttachment,
            color: ShadColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.typeMessage,
                filled: true,
                fillColor: ShadColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: ShadColors.primary,
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              onPressed: _send,
            ),
          ),
        ]),
      ),
    ]);
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (_) { return ''; }
  }

  Widget _actionChip(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color, fontFamily: 'Archivo')),
      ),
    );
  }
}

class _ClausesSheet extends StatelessWidget {
  final List<dynamic> clauses;
  const _ClausesSheet({required this.clauses});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(AppLocalizations.of(context)!.contractClauses, style: ShadTypography.cardTitle),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ]),
          const SizedBox(height: 12),
          if (clauses.isEmpty)
            Text(AppLocalizations.of(context)!.noClauses, style: ShadTypography.cardBody.copyWith(color: ShadColors.textSecondary))
          else
            ...clauses.map((cl) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.circle, size: 6, color: ShadColors.textDisabled),
                const SizedBox(width: 8),
                Expanded(child: Text(cl['content'] ?? '', style: ShadTypography.cardBody)),
              ]),
            )),
        ],
      ),
    );
  }
}
