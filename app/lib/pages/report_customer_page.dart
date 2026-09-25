import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/check_service.dart';
import '../services/report_service.dart';
import '../theme.dart';
import '../utils/phone_utils.dart';
import '../widgets/page_body.dart';

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

/// ไม่บังคับกรอก รับตัวเลขที่มีจุลภาคคั่นหลักได้ เช่น 1,500
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

class ReportCustomerPage extends StatefulWidget {
  const ReportCustomerPage({
    super.key,
    required this.reportService,
    this.checkService,
  });

  final ReportService reportService;

  /// ใช้กับปุ่ม "AI สกัดข้อมูล" ถ้าไม่ส่งมาจะไม่แสดงช่องวางแชท
  final CheckService? checkService;

  @override
  State<ReportCustomerPage> createState() => _ReportCustomerPageState();
}

class _ReportCustomerPageState extends State<ReportCustomerPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _chatController = TextEditingController();
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
    super.dispose();
  }

  Future<void> _submit() async {
    // ตั้ง _submitting ก่อน await ใดๆ กดรัวๆ จึงส่งได้ครั้งเดียว
    if (_submitting || _extracting) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    final result = await widget.reportService.submit(ReportInput(
      customerName: _nameController.text,
      phone: _phoneController.text,
      platform: _platform!,
      reason: _reason!,
      amount: parseDamageAmount(_amountController.text),
    ));
    if (!mounted) return;

    setState(() {
      _submitting = false;
      if (result is ReportSuccess) {
        _formKey.currentState!.reset();
        _platform = null;
        _reason = null;
        _aiMessage = null;
      }
    });
    switch (result) {
      case ReportSuccess():
        _showMessage('ส่งรายงานเรียบร้อยแล้ว ขอบคุณที่ช่วยแจ้งข้อมูล',
            isError: false);
      case ReportDuplicate(:final message):
      case ReportError(:final message):
        _showMessage(message, isError: true);
      case ReportInvalid(:final messages):
        _showMessage(messages.join('\n'), isError: true);
      case ReportNoInternet(:final message):
        _showMessage(message, isError: true);
    }
  }

  /// ส่งข้อความแชทให้ check-customer แยกชื่อและเบอร์ แล้วกรอกลงฟอร์มให้
  /// ผู้ใช้แก้ไขต่อได้ตามปกติ ไม่กรอกทับช่องที่ server ไม่ได้ส่งค่ามา
  Future<void> _extract() async {
    final service = widget.checkService;
    if (service == null || _extracting || _submitting) return;
    final text = _chatController.text.trim();
    if (text.isEmpty) {
      setState(() => _aiMessage =
          const _AiMessage('กรุณาวางข้อความแชทก่อน', _AiTone.error));
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
    // server ส่งมาแค่เบอร์ที่ mask แล้ว ผู้ใช้ต้องกรอกเบอร์เต็มเอง
    final prefix = filled.isEmpty ? '' : 'กรอก$filledให้แล้ว ';
    return _AiMessage(
      '$prefixพบเบอร์ $phoneMasked กรุณากรอกเบอร์เต็มเอง',
      _AiTone.warning,
    );
  }

  /// ผลการส่ง: สำเร็จเป็น SnackBar สีเขียว error เป็นสีแดง
  void _showMessage(String message, {required bool isError}) {
    final app = AppColors.of(context);
    final onColor = Theme.of(context).colorScheme.onPrimary;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
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
      ));
  }

  /// ช่องวางแชทลูกค้าและปุ่มให้ AI ช่วยกรอกชื่อและเบอร์
  Widget _buildAiCard(BuildContext context) {
    final busy = _extracting || _submitting;
    final message = _aiMessage;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const Key('report-chat'),
              controller: _chatController,
              enabled: !busy,
              minLines: 3,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                labelText: 'วางข้อความแชทลูกค้า',
                hintText: 'วางแชทหรือข้อความออเดอร์ที่นี่...',
                helperText: 'AI จะช่วยกรอกชื่อและเบอร์ให้ แก้ไขเองได้ภายหลัง',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('report-ai-extract'),
              onPressed: busy ? null : _extract,
              icon: _extracting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_outlined),
              label: Text(_extracting ? 'กำลังสกัดข้อมูล...' : 'AI สกัดข้อมูล'),
            ),
            if (message != null) ...[
              const SizedBox(height: 12),
              _AiMessageView(message: message),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dropdownRadius = BorderRadius.circular(AppSpacing.controlRadius);
    return Scaffold(
      appBar: AppBar(title: const Text('รายงานลูกค้า')),
      body: PageBody(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.checkService != null) ...[
                _buildAiCard(context),
                const SizedBox(height: 16),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        key: const Key('report-name'),
                        controller: _nameController,
                        enabled: !_submitting,
                        decoration: const InputDecoration(
                          labelText: 'ชื่อลูกค้า',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        maxLength: maxCustomerNameLength,
                        textInputAction: TextInputAction.next,
                        validator: validateCustomerName,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        key: const Key('report-phone'),
                        controller: _phoneController,
                        enabled: !_submitting,
                        decoration: const InputDecoration(
                          labelText: 'เบอร์โทร',
                          hintText: 'เช่น 081-234-5678',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        validator: validateThaiPhone,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<ReportPlatform>(
                        key: const Key('report-platform'),
                        initialValue: _platform,
                        isExpanded: true,
                        borderRadius: dropdownRadius,
                        decoration: const InputDecoration(
                          labelText: 'แพลตฟอร์ม',
                          prefixIcon: Icon(Icons.storefront_outlined),
                        ),
                        items: [
                          for (final p in ReportPlatform.values)
                            DropdownMenuItem(value: p, child: Text(p.label)),
                        ],
                        onChanged: _submitting
                            ? null
                            : (v) => setState(() => _platform = v),
                        validator: (v) =>
                            v == null ? 'กรุณาเลือกแพลตฟอร์ม' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<ReportReason>(
                        key: const Key('report-reason'),
                        initialValue: _reason,
                        isExpanded: true,
                        borderRadius: dropdownRadius,
                        decoration: const InputDecoration(
                          labelText: 'เหตุผล',
                          prefixIcon: Icon(Icons.help_outline),
                        ),
                        items: [
                          for (final r in ReportReason.values)
                            DropdownMenuItem(value: r, child: Text(r.label)),
                        ],
                        onChanged: _submitting
                            ? null
                            : (v) => setState(() => _reason = v),
                        validator: (v) =>
                            v == null ? 'กรุณาเลือกเหตุผล' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('report-amount'),
                        controller: _amountController,
                        enabled: !_submitting,
                        decoration: const InputDecoration(
                          labelText: 'มูลค่าความเสียหาย (บาท)',
                          helperText: 'ไม่บังคับ',
                          prefixIcon: Icon(Icons.payments_outlined),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        textInputAction: TextInputAction.done,
                        validator: validateDamageAmount,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              FilledButton(
                key: const Key('report-submit'),
                onPressed: _submitting || _extracting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('บันทึกรายงาน'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _AiTone { success, warning, error }

/// ข้อความผลการสกัดข้อมูล แสดงใต้ปุ่ม "AI สกัดข้อมูล"
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
        Icon(icon, color: color, size: 20),
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
