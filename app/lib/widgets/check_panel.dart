import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../services/check_service.dart';
import '../theme.dart';
import '../utils/order_splitter.dart';
import '../utils/phone_utils.dart';

enum _Mode { text, phone, multi }

/// ช่องวางข้อความออเดอร์ ปุ่มตรวจสอบ และผลการตรวจในหน้าเดียวกัน
/// (ใช้ในหน้า Home แทนการเปิดหน้า CheckCustomerPage)
/// วางหลายออเดอร์คั่นด้วยบรรทัดว่างได้ จะตรวจทีละออเดอร์และแสดงผลเป็นรายการ
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

  /// ผลสะสมของการตรวจหลายออเดอร์ (null = ไม่ได้ตรวจแบบหลายออเดอร์)
  List<MultiCheckResult>? _multiResults;
  int _multiTotal = 0;
  bool _multiTruncated = false;

  @override
  void dispose() {
    _textController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _checkText() {
    final text = _textController.text;
    if (text.trim().isEmpty) {
      setState(() => _textError = context.strings.orderEmptyError);
      return;
    }
    setState(() {
      _textError = null;
      _showPhoneInput = false;
      _phoneError = null;
    });
    final orders = splitOrders(text);
    if (orders.length > 1) {
      _runMultiple(orders, truncated: exceedsOrderLimit(text));
    } else {
      _run(_Mode.text, text);
    }
  }

  Future<void> _runMultiple(
    List<String> orders, {
    required bool truncated,
  }) async {
    if (_loading != null) return;
    FocusScope.of(context).unfocus();
    final results = <MultiCheckResult>[];
    setState(() {
      _loading = _Mode.multi;
      _lastMode = null;
      _result = null;
      _multiResults = results;
      _multiTotal = orders.length;
      _multiTruncated = truncated;
    });
    await widget.checkService.checkMultiple(
      orders,
      onResult: (r) {
        if (mounted) setState(() => results.add(r));
      },
    );
    if (mounted) setState(() => _loading = null);
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
      _multiResults = null;
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
    final strings = context.strings;
    final isDark = context.isDarkMode;
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
            hintText: strings.orderHint,
            errorText: _textError,
            filled: true,
            fillColor: isDark
                ? const Color(0xFF16233B)
                : const Color(0xFFF8FAFF),
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark
                    ? const Color(0xFF22304A)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark
                    ? const Color(0xFF22304A)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF3B82F6),
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: busy
                ? null
                : const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: busy
                ? null
                : const [
                    BoxShadow(
                      color: Color(0x4D2563EB),
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
          ),
          child: FilledButton.icon(
            key: const Key('check-submit'),
            onPressed: busy ? null : _checkText,
            style: FilledButton.styleFrom(
              backgroundColor: busy ? null : Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: _loading == _Mode.text || _loading == _Mode.multi
                ? const _ButtonSpinner()
                : const Icon(Icons.search_rounded, size: 18),
            label: Text(
              strings.checkRiskButton,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ),
        if (_showPhoneInput) ...[
          const SizedBox(height: AppSpacing.section),
          _phoneSection(busy),
        ],
        if (_result != null) ...[
          const SizedBox(height: AppSpacing.section),
          _resultView(_result!),
        ],
        if (_multiResults != null) ...[
          const SizedBox(height: AppSpacing.section),
          _MultiResultList(
            results: _multiResults!,
            total: _multiTotal,
            truncated: _multiTruncated,
            running: _loading == _Mode.multi,
          ),
        ],
      ],
    );
  }

  Widget _phoneSection(bool busy) {
    final app = AppColors.of(context);
    final strings = context.strings;
    final isDark = context.isDarkMode;

    final warningBg = isDark
        ? const Color(0x1AF59E0B)
        : const Color(0xFFFFFBEB);
    final warningBorder = isDark
        ? const Color(0x40F59E0B)
        : const Color(0xFFFDE68A);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: warningBg,
        border: Border.all(color: warningBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFF59E0B),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  strings.isThai ? noPhoneMessage : strings.noPhoneFound,
                  key: const Key('check-no-phone'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? const Color(0xFFFDE68A)
                        : const Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('check-phone'),
            controller: _phoneController,
            enabled: !busy,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: strings.customerPhoneLabel,
              hintText: strings.customerPhoneHint,
              prefixIcon: const Icon(Icons.phone_outlined, size: 18),
              errorText: _phoneError,
              filled: true,
              fillColor: isDark ? const Color(0xFF16233B) : Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark
                      ? const Color(0xFF22304A)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark
                      ? const Color(0xFF22304A)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF3B82F6),
                  width: 1.5,
                ),
              ),
            ),
            onSubmitted: (_) => _checkPhone(),
          ),
          const SizedBox(height: 10),
          FilledButton(
            key: const Key('check-phone-submit'),
            onPressed: busy ? null : _checkPhone,
            style: FilledButton.styleFrom(
              backgroundColor: isDark
                  ? const Color(0xFF22304A)
                  : const Color(0xFFE2E8F0),
              foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size.fromHeight(44),
            ),
            child: _loading == _Mode.phone
                ? const _ButtonSpinner()
                : Text(
                    strings.checkWithPhoneButton,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
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
            label: Text(context.strings.retry),
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
    final strings = context.strings;
    final style = _styleOf(app, result.level);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      key: Key('check-card-${result.level.value}'),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: style.foreground, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: style.foreground.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(style.icon, color: style.foreground, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: style.foreground,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(
                        strings.localizeRiskLevel(result.level.label),
                        key: const Key('check-level'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      strings.localizeRecommendation(result.recommendation),
                      key: const Key('check-recommendation'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: isDark
                            ? const Color(0xFFF1F5F9)
                            : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (result.aiUnavailable) ...[
            const SizedBox(height: 12),
            const _AiUnavailableNote(),
          ],
          Divider(
            height: 32,
            color: isDark
                ? const Color(0xFF22304A)
                : const Color(0xFFE2E8F0).withValues(alpha: 0.8),
          ),
          // 2-column info grid
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(
                      icon: Icons.flag_outlined,
                      child: Text(
                        strings.isThai
                            ? 'จำนวนรายงาน: ${result.countedReports} รายงาน'
                            : '${strings.reportCountLabel}: ${result.countedReports}',
                        key: const Key('check-count'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _InfoRow(
                      icon: Icons.person_outline,
                      child: Text(
                        '${strings.customerNameLabel}: ${result.customerName ?? '-'}',
                        key: const Key('check-name'),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(
                      icon: Icons.phone_outlined,
                      child: Text(
                        '${strings.phoneLabel}: ${result.phoneMasked}',
                        key: const Key('check-phone-masked'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (result.lastReportPeriod case final period?) ...[
                      const SizedBox(height: 10),
                      _InfoRow(
                        icon: Icons.calendar_today_outlined,
                        child: Text(
                          '${strings.latestReportLabel}: ${period.label}',
                          key: const Key('check-last-report'),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
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

/// คำแนะนำสั้นๆ 1 บรรทัดในรายการผลหลายออเดอร์ (คำแนะนำเต็มอยู่ตอนกดขยาย)
const _shortAdvice = {
  RiskLevel.green: 'ส่งได้ตามปกติ',
  RiskLevel.yellow: 'ยืนยันกับลูกค้าก่อนแพ็ก',
  RiskLevel.red: 'ให้โอนก่อน ไม่ส่ง COD',
};

const multiTruncatedMessage =
    'ตรวจได้สูงสุด 10 ออเดอร์ต่อครั้ง ระบบตรวจ 10 รายการแรกแล้ว';

/// สถานะ progress และรายการผลของการตรวจหลายออเดอร์
class _MultiResultList extends StatelessWidget {
  const _MultiResultList({
    required this.results,
    required this.total,
    required this.truncated,
    required this.running,
  });

  final List<MultiCheckResult> results;
  final int total;
  final bool truncated;
  final bool running;

  @override
  Widget build(BuildContext context) {
    final app = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final done = results.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (truncated) ...[
          _StatusBox(
            background: app.warningBackground,
            border: app.warning,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: app.warning),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    multiTruncatedMessage,
                    key: const Key('multi-truncated'),
                    style: textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          running
              ? 'พบ $total ออเดอร์ กำลังตรวจสอบ... ${done + 1}/$total'
              : 'ตรวจแล้ว $total ออเดอร์',
          key: const Key('multi-status'),
          style: textTheme.titleMedium,
        ),
        if (running) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(
            key: const Key('multi-progress'),
            value: total == 0 ? null : done / total,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
        for (var i = 0; i < results.length; i++) ...[
          const SizedBox(height: 12),
          _OrderResultTile(index: i, item: results[i]),
        ],
      ],
    );
  }
}

/// ผลหนึ่งออเดอร์ กดขยายเพื่อดูคำแนะนำเต็ม จำนวนรายงาน และข้อความออเดอร์
class _OrderResultTile extends StatelessWidget {
  const _OrderResultTile({required this.index, required this.item});

  final int index;
  final MultiCheckResult item;

  @override
  Widget build(BuildContext context) {
    final app = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final result = item.result;
    final firstLine = item.orderText.trim().split('\n').first;

    final Color background;
    final Color foreground;
    final IconData icon;
    final String title;
    final List<String> summary;
    final List<Widget> details;
    switch (result) {
      case CheckOk():
        final style = _styleOf(app, result.level);
        background = style.background;
        foreground = style.foreground;
        icon = style.icon;
        title = result.customerName ?? 'ไม่ทราบชื่อลูกค้า';
        summary = [
          result.phoneMasked,
          '${result.level.label} · ${_shortAdvice[result.level]}',
        ];
        details = [
          Text(result.recommendation, style: textTheme.titleSmall),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.flag_outlined,
            child: Text(
              'จำนวนรายงาน: ${result.countedReports} รายงาน',
              key: Key('multi-count-$index'),
              style: textTheme.bodyLarge,
            ),
          ),
          if (result.lastReportPeriod case final period?) ...[
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.schedule_outlined,
              child: Text(
                'รายงานล่าสุด: ${period.label}',
                key: Key('multi-last-report-$index'),
                style: textTheme.bodyLarge,
              ),
            ),
          ],
          if (result.aiUnavailable) ...[
            const SizedBox(height: 8),
            const _AiUnavailableNote(),
          ],
        ];
      case CheckNoPhone():
        background = app.neutralBackground;
        foreground = app.muted;
        icon = Icons.phone_disabled_outlined;
        title = firstLine;
        summary = ['ไม่พบเบอร์โทรในออเดอร์นี้'];
        details = const [];
      case CheckInvalidPhone(:final message):
      case CheckNoInternet(:final message):
      case CheckError(:final message):
        background = app.dangerBackground;
        foreground = app.danger;
        icon = Icons.error_outline;
        title = firstLine;
        summary = ['ตรวจไม่สำเร็จ: $message'];
        details = const [];
    }

    return Card(
      key: Key('multi-item-$index'),
      color: background,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: BorderSide(color: foreground, width: 1.5),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: foreground.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: foreground, size: 24),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, line) in summary.indexed)
              Text(
                line,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: i == summary.length - 1
                    ? textTheme.bodyMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      )
                    : textTheme.bodyMedium?.copyWith(color: app.muted),
              ),
          ],
        ),
        children: [
          ...details,
          if (details.isNotEmpty) const SizedBox(height: 12),
          Text(
            item.orderText,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(color: app.muted),
          ),
        ],
      ),
    );
  }
}
