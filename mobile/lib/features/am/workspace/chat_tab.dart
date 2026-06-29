import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api_client.dart';
import '../../../core/reverb_service.dart';
import '../../../core/theme.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/widgets/chat_contract_card.dart';
import '../widgets/contract_builder.dart';

class ChatTab extends StatefulWidget {
  final String? wsStatus;
  const ChatTab({super.key, this.wsStatus});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final _api = ApiClient();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<dynamic> _messages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    final wsId = _api.workspaceId;
    if (wsId != null) {
      final reverb = ReverbService();
      reverb.onMessageReceived = (payload) {
        final msg = payload['message'] as Map<String, dynamic>?;
        if (msg != null && mounted) {
          setState(() => _messages.add(msg));
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        }
      };
      reverb.onContractStatusChanged = () {
        if (mounted) _load();
      };
      reverb.connect(wsId);
    }
  }

  Future<void> _load() async {
    final wsId = _api.workspaceId;
    if (wsId == null) return;
    try {
      final data = await _api.get('/workspaces/$wsId/chat');
      _messages = data['messages'] as List<dynamic>? ?? [];
    } catch (_) {}
    if (mounted) {
      setState(() => _loading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _api.workspaceId == null) return;
    _controller.clear();
    try {
      await _api.post('/workspaces/${_api.workspaceId}/chat', {'message': text});
      _load();
    } catch (_) {}
  }

  Future<void> _requireAction(int msgId) async {
    if (_api.workspaceId == null) return;
    try {
      await _api.patch('/chat/$msgId/require-action', {});
      _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل طلب الموافقة')));
    }
  }

  void _showMessageActions(dynamic m) {
    final isSA = _api.role == 'super_admin';
    if (isSA || m['sender_type'] == 'App\\Models\\Client') return;
    final alreadyRequested = m['requires_action'] == true;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (!alreadyRequested)
            ListTile(
              leading: const Icon(Icons.how_to_reg, color: ShadColors.primary),
              title: const Text('طلب موافقة العميل'),
              subtitle: const Text('سيُطلب من العميل الموافقة على هذه الرسالة'),
              onTap: () {
                Navigator.pop(ctx);
                _requireAction(m['id']);
              },
            )
          else
            const ListTile(
              leading: Icon(Icons.check_circle, color: ShadColors.success),
              title: Text('تم طلب الموافقة مسبقاً'),
            ),
          ListTile(
            leading: const Icon(Icons.info_outline, color: ShadColors.textSecondary),
            title: const Text('تفاصيل الرسالة'),
            subtitle: Text('${m['message'] ?? '(بدون نص)'}'),
            onTap: () => Navigator.pop(ctx),
          ),
        ]),
      ),
    );
  }

  Future<void> _sendWithAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx', 'xls', 'xlsx'],
    );
    if (result == null || result.files.isEmpty || _api.workspaceId == null) return;
    final file = File(result.files.single.path!);
    try {
      await _api.multipartPost('/workspaces/${_api.workspaceId}/chat', {}, file: file, fileField: 'attachment');
      _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل إرسال المرفق')));
    }
  }

  Widget _contractBubble(dynamic m, Map<String, dynamic> contract, bool isClient) {
    return Column(
      crossAxisAlignment: isClient ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (m['message'] != null && m['message'].toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(m['message'], style: ShadTypography.cardBody.copyWith(color: ShadColors.textSecondary)),
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
        ),
      ],
    );
  }

  Widget _textBubble(dynamic m, bool isClient, bool isPending) {
    final sender = m['sender'] as Map<String, dynamic>?;
    final senderAvatarUrl = sender?['avatar_url'] as String?;
    final senderName = sender?['name'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isClient ? ShadColors.primaryLight : ShadColors.secondary,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isClient ? 4 : 16),
          bottomRight: Radius.circular(isClient ? 16 : 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sender != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: ShadColors.cardBorder,
                    backgroundImage: senderAvatarUrl != null
                        ? NetworkImage(_api.resolveFileUrl(senderAvatarUrl))
                        : null,
                    child: senderAvatarUrl == null
                        ? Text(senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ShadColors.textPrimary))
                        : null,
                  ),
                  const SizedBox(width: 6),
                  Text(senderName, style: ShadTypography.chatTimestamp.copyWith(color: ShadColors.primary)),
                ],
              ),
            ),
          if (m['type'] == 'file' && m['file_url'] != null)
            InkWell(
              onTap: () async {
                final url = _api.resolveFileUrl(m['file_url'] as String);
                final uri = Uri.tryParse(url);
                final messenger = ScaffoldMessenger.of(context);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  messenger.showSnackBar(const SnackBar(content: Text('فشل فتح الملف')));
                }
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.attach_file, size: 16),
                    const SizedBox(width: 4),
                    Flexible(child: Text('📎 ${AppLocalizations.of(context)!.attachment}', style: ShadTypography.chatBubble.copyWith(color: ShadColors.textPrimary), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            ),
          Text(m['message'] ?? '', style: ShadTypography.chatBubble.copyWith(color: isClient ? ShadColors.textPrimary : ShadColors.textPrimary)),
          if (isPending)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('🏷️ ${AppLocalizations.of(context)!.waitingClientApproval}', style: ShadTypography.chatTimestamp.copyWith(color: ShadColors.warning)),
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
                  final messenger = ScaffoldMessenger.of(context);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    messenger.showSnackBar(const SnackBar(content: Text('فشل فتح الملف')));
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
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    final uid = _api.userId;
    if (uid != null) {
      ReverbService().connectForUser(uid);
    } else {
      ReverbService().disconnect();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSA = _api.role == 'super_admin';

    if (widget.wsStatus == null || widget.wsStatus != 'active') {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock, size: 48, color: ShadColors.textDisabled),
              SizedBox(height: 16),
              Text('المحادثة غير متاحة — بانتظار تفعيل مساحة العمل',
                style: TextStyle(fontSize: 14, color: ShadColors.textSecondary),
                textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Column(children: [
      Expanded(
        child: _loading
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 4,
              itemBuilder: (_, __) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 200,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: ShadColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: ShadColors.cardBorder)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(height: 14, width: 140, decoration: BoxDecoration(color: ShadColors.cardBorder, borderRadius: BorderRadius.circular(6))),
                      const SizedBox(height: 8),
                      Container(height: 12, width: 100, decoration: BoxDecoration(color: ShadColors.cardBorder, borderRadius: BorderRadius.circular(6))),
                    ]),
                  ),
                ),
              ),
            )
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

                    final showActions = !isClient && _api.role != 'super_admin';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: isClient ? MainAxisAlignment.end : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isClient) const SizedBox(width: 40),
                          Flexible(
                            child: GestureDetector(
                              onLongPress: showActions ? () => _showMessageActions(m) : null,
                              child: hasContract
                                ? _contractBubble(m, contract, isClient)
                                : _textBubble(m, isClient, isPending),
                            ),
                          ),
                          if (isClient) const SizedBox(width: 40),
                        ],
                      ),
                    );
                  },
                ),
      ),
      if (isSA)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: ShadColors.card, border: const Border(top: BorderSide(color: ShadColors.divider))),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.visibility, size: 16, color: ShadColors.textSecondary),
            SizedBox(width: 8),
            Text('عرض المحادثة فقط', style: TextStyle(fontSize: 12, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
          ]),
        ),
      if (!isSA)
        Container(
          decoration: BoxDecoration(color: ShadColors.card, border: const Border(top: BorderSide(color: ShadColors.divider))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => ContractBuilder.show(context, onCreated: _load, isAdditional: true),
                  icon: const Icon(Icons.description, size: 18),
                  label: const Text('📄 إرسال عقد خدمة إضافية'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ShadColors.primary,
                    side: const BorderSide(color: ShadColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
          ]),
        ),
    ]);
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
