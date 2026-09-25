import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../utils/validators.dart';

enum AuthTab { signin, signup }

/// AuthModal popup dialog matching web version 100%
class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.authService,
    this.initialTab = AuthTab.signin,
    this.onClose,
  });

  final AuthService authService;
  final AuthTab initialTab;
  final VoidCallback? onClose;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _shopNameController = TextEditingController();

  late AuthTab _tab = widget.initialTab;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;
  bool _signupSuccess = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _shopNameController.dispose();
    super.dispose();
  }

  void _switchTab(AuthTab newTab) {
    if (_tab == newTab) return;
    setState(() {
      _tab = newTab;
      _error = null;
      _signupSuccess = false;
    });
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      if (_tab == AuthTab.signin) {
        await widget.authService.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
        if (mounted && widget.onClose != null) {
          widget.onClose!();
        }
      } else {
        await widget.authService.signUp(
          email: _emailController.text,
          password: _passwordController.text,
          shopName: _shopNameController.text,
        );
        if (mounted) {
          setState(() {
            _signupSuccess = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        final rawMsg = e.toString();
        if (rawMsg.contains('Invalid login credentials')) {
          _error = 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
        } else if (rawMsg.contains('Email not confirmed')) {
          _error = 'กรุณายืนยันอีเมลก่อนเข้าสู่ระบบ';
        } else {
          _error = authErrorMessage(e);
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handleClose() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final isDark = context.isDarkMode;
    final app = AppColors.of(context);

    final cardBg = isDark ? const Color(0xFF192640) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF22304A)
        : const Color(0xFFE2E8F0);
    final subtleBg = isDark ? const Color(0xFF16233B) : const Color(0xFFF1F5F9);
    final activeTabBg = isDark ? const Color(0xFF131D31) : Colors.white;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Modal Header with Tab switch & Close button
                  Row(
                    children: [
                      // Auth Tab switch
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: subtleBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _TabButton(
                                  label: strings.signIn,
                                  icon: Icons.login_rounded,
                                  active: _tab == AuthTab.signin,
                                  activeBg: activeTabBg,
                                  onTap: () => _switchTab(AuthTab.signin),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: _TabButton(
                                  label: strings.signUp,
                                  icon: Icons.person_add_alt_1_rounded,
                                  active: _tab == AuthTab.signup,
                                  activeBg: activeTabBg,
                                  onTap: () => _switchTab(AuthTab.signup),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Close button
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: IconButton(
                          tooltip: strings.close,
                          onPressed: _handleClose,
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: borderColor),
                  const SizedBox(height: 18),

                  // Success State (on signup)
                  if (_signupSuccess) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 36,
                              color: Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'สมัครสมาชิกสำเร็จ!',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'กรุณาตรวจสอบกล่องข้อความในอีเมล ${_emailController.text} เพื่อกดยืนยันตัวตนก่อนเข้าสู่ระบบ',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                              ),
                            ),
                            child: FilledButton(
                              onPressed: () {
                                setState(() {
                                  _signupSuccess = false;
                                  _tab = AuthTab.signin;
                                });
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('ไปที่หน้าเข้าสู่ระบบ'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Form Body
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_error != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: app.dangerBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: app.danger.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    size: 18,
                                    color: app.danger,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: app.danger,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          if (_tab == AuthTab.signup) ...[
                            Text(
                              '${strings.shopNameLabel} *',
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
                              controller: _shopNameController,
                              enabled: !_loading,
                              decoration: InputDecoration(
                                hintText: 'เช่น ร้านต้นไม้คุณนัท',
                                prefixIcon: const Icon(
                                  Icons.storefront_outlined,
                                  size: 18,
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? const Color(0xFF0B1120)
                                    : const Color(0xFFF8FAFF),
                              ),
                              textInputAction: TextInputAction.next,
                              validator: validateShopName,
                            ),
                            const SizedBox(height: 14),
                          ],

                          Text(
                            '${strings.emailLabel} *',
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
                            controller: _emailController,
                            enabled: !_loading,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              hintText: 'example@shop.com',
                              prefixIcon: const Icon(
                                Icons.mail_outline_rounded,
                                size: 18,
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? const Color(0xFF0B1120)
                                  : const Color(0xFFF8FAFF),
                            ),
                            validator: validateEmail,
                          ),
                          const SizedBox(height: 14),

                          Text(
                            '${strings.passwordLabel} *',
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
                            controller: _passwordController,
                            enabled: !_loading,
                            obscureText: _obscurePassword,
                            autofillHints: const [AutofillHints.password],
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) =>
                                _loading ? null : _submit(),
                            decoration: InputDecoration(
                              hintText: 'อย่างน้อย 6 ตัวอักษร',
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
                            validator: _tab == AuthTab.signin
                                ? validateLoginPassword
                                : validatePassword,
                          ),
                          const SizedBox(height: 22),

                          // Submit Button with Primary Gradient
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2563EB)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: FilledButton(
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
                                          strings.checking,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      _tab == AuthTab.signin
                                          ? strings.signIn
                                          : strings.signUp,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.activeBg,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final Color activeBg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: active ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.25 : 0.06,
                      ),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: active
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: active
                        ? (isDark ? Colors.white : const Color(0xFF0F172A))
                        : (isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
