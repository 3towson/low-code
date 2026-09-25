import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_settings.dart';
import '../services/check_service.dart';
import '../services/report_service.dart';
import '../theme.dart';
import '../utils/phone_utils.dart';

const int maxCustomerNameLength = 100;
const num maxDamageAmount = 1000000;

String? validateCustomerName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) return 'กรุณากรอกชื่อลูกค้า';
  if (name.runes.length > maxCustomerNameLength) {
    return 'ชื่อลูกค้าต้องไม่เกิน $maxCustomerNameLength ตัวอักษร';
  }
  return null;
}

num? parseDamageAmount(String? value) {
  final text = (value ?? '').replaceAll(',', '').trim();
  if (text.isEmpty) return null;
  final n = num.tryParse(text);
  if (n == null || !n.isFinite) return null;
  return n;
}

String? validateDamageAmount(String? value) {
  if ((value ?? '').trim().isEmpty) return null;
  final n = parseDamageAmount(value);
  if (n == null || n < 0 || n > maxDamageAmount) {
    return 'มูลค่าความเสียหายต้องเป็นตัวเลข 0 ถึง 1,000,000';
  }
  return null;
}

/// ReportModal popup dialog matching web version 100%
class ReportCustomerPage extends StatefulWidget {
  const ReportCustomerPage({
    super.key,
    required this.reportService,
    this.checkService,
    this.onClose,
  });

  final ReportService reportService;
  final CheckService? checkService;
  final VoidCallback? onClose;

  @override
  State<ReportCustomerPage> createState() => _ReportCustomerPageState();
}

class _ReportCustomerPageState extends State<ReportCustomerPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _chatController = TextEditingController();
  final _otherPlatformController = TextEditingController();
  final _otherReasonController = TextEditingController();

  ReportPlatform? _platform;
  ReportReason? _reason;
  bool _submitting = false;
  bool _extracting = false;
  _AiMessage? _aiMessage;

  @override
  void dispose() {
    _chatController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _otherPlatformController.dispose();
    _otherReasonController.dispose();
    super.dispose();
  }

  void _handleClose() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _submit() async {
    if (_submitting || _extracting) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    final result = await widget.reportService.submit(
      ReportInput(
        customerName: _nameController.text,
        phone: _phoneController.text,
        platform: _platform!,
        reason: _reason!,
        amount: parseDamageAmount(_amountController.text),
      ),
    );
    if (!mounted) return;

    setState(() {
      _submitting = false;
      if (result is ReportSuccess) {
        _formKey.currentState!.reset();
        _nameController.clear();
        _phoneController.clear();
        _amountController.clear();
        _platform = null;
        _reason = null;
        _otherPlatformController.clear();
        _otherReasonController.clear();
        _aiMessage = null;
      }
    });

    switch (result) {
      case ReportSuccess():
        _showMessage(
          'ส่งรายงานเรียบร้อยแล้ว ขอบคุณที่ช่วยแจ้งข้อมูล',
          isError: false,
        );
      case ReportDuplicate(:final message):
      case ReportError(:final message):
        _showMessage(message, isError: true);
      case ReportInvalid(:final messages):
        _showMessage(messages.join('\n'), isError: true);
      case ReportNoInternet(:final message):
        _showMessage(message, isError: true);
    }
  }

  Future<void> _extract() async {
    final service = widget.checkService;
    if (service == null || _extracting || _submitting) return;
    final text = _chatController.text.trim();
    if (text.isEmpty) {
      setState(
        () => _aiMessage = const _AiMessage(
          'กรุณาวางข้อความแชทก่อน',
          _AiTone.error,
        ),
      );
      return;
    }

    setState(() {
      _extracting = true;
      _aiMessage = null;
    });
    final result = await service.checkText(text);
    if (!mounted) return;

    setState(() {
      _extracting = false;
      _aiMessage = switch (result) {
        CheckOk(:final customerName, :final phone, :final phoneMasked) =>
          _fillFromAi(customerName, phone, phoneMasked),
        CheckNoPhone() => const _AiMessage(
          'ไม่พบเบอร์โทรในข้อความ กรุณากรอกเอง',
          _AiTone.warning,
        ),
        CheckInvalidPhone(:final message) => _AiMessage(message, _AiTone.error),
        CheckNoInternet(:final message) => _AiMessage(message, _AiTone.error),
        CheckError(:final message) => _AiMessage(message, _AiTone.error),
      };
    });
  }

  _AiMessage _fillFromAi(String? name, String? phone, String phoneMasked) {
    if (name != null) _nameController.text = name.trim();
    if (phone != null) _phoneController.text = phone.trim();

    final filled = [
      if (name != null) 'ชื่อ',
      if (phone != null) 'เบอร์โทร',
    ].join('และ');
    if (phone != null) {
      return _AiMessage(
        'กรอก$filledให้แล้ว กรุณาตรวจสอบก่อนบันทึก',
        _AiTone.success,
      );
    }
    final prefix = filled.isEmpty ? '' : 'กรอก$filledให้แล้ว ';
    return _AiMessage(
      '$prefixพบเบอร์ $phoneMasked กรุณากรอกเบอร์เต็มเอง',
      _AiTone.warning,
    );
  }

  void _showMessage(String message, {required bool isError}) {
    final app = AppColors.of(context);
    final onColor = Theme.of(context).colorScheme.onPrimary;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          backgroundColor: isError ? app.danger : app.success,
          content: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: onColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  key: const Key('report-message'),
                  style: TextStyle(color: onColor),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildAiCard(BuildContext context) {
    final busy = _extracting || _submitting;
    final message = _aiMessage;
    final isDark = context.isDarkMode;
    final borderColor = isDark
        ? const Color(0xFF22304A)
        : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16233B) : const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const Key('report-chat'),
            controller: _chatController,
            enabled: !busy,
            minLines: 2,
            maxLines: 4,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              labelText: 'วางข้อความแชทลูกค้า',
              hintText: 'วางแชทหรือข้อความออเดอร์ที่นี่...',
              helperText: 'AI จะช่วยกรอกชื่อและเบอร์ให้ แก้ไขเองได้ภายหลัง',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('report-ai-extract'),
            onPressed: busy ? null : _extract,
            icon: _extracting
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_outlined, size: 16),
            label: Text(_extracting ? 'กำลังสกัดข้อมูล...' : 'AI สกัดข้อมูล'),
          ),
          if (message != null) ...[
            const SizedBox(height: 10),
            _AiMessageView(message: message),
          ],
        ],
      ),
    );
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
    final fieldBg = isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFF);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
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
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: app.dangerBackground,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.flag_rounded,
                            color: app.danger,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            strings.reportModalTitle,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? const Color(0xFFF1F5F9)
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
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

                    // Form
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.checkService != null)
                            _buildAiCard(context),

                          Text(
                            '${strings.customerNameLabel} *',
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
                            key: const Key('report-name'),
                            controller: _nameController,
                            enabled: !_submitting,
                            maxLength: maxCustomerNameLength,
                            buildCounter: (
                              _, {
                              required currentLength,
                              required isFocused,
                              maxLength,
                            }) => null,
                            decoration: InputDecoration(
                              hintText: strings.customerNameHint,
                              prefixIcon: const Icon(
                                Icons.person_outline,
                                size: 18,
                              ),
                              filled: true,
                              fillColor: fieldBg,
                            ),
                            textInputAction: TextInputAction.next,
                            validator: (v) => validateCustomerName(v),
                          ),
                          const SizedBox(height: 14),

                          Text(
                            '${strings.phoneLabel} *',
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
                            key: const Key('report-phone'),
                            controller: _phoneController,
                            enabled: !_submitting,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              hintText: strings.phoneHint,
                              prefixIcon: const Icon(
                                Icons.phone_outlined,
                                size: 18,
                              ),
                              filled: true,
                              fillColor: fieldBg,
                            ),
                            textInputAction: TextInputAction.next,
                            validator: validateThaiPhone,
                          ),
                          const SizedBox(height: 14),

                          // Platform and Reason Row (2 columns)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${strings.platform} *',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? const Color(0xFFF1F5F9)
                                            : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<ReportPlatform>(
                                      key: const Key('report-platform'),
                                      initialValue: _platform,
                                      isExpanded: true,
                                      borderRadius: BorderRadius.circular(12),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: fieldBg,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 12,
                                            ),
                                      ),
                                      items: [
                                        for (final p in ReportPlatform.values)
                                          DropdownMenuItem(
                                            value: p,
                                            child: Text(
                                              p.localizedLabel(strings),
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                      onChanged: _submitting
                                          ? null
                                          : (v) => setState(() {
                                              _platform = v;
                                              if (v != ReportPlatform.other) {
                                                _otherPlatformController
                                                    .clear();
                                              }
                                            }),
                                      validator: (v) => v == null
                                          ? strings.platformReq
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${strings.reason} *',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? const Color(0xFFF1F5F9)
                                            : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<ReportReason>(
                                      key: const Key('report-reason'),
                                      initialValue: _reason,
                                      isExpanded: true,
                                      borderRadius: BorderRadius.circular(12),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: fieldBg,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 12,
                                            ),
                                      ),
                                      items: [
                                        for (final r in ReportReason.values)
                                          DropdownMenuItem(
                                            value: r,
                                            child: Text(
                                              r.localizedLabel(strings),
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                      onChanged: _submitting
                                          ? null
                                          : (v) => setState(() {
                                              _reason = v;
                                              if (v != ReportReason.other) {
                                                _otherReasonController.clear();
                                              }
                                            }),
                                      validator: (v) =>
                                          v == null ? strings.reasonReq : null,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // Conditional Other Platform
                          if (_platform == ReportPlatform.other) ...[
                            const SizedBox(height: 12),
                            Text(
                              '${strings.specifyPlatform} *',
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
                              key: const Key('report-platform-other'),
                              controller: _otherPlatformController,
                              enabled: !_submitting,
                              decoration: InputDecoration(
                                hintText: strings.specifyPlatformHint,
                                filled: true,
                                fillColor: fieldBg,
                              ),
                              textInputAction: TextInputAction.next,
                              validator: (v) =>
                                  _platform == ReportPlatform.other &&
                                      (v == null || v.trim().isEmpty)
                                  ? strings.specifyPlatformReq
                                  : null,
                            ),
                          ],

                          // Conditional Other Reason
                          if (_reason == ReportReason.other) ...[
                            const SizedBox(height: 12),
                            Text(
                              '${strings.specifyReason} *',
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
                              key: const Key('report-reason-other'),
                              controller: _otherReasonController,
                              enabled: !_submitting,
                              decoration: InputDecoration(
                                hintText: strings.specifyReasonHint,
                                filled: true,
                                fillColor: fieldBg,
                              ),
                              textInputAction: TextInputAction.next,
                              validator: (v) =>
                                  _reason == ReportReason.other &&
                                      (v == null || v.trim().isEmpty)
                                  ? strings.specifyReasonReq
                                  : null,
                            ),
                          ],

                          const SizedBox(height: 14),

                          Text(
                            strings.amount,
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
                            key: const Key('report-amount'),
                            controller: _amountController,
                            enabled: !_submitting,
                            decoration: InputDecoration(
                              hintText: strings.amountHint,
                              filled: true,
                              fillColor: fieldBg,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]'),
                              ),
                            ],
                            textInputAction: TextInputAction.done,
                            validator: validateDamageAmount,
                          ),

                          const SizedBox(height: 24),

                          // Modal Footer: Close & Submit
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _submitting ? null : _handleClose,
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    side: BorderSide(color: borderColor),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    strings.close,
                                    style: TextStyle(
                                      color: isDark
                                          ? const Color(0xFFF1F5F9)
                                          : const Color(0xFF0F172A),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  key: const Key('report-submit'),
                                  onPressed: _submitting || _extracting
                                      ? null
                                      : _submit,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: app.danger,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(48),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _submitting
                                      ? const Center(
                                          child: SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          ),
                                        )
                                      : Text(
                                          strings.submit,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _AiTone { success, warning, error }

class _AiMessage {
  const _AiMessage(this.text, this.tone);

  final String text;
  final _AiTone tone;
}

class _AiMessageView extends StatelessWidget {
  const _AiMessageView({required this.message});

  final _AiMessage message;

  @override
  Widget build(BuildContext context) {
    final app = AppColors.of(context);
    final (color, icon) = switch (message.tone) {
      _AiTone.success => (app.success, Icons.check_circle_outline),
      _AiTone.warning => (app.warning, Icons.info_outline),
      _AiTone.error => (app.danger, Icons.error_outline),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message.text,
            key: const Key('report-ai-message'),
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
