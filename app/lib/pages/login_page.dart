import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import '../utils/validators.dart';
import '../widgets/error_banner.dart';
import '../widgets/page_body.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.authService});

  final AuthService authService;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await widget.authService.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
      // สำเร็จแล้ว AuthGate จะสลับไปหน้า Home เอง
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openSignup() async {
    final email = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => SignupPage(authService: widget.authService),
      ),
    );
    if (email != null && mounted) {
      _emailController.text = email;
      _passwordController.clear();
      setState(() => _error = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final app = AppColors.of(context);
    return Scaffold(
      body: PageBody(
        centerVertically: true,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.verified_user_rounded,
                      size: 40, color: colors.onPrimary),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'COD Check',
                textAlign: TextAlign.center,
                style: textTheme.headlineLarge?.copyWith(color: colors.primary),
              ),
              const SizedBox(height: 4),
              Text(
                'ระบบตรวจสอบประวัติลูกค้า COD',
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(color: app.muted),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'อีเมล',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                validator: validateEmail,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'รหัสผ่าน',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _loading ? null : _submit(),
                validator: validateLoginPassword,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                ErrorBanner(message: _error!),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('เข้าสู่ระบบ'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _loading ? null : _openSignup,
                child: const Text('ยังไม่มีบัญชี? สมัครสมาชิก'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
