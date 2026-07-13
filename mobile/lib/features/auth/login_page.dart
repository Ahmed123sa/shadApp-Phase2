import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../core/locale_provider.dart';
import '../../core/theme.dart';

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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.language, size: 20),
                  onPressed: () => LocaleProvider().toggle(),
                  tooltip: 'تغيير اللغة',
                ),
              ),
              const SizedBox(height: 16),
              // Logo
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(text: 'd', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'Archivo')),
                    TextSpan(text: '.SHAD', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'PlayfairDisplay')),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              if (_error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: ShadColors.errorLight, borderRadius: BorderRadius.circular(8)),
                  child: Text(_error!, style: TextStyle(fontSize: 12, color: ShadColors.error, fontFamily: isAr ? 'NotoSansArabic' : 'Archivo')),
                ),

              // Email
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isAr ? 'البريد الإلكتروني' : 'Email',
                  style: TextStyle(fontSize: 11, color: ShadColors.textSecondary, fontFamily: isAr ? 'NotoSansArabic' : 'Archivo')),
                const SizedBox(height: 6),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    hintText: 'example@domain.com',
                    filled: true,
                    fillColor: ShadColors.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: ShadColors.gold)),
                  ),
                  style: TextStyle(fontSize: 13, color: ShadColors.textPrimary),
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                ),
              ]),
              const SizedBox(height: 14),

              // Password
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isAr ? 'كلمة المرور' : 'Password',
                  style: TextStyle(fontSize: 11, color: ShadColors.textSecondary, fontFamily: isAr ? 'NotoSansArabic' : 'Archivo')),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: ShadColors.gold)),
                  ),
                  style: TextStyle(fontSize: 13, color: ShadColors.textPrimary),
                  obscureText: !_passwordVisible,
                  textDirection: TextDirection.ltr,
                  onSubmitted: (_) => _login(),
                ),
              ]),
              const SizedBox(height: 18),

              // Sign In
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ShadColors.crimson,
                    foregroundColor: ShadColors.textOnCrimson,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text(isAr ? 'تسجيل الدخول' : 'Sign In',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, fontFamily: isAr ? 'NotoSansArabic' : 'Archivo')),
                ),
              ),
              const SizedBox(height: 16),

              // Forgot password
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: Text(isAr ? 'نسيت كلمة المرور؟' : 'Forgot Password?',
                  style: TextStyle(fontSize: 11, color: ShadColors.textSecondary, fontFamily: isAr ? 'NotoSansArabic' : 'Archivo')),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
