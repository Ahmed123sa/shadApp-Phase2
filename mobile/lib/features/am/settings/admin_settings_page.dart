import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/shad_logo.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  final _api = ApiClient();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _sigTextController = TextEditingController();
  final _boundaryKey = GlobalKey();
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];
  bool _loading = true;
  bool _saving = false;
  String _sigMode = 'draw';
  String? _existingSigUrl;
  String? _existingSigText;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _sigTextController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _api.get('/auth/me');
      final user = data['user'] as Map<String, dynamic>? ?? {};
      _emailController.text = (user['official_email'] as String? ?? '');
      _nameController.text = (user['name'] as String? ?? '');
      _avatarUrl = user['avatar_url'] as String?;

      final sigData = user['signature_data'] as String?;
      if (sigData != null && sigData.isNotEmpty) {
        if (sigData.startsWith('http') || sigData.startsWith('/storage')) {
          _existingSigUrl = sigData.startsWith('http') ? sigData : '${_api.baseUrl.replaceAll('/api', '')}$sigData';
        } else {
          _existingSigText = sigData;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      await _api.put('/auth/me', {
        'name': _nameController.text.trim(),
        'official_email': _emailController.text.trim(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم حفظ الإعدادات')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل حفظ الإعدادات')));
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    try {
      await _api.multipartPost('/auth/me', {}, file: file, fileField: 'avatar');
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم تغيير الصورة')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل تغيير الصورة')));
    }
  }

  Future<void> _saveSignature() async {
    setState(() => _saving = true);
    try {
      if (_sigMode == 'draw') {
        if (_strokes.isEmpty && _currentStroke.isEmpty) return;
        final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) return;
        final image = await boundary.toImage(pixelRatio: 3);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) return;
        final pngBytes = byteData.buffer.asUint8List();
        final dir = Directory.systemTemp;
        final file = File('${dir.path}/sig_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(pngBytes);
        await _api.multipartPost('/auth/sign', {}, file: file, fileField: 'signature_image');
      } else if (_sigMode == 'text') {
        final text = _sigTextController.text.trim();
        if (text.isEmpty) return;
        await _api.post('/auth/sign', {'signature': text});
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم حفظ التوقيع')));
        _load();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل حفظ التوقيع')));
    }
    if (mounted) setState(() => _saving = false);
  }

  void _clearStrokes() => setState(() { _strokes.clear(); _currentStroke.clear(); });

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          ShadLogo(size: 24, showText: false),
          SizedBox(width: 8),
          Text('الإعدادات'),
        ]),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: _pickAvatar,
            child: Center(
              child: CircleAvatar(
                radius: 44,
                backgroundColor: ShadColors.cardBorder,
                backgroundImage: _avatarUrl != null
                    ? NetworkImage(_api.resolveFileUrl(_avatarUrl!))
                    : null,
                child: _avatarUrl == null
                    ? const Icon(Icons.person, size: 44, color: ShadColors.textDisabled)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _pickAvatar,
              icon: const Icon(Icons.camera_alt, size: 16),
              label: const Text('تغيير الصورة الشخصية'),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'الاسم'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'البريد الإلكتروني الرسمي', hintText: 'company@example.com'),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _saveProfile,
              child: _saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('حفظ الإعدادات'),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),

          Text('التوقيع المحفوظ', style: ShadTypography.cardTitle),
          const SizedBox(height: 8),

          if (_existingSigUrl != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ShadColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ShadColors.cardBorder),
              ),
              child: Column(children: [
                const Text('التوقيع الحالي', style: TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(_existingSigUrl!, height: 60, fit: BoxFit.contain),
                ),
              ]),
            ),
          if (_existingSigText != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ShadColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ShadColors.cardBorder),
              ),
              child: Column(children: [
                const Text('التوقيع الحالي', style: TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
                const SizedBox(height: 8),
                Text(_existingSigText!, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w400, fontFamily: 'DancingScript')),
              ]),
            ),
          if (_existingSigUrl != null || _existingSigText != null) const SizedBox(height: 12),

          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _modeChip('draw', 'رسم', Icons.brush),
            const SizedBox(width: 8),
            _modeChip('text', 'نص', Icons.text_fields),
          ]),
          const SizedBox(height: 12),

          Container(
            margin: const EdgeInsets.only(bottom: 12),
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image, size: 18),
              label: const Text('📷 رفع صورة توقيع'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ShadColors.primary,
                side: const BorderSide(color: ShadColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          if (_sigMode == 'draw') ...[
            const Text('وقّع هنا', style: TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
            const SizedBox(height: 8),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: ShadColors.black,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ShadColors.cardBorder),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: GestureDetector(
                  onPanStart: (_) => setState(() => _currentStroke = []),
                  onPanUpdate: (details) => setState(() => _currentStroke.add(details.localPosition)),
                  onPanEnd: (_) => setState(() { _strokes.add(List.from(_currentStroke)); _currentStroke = []; }),
                  child: RepaintBoundary(
                    key: _boundaryKey,
                    child: CustomPaint(
                      painter: _SigPainter(strokes: _strokes, currentStroke: _currentStroke),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: _clearStrokes,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('مسح'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ShadColors.textSecondary,
                  side: const BorderSide(color: ShadColors.cardBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              )),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _saveSignature,
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle, size: 18),
                  label: const Text('حفظ التوقيع'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ShadColors.crimson,
                    foregroundColor: ShadColors.textOnCrimson,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ]),
          ],

          if (_sigMode == 'text') ...[
            const Text('اكتب اسمك', style: TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ShadColors.black,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ShadColors.cardBorder),
              ),
              child: TextField(
                controller: _sigTextController,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w400, fontFamily: 'DancingScript'),
                decoration: const InputDecoration(
                  hintText: 'اكتب توقيعك',
                  hintStyle: TextStyle(color: ShadColors.textDisabled, fontSize: 20),
                  border: InputBorder.none,
                ),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveSignature,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle, size: 18),
                label: const Text('حفظ التوقيع'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ShadColors.crimson,
                  foregroundColor: ShadColors.textOnCrimson,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    try {
      await _api.multipartPost('/auth/sign', {}, file: file, fileField: 'signature_image');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم حفظ التوقيع')));
        _load();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل حفظ التوقيع')));
    }
  }

  Widget _modeChip(String value, String label, IconData icon) {
    final selected = _sigMode == value;
    return GestureDetector(
      onTap: () => setState(() => _sigMode = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? ShadColors.crimson : ShadColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? ShadColors.crimson : ShadColors.cardBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: selected ? ShadColors.textOnCrimson : ShadColors.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: selected ? ShadColors.textOnCrimson : ShadColors.textSecondary)),
        ]),
      ),
    );
  }
}

class _SigPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;
  _SigPainter({required this.strokes, required this.currentStroke});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = ShadColors.cardBorder.withAlpha(40);
    for (double x = 0; x < size.width; x += 20) {
      for (double y = 0; y < size.height; y += 20) {
        canvas.drawCircle(Offset(x, y), 1, bgPaint);
      }
    }
    final paint = Paint()
      ..color = ShadColors.gold
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) { _drawStroke(canvas, stroke, paint); }
    _drawStroke(canvas, currentStroke, paint);
  }

  void _drawStroke(Canvas canvas, List<Offset> points, Paint paint) {
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(_SigPainter oldDelegate) => true;
}
