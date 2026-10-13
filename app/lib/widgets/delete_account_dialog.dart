import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../services/auth_service.dart';
import '../theme.dart';

/// กล่องข้อความยืนยันการลบบัญชีผู้ใช้ 2 ขั้นตอน (2-Step Delete Account Dialog)
/// ตามข้อกำหนด Apple App Store 5.1.1(v) และ Google Play account deletion
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({
    super.key,
    required this.authService,
  });

  final AuthService authService;

  static Future<bool?> show(BuildContext context, {required AuthService authService}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeleteAccountDialog(authService: authService),
    );
  }

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  int _step = 1;
  bool _confirmed = false;
  bool _isDeleting = false;
  String? _errorMessage;

  Future<void> _handleDelete() async {
    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });

    try {
      await widget.authService.deleteAccount();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDeleting = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final app = AppColors.of(context);
    final strings = context.strings;
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      key: const Key('delete-account-dialog'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: _step == 2
              ? const Color(0xFFEF4444).withValues(alpha: 0.4)
              : app.border,
        ),
      ),
      backgroundColor: app.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _step == 1
                ? _buildStep1(context, textTheme, app, strings, isDark)
                : _buildStep2(context, textTheme, app, strings, isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1(
    BuildContext context,
    TextTheme textTheme,
    AppColors app,
    dynamic strings,
    bool isDark,
  ) {
    return Column(
      key: const ValueKey('step-1'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFEF4444),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.deleteAccountTitle,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    'ขั้นตอนที่ 1 จาก 2: ข้อมูลและผลกระทบ',
                    style: TextStyle(
                      fontSize: 12,
                      color: app.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const Key('delete-account-close-x'),
              onPressed: () => Navigator.of(context).pop(false),
              icon: Icon(Icons.close_rounded, size: 20, color: app.muted),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 16),

        Text(
          strings.deleteAccountDesc,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),

        // ข้อมูลที่จะถูกลบถาวร
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.12 : 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFEF4444).withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      strings.deleteAccountDataDeletedTitle,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                strings.deleteAccountDataDeletedDesc,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ข้อมูลที่จัดเก็บต่อในรูปแบบนิรนาม
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.12 : 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    size: 16,
                    color: Color(0xFF3B82F6),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      strings.deleteAccountDataRetainedTitle,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                strings.deleteAccountDataRetainedDesc,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Actions
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('delete-account-cancel-btn'),
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  side: BorderSide(color: app.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  strings.deleteAccountCancel,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: app.muted,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const Key('delete-account-continue-btn'),
                onPressed: () => setState(() => _step = 2),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  strings.deleteAccountContinue,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep2(
    BuildContext context,
    TextTheme textTheme,
    AppColors app,
    dynamic strings,
    bool isDark,
  ) {
    return Column(
      key: const ValueKey('step-2'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.delete_forever_rounded,
                color: Color(0xFFEF4444),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.deleteAccountConfirmTitle,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                  Text(
                    'ขั้นตอนที่ 2 จาก 2: ยืนยันการดำเนินการ',
                    style: TextStyle(
                      fontSize: 12,
                      color: app.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 16),

        // Warning Box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFEF4444),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  strings.deleteAccountConfirmWarning,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Checkbox confirmation
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isDeleting
                ? null
                : () => setState(() => _confirmed = !_confirmed),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _confirmed
                      ? const Color(0xFFEF4444)
                      : app.border,
                ),
              ),
              child: Row(
                children: [
                  Checkbox(
                    key: const Key('delete-account-confirm-checkbox'),
                    value: _confirmed,
                    activeColor: const Color(0xFFEF4444),
                    onChanged: _isDeleting
                        ? null
                        : (val) => setState(() => _confirmed = val ?? false),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      strings.deleteAccountCheckbox,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _confirmed
                            ? (isDark ? Colors.white : Colors.black87)
                            : app.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Actions
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('delete-account-back-btn'),
                onPressed: _isDeleting
                    ? null
                    : () => setState(() {
                          _step = 1;
                          _errorMessage = null;
                        }),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  side: BorderSide(color: app.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  strings.deleteAccountBack,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: app.muted,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const Key('delete-account-confirm-btn'),
                onPressed: (_confirmed && !_isDeleting) ? _handleDelete : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      const Color(0xFFEF4444).withValues(alpha: 0.3),
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isDeleting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        strings.deleteAccountConfirmButton,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
