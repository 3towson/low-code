import 'package:flutter/material.dart';

import '../services/check_service.dart';
import '../utils/phone_utils.dart';

enum _Mode { text, phone }

class CheckCustomerPage extends StatefulWidget {
  const CheckCustomerPage({super.key, required this.checkService});

  final CheckService checkService;

  @override
  State<CheckCustomerPage> createState() => _CheckCustomerPageState();
}

class _CheckCustomerPageState extends State<CheckCustomerPage> {
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
    return Scaffold(
      appBar: AppBar(title: const Text('ตรวจสอบลูกค้า')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('check-text'),
                    controller: _textController,
                    enabled: !busy,
                    minLines: 5,
                    maxLines: 10,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      labelText: 'ข้อความออเดอร์',
                      hintText: 'วางข้อความออเดอร์ที่มีชื่อและเบอร์โทรลูกค้า',
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
                      errorText: _textError,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('check-submit'),
                    onPressed: busy ? null : _checkText,
                    child: _loading == _Mode.text
                        ? const _ButtonSpinner()
                        : const Text('ตรวจสอบ'),
                  ),
                  if (_showPhoneInput) ..._phoneSection(busy),
                  if (_result != null) ...[
                    const SizedBox(height: 24),
                    _resultView(_result!),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _phoneSection(bool busy) {
    return [
      const SizedBox(height: 24),
      Text(noPhoneMessage,
          key: const Key('check-no-phone'),
          style: Theme.of(context).textTheme.bodyLarge),
      const SizedBox(height: 12),
      TextField(
        key: const Key('check-phone'),
        controller: _phoneController,
        enabled: !busy,
        keyboardType: TextInputType.phone,
        decoration: InputDecoration(
          labelText: 'เบอร์โทรลูกค้า',
          hintText: 'เช่น 081-234-5678',
          border: const OutlineInputBorder(),
          errorText: _phoneError,
        ),
        onSubmitted: (_) => _checkPhone(),
      ),
      const SizedBox(height: 12),
      FilledButton.tonal(
        key: const Key('check-phone-submit'),
        onPressed: busy ? null : _checkPhone,
        child: _loading == _Mode.phone
            ? const _ButtonSpinner()
            : const Text('ตรวจสอบด้วยเบอร์'),
      ),
    ];
  }

  Widget _resultView(CheckResult result) {
    final colors = Theme.of(context).colorScheme;
    switch (result) {
      case CheckOk():
        return _RiskCard(result: result);
      case CheckNoPhone():
        // ข้อความและช่องกรอกเบอร์แสดงใน _phoneSection แล้ว
        return const SizedBox.shrink();
      case CheckInvalidPhone(:final message):
        return Text(message,
            key: const Key('check-message'),
            style: TextStyle(color: colors.error));
      case CheckNoInternet(:final message):
      case CheckError(:final message):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message,
                key: const Key('check-message'),
                style: TextStyle(color: colors.error)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('check-retry'),
              onPressed: _loading != null ? null : _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองใหม่'),
            ),
          ],
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

/// สีพื้น สีเข้ม และไอคอนของแต่ละระดับ สีเข้มใช้กับตัวอักษรบนพื้นสีอ่อนจึงอ่านง่าย
({Color background, Color foreground, IconData icon}) _styleOf(RiskLevel level) {
  return switch (level) {
    RiskLevel.green => (
        background: const Color(0xFFE8F5E9),
        foreground: const Color(0xFF1B5E20),
        icon: Icons.check_circle,
      ),
    RiskLevel.yellow => (
        background: const Color(0xFFFFF8E1),
        foreground: const Color(0xFF7A4F00),
        icon: Icons.warning_amber_rounded,
      ),
    RiskLevel.red => (
        background: const Color(0xFFFFEBEE),
        foreground: const Color(0xFFB71C1C),
        icon: Icons.dangerous,
      ),
  };
}

class _RiskCard extends StatelessWidget {
  const _RiskCard({required this.result});

  final CheckOk result;

  @override
  Widget build(BuildContext context) {
    final style = _styleOf(result.level);
    final textTheme = Theme.of(context).textTheme;
    const body = TextStyle(color: Colors.black87);
    return Card(
      key: Key('check-card-${result.level.value}'),
      color: style.background,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: style.foreground, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(style.icon, color: style.foreground, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result.level.label,
                    key: const Key('check-level'),
                    style: textTheme.titleLarge?.copyWith(
                      color: style.foreground,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              result.recommendation,
              key: const Key('check-recommendation'),
              style: textTheme.titleMedium?.copyWith(color: Colors.black87),
            ),
            const Divider(height: 24),
            Text('จำนวนรายงาน: ${result.countedReports} รายงาน',
                key: const Key('check-count'), style: body),
            const SizedBox(height: 4),
            Text('ชื่อลูกค้า: ${result.customerName ?? '-'}',
                key: const Key('check-name'), style: body),
            const SizedBox(height: 4),
            Text('เบอร์โทร: ${result.phoneMasked}',
                key: const Key('check-phone-masked'), style: body),
            if (result.aiUnavailable) ...[
              const SizedBox(height: 12),
              Text(
                'หมายเหตุ: ระบบแยกชื่ออัตโนมัติไม่พร้อมใช้งานในขณะนี้ '
                'ผลความเสี่ยงยังตรวจจากเบอร์โทรตามปกติ',
                key: const Key('check-ai-note'),
                style: textTheme.bodySmall?.copyWith(color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
