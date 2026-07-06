import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/shad_logo.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _api = ApiClient();
  bool _passwordVisible = false;
  String? _error;
  bool _loading = false;
  Future<void> _login() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() => _error = 'يرجى إدخال البريد الإلكتروني وكلمة المرور');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final body = {
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
      };

      Map<String, dynamic> data;
      bool isClient = false;

      try {
        data = await _api.post('/auth/login', body);
      } on Exception {
        data = await _api.post('/auth/client/login', body);
        isClient = true;
      }

      await _api.setToken(data['token']);

      if (isClient) {
        await _api.setRole('client');
        final client = data['client'] as Map<String, dynamic>;
        final wsId = data['workspace_id'] as int?;
        await _api.setUserData(id: client['id'], name: client['company_name'], workspace: wsId);
      } else {
        final user = data['user'] as Map<String, dynamic>;
        final role = user['role'] as String;
        await _api.setRole(role);
        await _api.setUserData(id: user['id'], name: user['name']);
      }

      if (!mounted) return;
      context.go(isClient ? '/dashboard' : '/am/dashboard');
    } on AuthException {
      setState(() => _error = 'انتهت الجلسة — يرجى المحاولة مرة أخرى');
    } on ValidationException catch (e) {
      setState(() => _error = e.message);
    } on ServerException {
      setState(() => _error = 'حدث خطأ في الخادم — حاول لاحقاً');
    } catch (_) {
      setState(() => _error = 'بيانات الدخول غير صحيحة');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.2,
            colors: [Color(0x26141414), Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const ShadLogo(size: 96),
                const SizedBox(height: 12),
                Text(isAr ? 'مرحباً بعودتك' : 'Welcome back', style: isAr
                  ? TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'Amiri', height: 1.3)
                  : ShadTypography.largeTitle.copyWith(fontSize: 30, color: ShadColors.textPrimary, fontFamily: 'PlayfairDisplay')),
                const SizedBox(height: 32),

                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: ShadColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ShadColors.cardBorder),
                  ),
                    child: Column(children: [
                    // d-motif corner
                    SizedBox(
                      height: 0,
                      child: Stack(children: [
                        Positioned(
                          top: -24, right: -24,
                          child: Opacity(
                            opacity: 0.1,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Container(width: 48, height: 2, color: ShadColors.crimson),
                              const SizedBox(height: 2),
                              Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: ShadColors.gold)),
                            ]),
                          ),
                        ),
                      ]),
                    ),

                    const SizedBox(height: 24),

                    if (_error != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(color: ShadColors.errorLight, borderRadius: BorderRadius.circular(8)),
                        child: Text(_error!, style: ShadTypography.cardBody.copyWith(color: ShadColors.error)),
                      ),

                    // Email
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(isAr ? 'البريد الإلكتروني' : 'Email Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: ShadColors.textSecondary, fontFamily: isAr ? 'NotoSansArabic' : 'Archivo')),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          hintText: 'example@domain.com',
                          suffixIcon: Icon(Icons.mail_outline, size: 20, color: ShadColors.textSecondary),
                          filled: true,
                          fillColor: ShadColors.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // Password
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(isAr ? 'كلمة المرور' : 'Password', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: ShadColors.textSecondary, fontFamily: isAr ? 'NotoSansArabic' : 'Archivo')),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          suffixIcon: IconButton(
                            icon: Icon(_passwordVisible ? Icons.visibility_off : Icons.visibility, size: 20),
                            onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                          ),
                          filled: true,
                          fillColor: ShadColors.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                        obscureText: !_passwordVisible,
                        textDirection: TextDirection.ltr,
                        onSubmitted: (_) => _login(),
                      ),
                    ]),
                    const SizedBox(height: 12),

                    // Forgot password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        child: Text(isAr ? 'نسيت كلمة المرور؟' : 'Forgot Password?', style: TextStyle(fontSize: 12, color: ShadColors.gold, fontFamily: isAr ? 'NotoSansArabic' : 'Archivo')),
                      ),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ShadColors.crimson,
                          foregroundColor: ShadColors.textOnCrimson,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _loading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text(isAr ? 'تسجيل الدخول' : 'Sign In', style: ShadTypography.buttonLabel),
                              const SizedBox(width: 8),
                              const Icon(Icons.login, size: 18),
                            ]),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Divider
                    Row(children: [
                      const Expanded(child: Divider(color: ShadColors.cardBorder)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(isAr ? 'أو' : 'or', style: TextStyle(fontSize: 12, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
                      ),
                      const Expanded(child: Divider(color: ShadColors.cardBorder)),
                    ]),
                    const SizedBox(height: 16),

                    // Social
                    Row(children: [
                      Expanded(child: _socialButton(Icons.g_mobiledata_rounded, 'Google')),
                      const SizedBox(width: 12),
                      Expanded(child: _socialButton(Icons.apple, 'Apple')),
                    ]),
                  ]),
                ),

                const SizedBox(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(isAr ? 'ليس لديك حساب؟' : "Don't have an account?", style: TextStyle(fontSize: 12, color: ShadColors.textSecondary, fontFamily: isAr ? 'NotoSansArabic' : 'Archivo')),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: Text(isAr ? 'طلب دخول' : 'Request Access', style: TextStyle(fontSize: 12, color: ShadColors.gold, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('SECURE', style: TextStyle(fontSize: 10, letterSpacing: 2, color: ShadColors.textDisabled.withAlpha(100))),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('•', style: TextStyle(color: ShadColors.textDisabled.withAlpha(100)))),
                  Text('INSTITUTIONAL', style: TextStyle(fontSize: 10, letterSpacing: 2, color: ShadColors.textDisabled.withAlpha(100))),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('•', style: TextStyle(color: ShadColors.textDisabled.withAlpha(100)))),
                  Text('COMPLIANT', style: TextStyle(fontSize: 10, letterSpacing: 2, color: ShadColors.textDisabled.withAlpha(100))),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _socialButton(IconData icon, String label) {
    return OutlinedButton(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        foregroundColor: ShadColors.textSecondary,
        side: const BorderSide(color: ShadColors.cardBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Icon(icon, size: 20),
    );
  }
}
