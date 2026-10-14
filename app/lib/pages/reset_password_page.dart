import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/app_settings.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';
import '../widgets/error_banner.dart';
import '../widgets/page_body.dart';
import 'login_page.dart';

/// หน้า "ลืมรหัสผ่าน" แบบ 3 ขั้นตอนในหน้าเดียว:
/// ขั้น 1: กรอกอีเมล → resetPassword → ไปขั้น 2
/// ขั้น 2: กรอกรหัส 6 หลักจากอีเมล → verifyRecoveryCode → ไปขั้น 3
/// ขั้น 3: ตั้งรหัสผ่านใหม่ + ยืนยัน → updatePassword → signOut(global) → Login
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    required this.authService,
    this.initialEmail,
    this.initialStep = 1,
    this.onComplete,
  });

  final AuthService authService;
  final String? initialEmail;
  final int initialStep;
  final VoidCallback? onComplete;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  late int _step = widget.initialStep;
  late final TextEditingController _emailController =
      TextEditingController(text: widget.initialEmail ?? '');
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();
  final _step3FormKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  int _resendCountdown = 60;
  Timer? _resendTimer;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialStep == 3) {
      widget.authService.inPasswordRecovery.value = true;
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCountdown <= 1) {
        timer.cancel();
        setState(() => _resendCountdown = 0);
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  // ขั้นที่ 1: ส่งรหัสรีเซ็ตไปที่อีเมล
  Future<void> _submitStep1() async {
    setState(() => _error = null);
    if (!_step1FormKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await widget.authService.resetPassword(_emailController.text.trim());
      _startResendTimer();
      if (mounted) {
        setState(() {
          _step = 2;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = authErrorMessage(e);
          _loading = false;
        });
      }
    }
  }

  // ส่งรหัสใหม่ในขั้นที่ 2
  Future<void> _resendCode() async {
    if (_resendCountdown > 0 || _resending) return;
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      await widget.authService.resetPassword(_emailController.text.trim());
      _startResendTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.strings.resendCodeSuccess),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = authErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  // ขั้นที่ 2: ตรวจสอบ OTP (6-8 หลัก)
  Future<void> _submitStep2() async {
    setState(() => _error = null);
    if (!_step2FormKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final code = _codeController.text.replaceAll(RegExp(r'\D'), '').trim();
      await widget.authService.verifyRecoveryCode(
        _emailController.text.trim(),
        code,
      );
      _resendTimer?.cancel();
      if (mounted) {
        setState(() {
          _step = 3;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = authErrorMessage(e);
          _loading = false;
        });
      }
    }
  }

  // ขั้นที่ 3: บันทึกรหัสผ่านใหม่
  Future<void> _submitStep3() async {
    setState(() => _error = null);
    if (!_step3FormKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      // 1. บันทึกรหัสผ่านใหม่
      await widget.authService.updatePassword(_passwordController.text);

      // 2. ให้ทุกเครื่องหลุดจากระบบ
      await widget.authService.signOut(scope: SignOutScope.global);
      try {
        widget.authService.inPasswordRecovery.value = false;
      } catch (_) {}
      widget.onComplete?.call();

      if (!mounted) return;
      setState(() => _loading = false);

      // 3. แสดงข้อความสำเร็จ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.strings.setNewPasswordSuccess),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // 4. กลับหน้า Login และกรอกอีเมลไว้ให้
      final email = _emailController.text.trim();
      final nav = Navigator.of(context);
      nav.popUntil((route) => route.isFirst);
      nav.push(
        MaterialPageRoute<void>(
          builder: (ctx) => Scaffold(
            body: Stack(
              children: [
                LoginPage(
                  authService: widget.authService,
                  initialEmail: email,
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

  // ปุ่มกลับหรือยกเลิก: ในขั้น 3 ต้อง signOut() ก่อนเสมอ
  Future<void> _handleCancel() async {
    if (_loading) return;
    _resendTimer?.cancel();

    if (_step == 3) {
      setState(() => _loading = true);
      try {
        await widget.authService.signOut();
      } finally {
        try {
          widget.authService.inPasswordRecovery.value = false;
        } catch (_) {}
        widget.onComplete?.call();
        if (mounted) {
          setState(() => _loading = false);
          final nav = Navigator.of(context);
          if (nav.canPop()) {
            nav.popUntil((route) => route.isFirst);
          }
        }
      }
    } else {
      try {
        widget.authService.inPasswordRecovery.value = false;
      } catch (_) {}
      widget.onComplete?.call();
      final nav = Navigator.of(context);
      if (nav.canPop()) {
        nav.pop();
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
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleCancel();
      },
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Stepper Header
                            _buildStepper(isDark, primary),
                            const SizedBox(height: 20),

                            if (_error != null) ...[
                              ErrorBanner(message: _error!),
                              const SizedBox(height: 16),
                            ],

                            // Step 1: กรอกอีเมล
                            if (_step == 1) _buildStep1(strings, isDark, primary),

                            // ขั้น 2: กรอกรหัสจากอีเมล
                            if (_step == 2) _buildStep2(strings, isDark, primary),

                            // ขั้น 3: รหัสผ่านใหม่ + ยืนยัน
                            if (_step == 3) _buildStep3(strings, isDark, primary),
                          ],
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

  Widget _buildStepper(bool isDark, Color primary) {
    return Row(
      children: [
        _buildStepBadge(1, Icons.mail_outline_rounded, isDark, primary),
        Expanded(child: _buildStepDivider(1, isDark, primary)),
        _buildStepBadge(2, Icons.pin_rounded, isDark, primary),
        Expanded(child: _buildStepDivider(2, isDark, primary)),
        _buildStepBadge(3, Icons.lock_outline_rounded, isDark, primary),
      ],
    );
  }

  Widget _buildStepBadge(int stepNumber, IconData icon, bool isDark, Color primary) {
    final isActive = _step == stepNumber;
    final isDone = _step > stepNumber;

    Color bgColor;
    Color iconColor;
    Border? border;

    if (isDone) {
      bgColor = const Color(0xFF10B981);
      iconColor = Colors.white;
    } else if (isActive) {
      bgColor = primary;
      iconColor = Colors.white;
    } else {
      bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
      iconColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
      border = Border.all(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
      );
    }

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: border,
        boxShadow: (isActive || isDone)
            ? [
                BoxShadow(
                  color: (isDone ? const Color(0xFF10B981) : primary)
                      .withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Icon(
          isDone ? Icons.check_rounded : icon,
          size: 18,
          color: iconColor,
        ),
      ),
    );
  }

  Widget _buildStepDivider(int afterStep, bool isDark, Color primary) {
    final isDone = _step > afterStep;
    return Container(
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: isDone
            ? const Color(0xFF10B981)
            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  // --- Step 1: กรอกอีเมล ---
  Widget _buildStep1(AppStrings strings, bool isDark, Color primary) {
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: primary.withValues(alpha: 0.3)),
              ),
              child: Icon(
                Icons.mark_email_read_outlined,
                size: 28,
                color: primary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            strings.forgotPasswordTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            strings.forgotPasswordDesc,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            '${strings.emailLabel} *',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: const Key('reset-password-email-field'),
            controller: _emailController,
            enabled: !_loading,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _loading ? null : _submitStep1(),
            decoration: InputDecoration(
              hintText: 'example@shop.com',
              prefixIcon: const Icon(Icons.mail_outline_rounded, size: 18),
              filled: true,
              fillColor:
                  isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFF),
            ),
            validator: validateEmail,
          ),
          const SizedBox(height: 22),

          _buildGradientButton(
            key: const Key('reset-password-send-code-button'),
            onPressed: _loading ? null : _submitStep1,
            label: strings.forgotPasswordSend,
            loading: _loading,
            loadingLabel: strings.checking,
          ),
          const SizedBox(height: 10),

          TextButton(
            key: const Key('reset-password-cancel-button'),
            onPressed: _loading ? null : _handleCancel,
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
    );
  }

  // --- Step 2: กรอกรหัสจากอีเมล ---
  Widget _buildStep2(AppStrings strings, bool isDark, Color primary) {
    return Form(
      key: _step2FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: primary.withValues(alpha: 0.3)),
              ),
              child: Icon(Icons.dialpad_rounded, size: 28, color: primary),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            strings.verifyCodeTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            strings.verifyCodeSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),

          // Notice: "ถ้ามีบัญชีนี้ในระบบ เราได้ส่งรหัสไปที่อีเมลแล้ว" เสมอ ไม่บอกว่ามีบัญชีหรือไม่
          Container(
            key: const Key('reset-password-email-notice'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF3B82F6),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.resetPasswordEmailNotice,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFF93C5FD)
                              : const Color(0xFF1D4ED8),
                          height: 1.4,
                        ),
                      ),
                      if (_emailController.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _emailController.text.trim(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? const Color(0xFFBFDBFE)
                                : const Color(0xFF1E40AF),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          Text(
            '${strings.recoveryCodeLabel} *',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: const Key('reset-password-code-field'),
            controller: _codeController,
            enabled: !_loading,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(
              letterSpacing: 4,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _loading ? null : _submitStep2(),
            decoration: InputDecoration(
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.key_rounded, size: 18),
              filled: true,
              fillColor:
                  isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFF),
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return strings.recoveryCodeRequired;
              if (text.length < 6) return strings.recoveryCodeInvalid;
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Resend Code Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                key: const Key('reset-password-back-to-email-button'),
                onPressed: _loading ? null : () => setState(() => _step = 1),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  strings.backToEmail,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
              TextButton(
                key: const Key('reset-password-resend-button'),
                onPressed: (_resendCountdown > 0 || _resending || _loading)
                    ? null
                    : _resendCode,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: _resending
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _resendCountdown > 0
                            ? strings.resendCodeIn(_resendCountdown)
                            : strings.resendCode,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _resendCountdown > 0
                              ? (isDark
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF94A3B8))
                              : primary,
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _buildGradientButton(
            key: const Key('reset-password-verify-button'),
            onPressed: _loading ? null : _submitStep2,
            label: strings.verifyCodeButton,
            loading: _loading,
            loadingLabel: strings.verifyingCode,
          ),
          const SizedBox(height: 10),

          TextButton(
            key: const Key('reset-password-cancel-button-step2'),
            onPressed: _loading ? null : _handleCancel,
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
    );
  }

  // --- Step 3: รหัสผ่านใหม่ + ยืนยัน ---
  Widget _buildStep3(AppStrings strings, bool isDark, Color primary) {
    return Form(
      key: _step3FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: primary.withValues(alpha: 0.3)),
              ),
              child: Icon(Icons.lock_reset_rounded, size: 28, color: primary),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            strings.setNewPasswordTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            strings.setNewPasswordSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 20),

          // New Password Input
          Text(
            '${strings.newPasswordLabel} *',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
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
              helperText: 'อย่างน้อย $minPasswordLength ตัวอักษร',
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
              filled: true,
              fillColor:
                  isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFF),
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
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
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: const Key('confirm-password-field'),
            controller: _confirmController,
            enabled: !_loading,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _loading ? null : _submitStep3(),
            decoration: InputDecoration(
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
              filled: true,
              fillColor:
                  isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFF),
              suffixIcon: IconButton(
                tooltip: _obscureConfirm ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (value) => validateConfirmPassword(
              value,
              _passwordController.text,
            ),
          ),
          const SizedBox(height: 22),

          // Submit Button
          _buildGradientButton(
            key: const Key('set-new-password-submit-button'),
            onPressed: _loading ? null : _submitStep3,
            label: strings.saveNewPassword,
            loading: _loading,
            loadingLabel: strings.savingNewPassword,
          ),
          const SizedBox(height: 10),

          // Cancel Button: signOut() ก่อนออกจากหน้าเสมอ
          TextButton(
            key: const Key('set-new-password-cancel-button'),
            onPressed: _loading ? null : _handleCancel,
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
    );
  }

  Widget _buildGradientButton({
    required Key key,
    required VoidCallback? onPressed,
    required String label,
    required bool loading,
    required String loadingLabel,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FilledButton(
        key: key,
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: loading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
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
                    loadingLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            : Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
