import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import '../utils/validators.dart';
import '../widgets/error_banner.dart';
import '../widgets/page_body.dart';

/// สมัครสำเร็จแล้ว pop กลับหน้า Login พร้อมคืนอีเมลที่สมัคร
class SignupPage extends StatefulWidget {
  const SignupPage({super.key, required this.authService});

  final AuthService authService;

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _shopNameController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _shopNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await widget.authService.signUp(
        email: _emailController.text,
        password: _passwordController.text,
        shopName: _shopNameController.text,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = authErrorMessage(e);
          _loading = false;
        });
      }
      return;
    }
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('สมัครสมาชิกสำเร็จ'),
        content: const Text('กรุณายืนยันอีเมลก่อนเข้าสู่ระบบ'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop(_emailController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final app = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: PageBody(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('สมัครสมาชิก', style: textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                'สร้างบัญชีร้านค้าเพื่อเริ่มตรวจสอบลูกค้า',
                style: textTheme.bodyLarge?.copyWith(color: app.muted),
              ),
              const SizedBox(height: AppSpacing.section),
              TextFormField(
                controller: _shopNameController,
                decoration: const InputDecoration(
                  labelText: 'ชื่อร้าน',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
                textInputAction: TextInputAction.next,
                validator: validateShopName,
              ),
              const SizedBox(height: 16),
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
                  helperText: 'อย่างน้อย $minPasswordLength ตัวอักษร',
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
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                validator: validatePassword,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmController,
                decoration: const InputDecoration(
                  labelText: 'ยืนยันรหัสผ่าน',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _loading ? null : _submit(),
                validator: (value) =>
                    validateConfirmPassword(value, _passwordController.text),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                ErrorBanner(message: _error!),
              ],
              const SizedBox(height: AppSpacing.section),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('สมัครสมาชิก'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
