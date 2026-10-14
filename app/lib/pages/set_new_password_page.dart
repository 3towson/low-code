import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/app_settings.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';
import '../widgets/error_banner.dart';
import '../widgets/page_body.dart';
import 'login_page.dart';

/// หน้าตั้งรหัสผ่านใหม่ (Set New Password)
/// เปิดเมื่อได้รับ event passwordRecovery จาก Supabase Auth
/// ไม่สามารถปิดด้วย back button หรือ barrier ได้ ต้องบันทึกสำเร็จหรือกดยกเลิกเท่านั้น
class SetNewPasswordPage extends StatefulWidget {
  const SetNewPasswordPage({
    super.key,
    required this.authService,
    this.onComplete,
  });

  final AuthService authService;
  final VoidCallback? onComplete;

  @override
  State<SetNewPasswordPage> createState() => _SetNewPasswordPageState();
}

class _SetNewPasswordPageState extends State<SetNewPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      // 1. บันทึกรหัสผ่านใหม่
      await widget.authService.updatePassword(_passwordController.text);

      // 2. ให้ทุกเครื่องหลุดจากระบบ
      await widget.authService.signOut(scope: SignOutScope.global);

      widget.onComplete?.call();

      if (!mounted) return;

      // 3. แสดงข้อความสำเร็จ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.strings.setNewPasswordSuccess),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // 4. พาไปหน้า Login
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (ctx) => Scaffold(
            body: Stack(
              children: [
                LoginPage(
                  authService: widget.authService,
                  onClose: () => Navigator.of(ctx).pop(),
                ),
                const SafeArea(
                  child: Material(
                    type: MaterialType.transparency,
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: BackButton(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = authErrorMessage(e);
          _loading = false;
        });
      }
    }
  }

  Future<void> _cancel() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.authService.signOut();
    } finally {
      widget.onComplete?.call();
      if (mounted) {
        final nav = Navigator.of(context);
        if (nav.canPop()) {
          nav.popUntil((route) => route.isFirst);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final isDark = context.isDarkMode;
    final primary = Theme.of(context).colorScheme.primary;

    final cardBg = isDark ? const Color(0xFF192640) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF22304A)
        : const Color(0xFFE2E8F0);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0F172A)
            : const Color(0xFFF8FAFF),
        body: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: AmbientGlowPainter(primary: primary, isDark: isDark),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.45 : 0.12,
                              ),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Icon & Header
                              Center(
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: primary.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: primary.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.lock_reset_rounded,
                                    size: 32,
                                    color: primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                strings.setNewPasswordTitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                strings.setNewPasswordSubtitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 20),

                              if (_error != null) ...[
                                ErrorBanner(message: _error!),
                                const SizedBox(height: 16),
                              ],

                              // New Password Input
                              Text(
                                '${strings.newPasswordLabel} *',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? const Color(0xFFF1F5F9)
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                key: const Key('new-password-field'),
                                controller: _passwordController,
                                enabled: !_loading,
                                obscureText: _obscurePassword,
                                autofillHints: const [AutofillHints.newPassword],
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  hintText: '••••••••',
                                  helperText:
                                      'อย่างน้อย $minPasswordLength ตัวอักษร',
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 18,
                                  ),
                                  filled: true,
                                  fillColor: isDark
                                      ? const Color(0xFF0B1120)
                                      : const Color(0xFFF8FAFF),
                                  suffixIcon: IconButton(
                                    tooltip: _obscurePassword
                                        ? 'แสดงรหัสผ่าน'
                                        : 'ซ่อนรหัสผ่าน',
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 18,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),
                                validator: validatePassword,
                              ),
                              const SizedBox(height: 14),

                              // Confirm Password Input
                              Text(
                                '${strings.confirmNewPasswordLabel} *',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? const Color(0xFFF1F5F9)
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                key: const Key('confirm-password-field'),
                                controller: _confirmController,
                                enabled: !_loading,
                                obscureText: _obscureConfirm,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) =>
                                    _loading ? null : _submit(),
                                decoration: InputDecoration(
                                  hintText: '••••••••',
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 18,
                                  ),
                                  filled: true,
                                  fillColor: isDark
                                      ? const Color(0xFF0B1120)
                                      : const Color(0xFFF8FAFF),
                                  suffixIcon: IconButton(
                                    tooltip: _obscureConfirm
                                        ? 'แสดงรหัสผ่าน'
                                        : 'ซ่อนรหัสผ่าน',
                                    icon: Icon(
                                      _obscureConfirm
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 18,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureConfirm = !_obscureConfirm,
                                    ),
                                  ),
                                ),
                                validator: (value) => validateConfirmPassword(
                                  value,
                                  _passwordController.text,
                                ),
                              ),
                              const SizedBox(height: 22),

                              // Submit Button with Primary Gradient
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF2563EB),
                                      Color(0xFF3B82F6),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF2563EB).withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 14,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: FilledButton(
                                  key: const Key('set-new-password-submit-button'),
                                  onPressed: _loading ? null : _submit,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    minimumSize: const Size.fromHeight(48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _loading
                                      ? Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const SizedBox(
                                              height: 18,
                                              width: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              strings.savingNewPassword,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Text(
                                          strings.saveNewPassword,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Cancel Button
                              TextButton(
                                key: const Key('set-new-password-cancel-button'),
                                onPressed: _loading ? null : _cancel,
                                child: Text(
                                  strings.cancel,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
