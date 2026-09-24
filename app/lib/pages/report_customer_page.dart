import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
                onPressed: _submitting ? null : _submit,
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
