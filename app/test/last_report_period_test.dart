import 'dart:async';

import 'package:cod_customer_check/services/check_service.dart';
import 'package:cod_customer_check/widgets/check_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// ไม่ต่อ Supabase จริง ให้เทสต์ปล่อยผลทีละออเดอร์ผ่าน [respond]
class FakeCheckService implements CheckService {
  final _pending = <Completer<CheckResult>>[];

  void respond(CheckResult result) => _pending.removeAt(0).complete(result);

  @override
  Future<CheckResult> checkText(String text) {
    final c = Completer<CheckResult>();
    _pending.add(c);
    return c.future;
  }

  @override
  Future<List<MultiCheckResult>> checkMultiple(
    List<String> orders, {
    void Function(MultiCheckResult result)? onResult,
  }) async {
    final results = <MultiCheckResult>[];
    for (final order in orders) {
      final r = MultiCheckResult(orderText: order, result: await checkText(order));
      results.add(r);
      onResult?.call(r);
    }
    return results;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

CheckOk _ok(RiskLevel level, {int count = 0, ReportPeriod? period}) => CheckOk(
      level: level,
      countedReports: count,
      recommendation: 'คำแนะนำ',
      phoneMasked: '081-XXX-8877',
      customerName: 'นายอาทิตย์ รุ่งเรือง',
      lastReportPeriod: period,
    );

const _order = 'ชื่อ นายอาทิตย์ รุ่งเรือง\nเบอร์ 081-999-8877';

Future<FakeCheckService> _check(WidgetTester tester, String text) async {
  final service = FakeCheckService();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: CheckPanel(checkService: service)),
    ),
  ));
  await tester.enterText(find.byKey(const Key('check-text')), text);
  final button = find.byKey(const Key('check-submit'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
  return service;
}

Map<String, Object?> _okData(Object? period) => {
      'status': 'OK',
      'level': 'yellow',
      'counted_reports': 1,
      'recommendation': 'คำแนะนำ',
      'phone_masked': '081-XXX-8877',
      'last_report_period': period,
    };

void main() {
  group('checkResultFromData อ่าน last_report_period', () {
    const cases = {
      'within_30_days': ReportPeriod.within30Days,
      '1_to_3_months': ReportPeriod.oneToThreeMonths,
      '3_to_12_months': ReportPeriod.threeToTwelveMonths,
    };
    cases.forEach((value, expected) {
      test('$value -> ${expected.label}', () {
        final r = checkResultFromData(_okData(value)) as CheckOk;
        expect(r.lastReportPeriod, expected);
      });
    });

    test('null / ค่าไม่รู้จัก / ไม่มีฟิลด์ -> null และยังเป็น CheckOk', () {
      for (final v in [null, 'yesterday', '2026-09-20']) {
        final r = checkResultFromData(_okData(v));
        expect(r, isA<CheckOk>());
        expect((r as CheckOk).lastReportPeriod, isNull);
      }
      final noField = Map.of(_okData(null))..remove('last_report_period');
      expect((checkResultFromData(noField) as CheckOk).lastReportPeriod,
          isNull);
    });
  });

  testWidgets('ผลตรวจที่มีรายงาน แสดง "รายงานล่าสุด" เป็นช่วงเวลา',
      (tester) async {
    final service = await _check(tester, _order);
    service.respond(_ok(RiskLevel.yellow,
        count: 1, period: ReportPeriod.within30Days));
    await tester.pump();

    expect(
      tester.widget<Text>(find.byKey(const Key('check-last-report'))).data,
      'รายงานล่าสุด: ภายใน 30 วันที่ผ่านมา',
    );
  });

  testWidgets('ผลตรวจสีเขียว (ไม่มีรายงาน) ไม่แสดง "รายงานล่าสุด"',
      (tester) async {
    final service = await _check(tester, _order);
    service.respond(_ok(RiskLevel.green));
    await tester.pump();

    expect(find.byKey(const Key('check-count')), findsOneWidget);
    expect(find.byKey(const Key('check-last-report')), findsNothing);
  });

  testWidgets('ตรวจหลายออเดอร์ กดขยาย item แล้วเห็น "รายงานล่าสุด"',
      (tester) async {
    final service =
        await _check(tester, '$_order\n\nชื่อ ลูกค้าสอง\nเบอร์ 080-000-0002');
    service.respond(_ok(RiskLevel.red,
        count: 3, period: ReportPeriod.oneToThreeMonths));
    await tester.pump();
    service.respond(_ok(RiskLevel.green));
    await tester.pumpAndSettle();

    final item0 = find.byKey(const Key('multi-item-0'));
    await tester.ensureVisible(item0);
    await tester.tap(find
        .descendant(of: item0, matching: find.text('นายอาทิตย์ รุ่งเรือง'))
        .first);
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('multi-last-report-0'))).data,
      'รายงานล่าสุด: 1–3 เดือนที่แล้ว',
    );
  });
}
