import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/report_service.dart';
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
  const ReportCustomerPage({super.key, required this.reportService});

  final ReportService reportService;

  @override
  State<ReportCustomerPage> createState() => _ReportCustomerPageState();
}

class _ReportCustomerPageState extends State<ReportCustomerPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  ReportPlatform? _platform;
  ReportReason? _reason;
  bool _submitting = false;

  /// ข้อความผลการส่งล่าสุด (สำเร็จหรือ error)
  String? _message;
  bool _messageIsError = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // ตั้ง _submitting ก่อน await ใดๆ กดรัวๆ จึงส่งได้ครั้งเดียว
    if (_submitting) return;
    setState(() => _message = null);
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
      switch (result) {
        case ReportSuccess():
          _formKey.currentState!.reset();
          _platform = null;
          _reason = null;
          _message = 'ส่งรายงานเรียบร้อยแล้ว ขอบคุณที่ช่วยแจ้งข้อมูล';
          _messageIsError = false;
        case ReportDuplicate(:final message):
        case ReportError(:final message):
          _message = message;
          _messageIsError = true;
        case ReportInvalid(:final messages):
          _message = messages.join('\n');
          _messageIsError = true;
        case ReportNoInternet(:final message):
          _message = message;
          _messageIsError = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('รายงานลูกค้า')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      key: const Key('report-name'),
                      controller: _nameController,
                      enabled: !_submitting,
                      decoration: const InputDecoration(
                        labelText: 'ชื่อลูกค้า',
                        border: OutlineInputBorder(),
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
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      validator: validateThaiPhone,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<ReportPlatform>(
                      key: const Key('report-platform'),
                      initialValue: _platform,
                      decoration: const InputDecoration(
                        labelText: 'แพลตฟอร์ม',
                        border: OutlineInputBorder(),
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
                      decoration: const InputDecoration(
                        labelText: 'เหตุผล',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final r in ReportReason.values)
                          DropdownMenuItem(value: r, child: Text(r.label)),
                      ],
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _reason = v),
                      validator: (v) => v == null ? 'กรุณาเลือกเหตุผล' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('report-amount'),
                      controller: _amountController,
                      enabled: !_submitting,
                      decoration: const InputDecoration(
                        labelText: 'มูลค่าความเสียหาย (บาท, ไม่บังคับ)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      textInputAction: TextInputAction.done,
                      validator: validateDamageAmount,
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _message!,
                        key: const Key('report-message'),
                        style: TextStyle(
                          color: _messageIsError ? colors.error : colors.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const Key('report-submit'),
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('ส่งรายงาน'),
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
