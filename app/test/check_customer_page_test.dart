import 'dart:async';

import 'package:cod_customer_check/pages/check_customer_page.dart';
import 'package:cod_customer_check/pages/home_page.dart';
import 'package:cod_customer_check/services/auth_service.dart';
import 'package:cod_customer_check/services/check_service.dart';
import 'package:cod_customer_check/services/report_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// ไม่ต่อ Supabase จริง เก็บคำขอที่ส่งมา และให้เทสต์เป็นคนปล่อยผลผ่าน [respond]
class FakeCheckService implements CheckService {
  /// เช่น 'text:...' หรือ 'phone:...'
  final calls = <String>[];
  Completer<CheckResult> _pending = Completer();

  void respond(CheckResult result) {
    _pending.complete(result);
    _pending = Completer();
  }

  @override
  Future<CheckResult> checkText(String text) {
    calls.add('text:$text');
    return _pending.future;
  }

  @override
  Future<CheckResult> checkPhone(String phone) {
    calls.add('phone:$phone');
    return _pending.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeAuthService implements AuthService {
  @override
  String get shopName => 'ร้านทดสอบ';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeReportService implements ReportService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

const _order = 'สมชาย ใจดี 080-000-0002 บ้านเลขที่ 1 กทม.';

Finder get _submit => find.byKey(const Key('check-submit'));
Finder get _phoneSubmit => find.byKey(const Key('check-phone-submit'));
Finder get _retry => find.byKey(const Key('check-retry'));

Future<void> _pumpPage(WidgetTester tester, FakeCheckService service) {
  return tester
      .pumpWidget(MaterialApp(home: CheckCustomerPage(checkService: service)));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder, warnIfMissed: false);
  await tester.pump();
}

Future<void> _checkText(WidgetTester tester, FakeCheckService service,
    CheckResult result) async {
  await tester.enterText(find.byKey(const Key('check-text')), _order);
  await _tap(tester, _submit);
  service.respond(result);
  await tester.pump();
}

bool _enabled(WidgetTester tester, Finder finder) =>
    tester.widget<ButtonStyleButton>(finder).onPressed != null;

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  const cases = [
    (
      level: RiskLevel.green,
      label: 'ความเสี่ยงต่ำ',
      recommendation: 'ส่งได้ตามปกติ',
      count: 0,
    ),
    (
      level: RiskLevel.yellow,
      label: 'ควรระวัง',
      recommendation: 'ควรโทรหรือทักยืนยันออเดอร์กับลูกค้าก่อนแพ็กสินค้า',
      count: 1,
    ),
    (
      level: RiskLevel.red,
      label: 'ความเสี่ยงสูง',
      recommendation: 'ไม่แนะนำให้ส่งแบบเก็บเงินปลายทาง ควรให้ลูกค้าโอนชำระก่อน',
      count: 2,
    ),
  ];

  for (final c in cases) {
    testWidgets('ผล ${c.level.value} แสดงการ์ด ${c.label} พร้อมรายละเอียด',
        (tester) async {
      final service = FakeCheckService();
      await _pumpPage(tester, service);

      await _checkText(
        tester,
        service,
        CheckOk(
          level: c.level,
          countedReports: c.count,
          recommendation: c.recommendation,
          phoneMasked: '080-XXX-0002',
          customerName: 'สมชาย ใจดี',
        ),
      );

      expect(service.calls, ['text:$_order']);
      expect(find.byKey(Key('check-card-${c.level.value}')), findsOneWidget);
      // มีการ์ดระดับเดียว
      expect(find.byWidgetPredicate((w) => w is Card), findsOneWidget);
      // สีต้องมีข้อความกำกับเสมอ
      expect(_text(tester, 'check-level'), c.label);
      expect(_text(tester, 'check-recommendation'), c.recommendation);
      expect(_text(tester, 'check-count'), 'จำนวนรายงาน: ${c.count} รายงาน');
      expect(_text(tester, 'check-name'), 'ชื่อลูกค้า: สมชาย ใจดี');
      expect(_text(tester, 'check-phone-masked'), 'เบอร์โทร: 080-XXX-0002');
      expect(find.byKey(const Key('check-ai-note')), findsNothing);
      expect(find.byKey(const Key('check-phone')), findsNothing);
    });
  }

  testWidgets('สีการ์ดต่างกันตามระดับ', (tester) async {
    final colors = <Color?>{};
    for (final c in cases) {
      final service = FakeCheckService();
      await _pumpPage(tester, service);
      await _checkText(
        tester,
        service,
        CheckOk(
          level: c.level,
          countedReports: c.count,
          recommendation: c.recommendation,
          phoneMasked: '080-XXX-0002',
        ),
      );
      colors.add(tester.widget<Card>(find.byType(Card)).color);
    }
    expect(colors, hasLength(3));
  });

  testWidgets('ai_unavailable = true แสดงหมายเหตุ และไม่มีชื่อแสดงเป็น -',
      (tester) async {
    final service = FakeCheckService();
    await _pumpPage(tester, service);

    await _checkText(
      tester,
      service,
      const CheckOk(
        level: RiskLevel.green,
        countedReports: 0,
        recommendation: 'ส่งได้ตามปกติ',
        phoneMasked: '080-XXX-0001',
        aiUnavailable: true,
      ),
    );

    expect(find.byKey(const Key('check-ai-note')), findsOneWidget);
    expect(find.textContaining('ระบบแยกชื่ออัตโนมัติไม่พร้อมใช้งาน'),
        findsOneWidget);
    expect(_text(tester, 'check-name'), 'ชื่อลูกค้า: -');
  });

  testWidgets('ไม่พบเบอร์ แสดงข้อความและช่องกรอกเบอร์ แล้วตรวจด้วยเบอร์ได้',
      (tester) async {
    final service = FakeCheckService();
    await _pumpPage(tester, service);

    expect(find.byKey(const Key('check-phone')), findsNothing);
    await _checkText(tester, service, const CheckNoPhone());

    expect(find.text('ไม่พบเบอร์โทรในข้อความ กรุณากรอกเบอร์ลูกค้าเอง'),
        findsOneWidget);
    expect(find.byKey(const Key('check-phone')), findsOneWidget);
    expect(find.text('ตรวจสอบด้วยเบอร์'), findsOneWidget);

    // เบอร์ผิดรูปแบบ ตรวจในแอปก่อน ไม่ส่ง
    await tester.enterText(find.byKey(const Key('check-phone')), '02-123-4567');
    await _tap(tester, _phoneSubmit);
    expect(find.text('เบอร์โทรไม่ถูกต้อง ต้องเป็นเบอร์มือถือไทย 10 หลัก'),
        findsOneWidget);
    expect(service.calls, hasLength(1));

    // เบอร์ถูกต้อง ส่งตามที่กรอก ให้ server normalize เอง
    await tester.enterText(find.byKey(const Key('check-phone')), '080-000-0003');
    await _tap(tester, _phoneSubmit);
    expect(service.calls.last, 'phone:080-000-0003');
    expect(_enabled(tester, _phoneSubmit), isFalse);
    expect(_enabled(tester, _submit), isFalse);

    service.respond(const CheckOk(
      level: RiskLevel.red,
      countedReports: 2,
      recommendation: 'ไม่แนะนำให้ส่งแบบเก็บเงินปลายทาง ควรให้ลูกค้าโอนชำระก่อน',
      phoneMasked: '080-XXX-0003',
    ));
    await tester.pump();
    expect(find.byKey(const Key('check-card-red')), findsOneWidget);
    expect(_text(tester, 'check-level'), 'ความเสี่ยงสูง');
  });

  testWidgets('ระหว่างรอผลปุ่มถูกปิด แสดง loading และกดรัวๆ ส่งครั้งเดียว',
      (tester) async {
    final service = FakeCheckService();
    await _pumpPage(tester, service);
    await tester.enterText(find.byKey(const Key('check-text')), _order);

    expect(_enabled(tester, _submit), isTrue);
    await _tap(tester, _submit);
    await _tap(tester, _submit);
    await _tap(tester, _submit);

    expect(_enabled(tester, _submit), isFalse);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(service.calls, hasLength(1));

    service.respond(const CheckOk(
      level: RiskLevel.green,
      countedReports: 0,
      recommendation: 'ส่งได้ตามปกติ',
      phoneMasked: '080-XXX-0002',
    ));
    await tester.pump();
    expect(_enabled(tester, _submit), isTrue);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('ข้อความว่าง แสดงข้อความเตือนและไม่ส่ง', (tester) async {
    final service = FakeCheckService();
    await _pumpPage(tester, service);

    await _tap(tester, _submit);

    expect(find.text('กรุณาวางข้อความออเดอร์'), findsOneWidget);
    expect(service.calls, isEmpty);
  });

  testWidgets('error แสดงข้อความและปุ่มลองใหม่ กดแล้วส่งคำขอเดิมอีกครั้ง',
      (tester) async {
    final service = FakeCheckService();
    await _pumpPage(tester, service);

    await _checkText(
        tester, service, const CheckError('เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง'));

    expect(find.text('เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง'), findsOneWidget);
    expect(_retry, findsOneWidget);
    expect(_enabled(tester, _submit), isTrue);

    await _tap(tester, _retry);
    expect(service.calls, ['text:$_order', 'text:$_order']);
    expect(_enabled(tester, _submit), isFalse);

    service.respond(const CheckOk(
      level: RiskLevel.yellow,
      countedReports: 1,
      recommendation: 'ควรโทรหรือทักยืนยันออเดอร์กับลูกค้าก่อนแพ็กสินค้า',
      phoneMasked: '080-XXX-0002',
    ));
    await tester.pump();
    expect(find.byKey(const Key('check-card-yellow')), findsOneWidget);
    expect(_retry, findsNothing);
  });

  testWidgets('ไม่มีอินเทอร์เน็ต แสดงข้อความและปุ่มลองใหม่', (tester) async {
    final service = FakeCheckService();
    await _pumpPage(tester, service);

    await _checkText(tester, service, const CheckNoInternet());

    expect(
        find.text(
            'ไม่สามารถเชื่อมต่ออินเทอร์เน็ตได้ กรุณาตรวจสอบการเชื่อมต่อแล้วลองใหม่'),
        findsOneWidget);
    expect(_retry, findsOneWidget);
    expect(_enabled(tester, _retry), isTrue);
  });

  testWidgets('กดตรวจสอบลูกค้าที่หน้า Home แล้วเปิดหน้าตรวจสอบ',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        authService: _FakeAuthService(),
        checkService: FakeCheckService(),
        reportService: _FakeReportService(),
      ),
    ));

    await tester.tap(find.text('ตรวจสอบลูกค้า'));
    await tester.pumpAndSettle();

    expect(find.byType(CheckCustomerPage), findsOneWidget);
    expect(find.byKey(const Key('check-text')), findsOneWidget);
  });
}
