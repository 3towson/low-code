import 'package:flutter/material.dart';

import '../services/check_service.dart';
import '../theme.dart';
import '../utils/phone_utils.dart';

enum _Mode { text, phone }

/// ช่องวางข้อความออเดอร์ ปุ่มตรวจสอบ และผลการตรวจในหน้าเดียวกัน
/// (ใช้ในหน้า Home แทนการเปิดหน้า CheckCustomerPage)
class CheckPanel extends StatefulWidget {
  const CheckPanel({super.key, required this.checkService});

  final CheckService checkService;

  @override
  State<CheckPanel> createState() => _CheckPanelState();
}

class _CheckPanelState extends State<CheckPanel> {
  final _textController = TextEditingController();
  final _phoneController = TextEditingController();

  /// โหมดที่กำลังรอผล (null = ไม่ได้รอ)
  _Mode? _loading;

  /// โหมดและค่าที่ส่งล่าสุด ใช้กับปุ่ม "ลองใหม่"
  _Mode? _lastMode;
  String _lastValue = '';

  CheckResult? _result;
  String? _textError;
  String? _phoneError;

  /// แสดงช่องกรอกเบอร์เองหลังจากข้อความไม่มีเบอร์
  bool _showPhoneInput = false;

  @override
  void dispose() {
    _textController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _checkText() {
    final text = _textController.text;
    if (text.trim().isEmpty) {
      setState(() => _textError = 'กรุณาวางข้อความออเดอร์');
      return;
    }
    setState(() {
      _textError = null;
      _showPhoneInput = false;
      _phoneError = null;
    });
    _run(_Mode.text, text);
  }

  void _checkPhone() {
    final phone = _phoneController.text;
    final error = validateThaiPhone(phone);
    setState(() => _phoneError = error);
    if (error != null) return;
    _run(_Mode.phone, phone);
  }

  Future<void> _run(_Mode mode, String value) async {
    // ตั้ง _loading ก่อน await ใดๆ กดรัวๆ จึงส่งได้ครั้งเดียว
    if (_loading != null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = mode;
      _lastMode = mode;
      _lastValue = value;
      _result = null;
    });
    final result = mode == _Mode.text
        ? await widget.checkService.checkText(value)
        : await widget.checkService.checkPhone(value);
    if (!mounted) return;
    setState(() {
      _loading = null;
      _result = result;
      if (result is CheckNoPhone) _showPhoneInput = true;
    });
  }

  void _retry() {
    final mode = _lastMode;
    if (mode != null) _run(mode, _lastValue);
  }

  @override
  Widget build(BuildContext context) {
    final busy = _loading != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('check-text'),
          controller: _textController,
          enabled: !busy,
          minLines: 4,
          maxLines: 10,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            hintText: 'วางข้อความออเดอร์ แชตลูกค้า หรือที่อยู่จัดส่งที่นี่...',
            errorText: _textError,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('check-submit'),
          onPressed: busy ? null : _checkText,
          icon: _loading == _Mode.text
              ? const _ButtonSpinner()
              : const Icon(Icons.shield_outlined),
          label: const Text('ตรวจสอบความเสี่ยง'),
        ),
        if (_showPhoneInput) ...[
          const SizedBox(height: AppSpacing.section),
          _phoneSection(busy),
        ],
        if (_result != null) ...[
          const SizedBox(height: AppSpacing.section),
          _resultView(_result!),
        ],
      ],
    );
  }

  Widget _phoneSection(bool busy) {
    final app = AppColors.of(context);
    return _StatusBox(
      background: app.neutralBackground,
      border: app.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.phone_disabled_outlined, color: app.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  noPhoneMessage,
                  key: const Key('check-no-phone'),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('check-phone'),
            controller: _phoneController,
            enabled: !busy,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'เบอร์โทรลูกค้า',
              hintText: 'เช่น 081-234-5678',
              prefixIcon: const Icon(Icons.phone_outlined),
              errorText: _phoneError,
            ),
            onSubmitted: (_) => _checkPhone(),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('check-phone-submit'),
            onPressed: busy ? null : _checkPhone,
            child: _loading == _Mode.phone
                ? const _ButtonSpinner()
                : const Text('ตรวจสอบด้วยเบอร์'),
          ),
        ],
      ),
    );
  }

  Widget _resultView(CheckResult result) {
    switch (result) {
      case CheckOk():
        return _RiskCard(result: result);
      case CheckNoPhone():
        // ข้อความและช่องกรอกเบอร์แสดงใน _phoneSection แล้ว
        return const SizedBox.shrink();
      case CheckInvalidPhone(:final message):
        return _ErrorBox(message: message);
      case CheckNoInternet(:final message):
      case CheckError(:final message):
        return _ErrorBox(
          message: message,
          action: OutlinedButton.icon(
            key: const Key('check-retry'),
            onPressed: _loading != null ? null : _retry,
            icon: const Icon(Icons.refresh),
            label: const Text('ลองใหม่'),
          ),
        );
    }
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

/// กล่องสถานะที่ไม่ใช่ผลความเสี่ยง
class _StatusBox extends StatelessWidget {
  const _StatusBox({
    required this.background,
    required this.border,
    required this.child,
  });

  final Color background;
  final Color border;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final app = AppColors.of(context);
    return _StatusBox(
      background: app.dangerBackground,
      border: app.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: app.danger),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  key: const Key('check-message'),
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: app.danger),
                ),
              ),
            ],
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

/// สีพื้น สีหลัก และไอคอนของแต่ละระดับ
({Color background, Color foreground, IconData icon}) _styleOf(
  AppColors app,
  RiskLevel level,
) {
  return switch (level) {
    RiskLevel.green => (
      background: app.successBackground,
      foreground: app.success,
      icon: Icons.check_rounded,
    ),
    RiskLevel.yellow => (
      background: app.warningBackground,
      foreground: app.warning,
      icon: Icons.warning_amber_rounded,
    ),
    RiskLevel.red => (
      background: app.dangerBackground,
      foreground: app.danger,
      icon: Icons.close_rounded,
    ),
  };
}

class _RiskCard extends StatelessWidget {
  const _RiskCard({required this.result});

  final CheckOk result;

  @override
  Widget build(BuildContext context) {
    final app = AppColors.of(context);
    final style = _styleOf(app, result.level);
    final textTheme = Theme.of(context).textTheme;
    return Card(
      key: Key('check-card-${result.level.value}'),
      color: style.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: BorderSide(color: style.foreground, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: style.foreground.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(style.icon, color: style.foreground, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    result.level.label,
                    key: const Key('check-level'),
                    style: textTheme.headlineSmall?.copyWith(
                      color: style.foreground,
                    ),
                  ),
                ),
              ],
            ),
            if (result.aiUnavailable) ...[
              const SizedBox(height: 12),
              const _AiUnavailableNote(),
            ],
            const SizedBox(height: 16),
            Text(
              result.recommendation,
              key: const Key('check-recommendation'),
              style: textTheme.titleMedium,
            ),
            Divider(height: 32, color: style.foreground.withValues(alpha: 0.3)),
            _InfoRow(
              icon: Icons.flag_outlined,
              child: Text(
                'จำนวนรายงาน: ${result.countedReports} รายงาน',
                key: const Key('check-count'),
                style: textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.person_outline,
              child: Text(
                'ชื่อลูกค้า: ${result.customerName ?? '-'}',
                key: const Key('check-name'),
                style: textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.phone_outlined,
              child: Text(
                'เบอร์โทร: ${result.phoneMasked}',
                key: const Key('check-phone-masked'),
                style: textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.child});

  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.of(context).muted),
        const SizedBox(width: 10),
        Expanded(child: child),
      ],
    );
  }
}

/// chip "AI ไม่พร้อมใช้งาน" พร้อมคำอธิบายสั้นๆ
class _AiUnavailableNote extends StatelessWidget {
  const _AiUnavailableNote();

  @override
  Widget build(BuildContext context) {
    final app = AppColors.of(context);
    return Column(
      key: const Key('check-ai-note'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Chip(
          avatar: Icon(Icons.auto_awesome_outlined, size: 16, color: app.muted),
          label: const Text('AI ไม่พร้อมใช้งาน'),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        const SizedBox(height: 4),
        Text(
          'ระบบแยกชื่ออัตโนมัติไม่พร้อมใช้งานในขณะนี้ '
          'ผลความเสี่ยงยังตรวจจากเบอร์โทรตามปกติ',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: app.muted),
        ),
      ],
    );
  }
}
