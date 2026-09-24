import 'dart:async';

import 'package:cod_customer_check/pages/report_customer_page.dart';
import 'package:cod_customer_check/services/report_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// ไม่ต่อ Supabase จริง เก็บ input ที่ส่งมา และให้เทสต์เป็นคนปล่อยผลผ่าน [respond]
class FakeReportService implements ReportService {
  final inputs = <ReportInput>[];
  Completer<ReportResult> _pending = Completer();

  void respond(ReportResult result) {
    _pending.complete(result);
    _pending = Completer();
  }

  @override
  Future<ReportResult> submit(ReportInput input) {
    inputs.add(input);
    return _pending.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Finder get _submit => find.byKey(const Key('report-submit'));

Future<void> _pumpPage(WidgetTester tester, FakeReportService service) {
  return tester.pumpWidget(
      MaterialApp(home: ReportCustomerPage(reportService: service)));
}

Future<void> _tapSubmit(WidgetTester tester) async {
  await tester.ensureVisible(_submit);
  await tester.tap(_submit, warnIfMissed: false);
  await tester.pump();
}

Future<void> _select(WidgetTester tester, String key, String label) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _fillValid(WidgetTester tester, {String phone = '081-234-5678'}) async {
  await tester.enterText(find.byKey(const Key('report-name')), 'สมชาย ทดสอบ');
  await tester.enterText(find.byKey(const Key('report-phone')), phone);
  await _select(tester, 'report-platform', 'Shopee');
  await _select(tester, 'report-reason', 'ปฏิเสธรับสินค้า');
  await tester.enterText(find.byKey(const Key('report-amount')), '1,500');
}

bool _buttonEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_submit).onPressed != null;

void main() {
  testWidgets('ช่องบังคับว่าง ต้องแสดงข้อความเตือนและไม่ส่ง', (tester) async {
    final service = FakeReportService();
    await _pumpPage(tester, service);

    await _tapSubmit(tester);

    expect(find.text('กรุณากรอกชื่อลูกค้า'), findsOneWidget);
    expect(find.text('กรุณากรอกเบอร์โทร'), findsOneWidget);
    expect(find.text('กรุณาเลือกแพลตฟอร์ม'), findsOneWidget);
    expect(find.text('กรุณาเลือกเหตุผล'), findsOneWidget);
    expect(service.inputs, isEmpty);
  });

  testWidgets('เบอร์ผิด ต้องแสดงข้อความเตือนและไม่ส่ง', (tester) async {
    final service = FakeReportService();
    await _pumpPage(tester, service);

    await _fillValid(tester, phone: '02-123-4567');
    await _tapSubmit(tester);

    expect(find.text('เบอร์โทรไม่ถูกต้อง ต้องเป็นเบอร์มือถือไทย 10 หลัก'),
        findsOneWidget);
    expect(service.inputs, isEmpty);
  });

  testWidgets('ระหว่างส่งปุ่มถูกปิด แสดง loading และกดรัวๆ ส่งครั้งเดียว',
      (tester) async {
    final service = FakeReportService();
    await _pumpPage(tester, service);
    await _fillValid(tester);

    expect(_buttonEnabled(tester), isTrue);
    await _tapSubmit(tester);
    await _tapSubmit(tester);
    await _tapSubmit(tester);

    expect(_buttonEnabled(tester), isFalse);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(service.inputs, hasLength(1));

    // ส่งค่า enum ตาม PROJECT_CONTEXT ไม่ใช่ข้อความภาษาไทย
    expect(service.inputs.single.toJson(), {
      'customer_name': 'สมชาย ทดสอบ',
      'phone': '081-234-5678',
      'platform': 'shopee',
      'reason': 'refused_delivery',
      'amount': 1500,
    });

    service.respond(const ReportSuccess());
    await tester.pump();
    expect(_buttonEnabled(tester), isTrue);
  });

  testWidgets('ผลแบบรายงานซ้ำ แสดงข้อความจาก server และไม่ล้างฟอร์ม',
      (tester) async {
    final service = FakeReportService();
    await _pumpPage(tester, service);
    await _fillValid(tester);

    await _tapSubmit(tester);
    service.respond(const ReportDuplicate(
        'คุณรายงานเบอร์นี้ไปแล้วในช่วง 7 วันที่ผ่านมา'));
    await tester.pump();

    expect(find.text('คุณรายงานเบอร์นี้ไปแล้วในช่วง 7 วันที่ผ่านมา'),
        findsOneWidget);
    expect(find.text('081-234-5678'), findsOneWidget);
    expect(_buttonEnabled(tester), isTrue);
  });

  testWidgets('ผลแบบข้อมูลไม่ถูกต้อง แสดงข้อความจาก server', (tester) async {
    final service = FakeReportService();
    await _pumpPage(tester, service);
    await _fillValid(tester);

    await _tapSubmit(tester);
    service.respond(const ReportInvalid(['ชื่อลูกค้าห้ามมีเบอร์โทร']));
    await tester.pump();

    expect(find.text('ชื่อลูกค้าห้ามมีเบอร์โทร'), findsOneWidget);
  });

  testWidgets('สำเร็จ แสดงข้อความยืนยันและล้างฟอร์ม', (tester) async {
    final service = FakeReportService();
    await _pumpPage(tester, service);
    await _fillValid(tester);

    await _tapSubmit(tester);
    service.respond(const ReportSuccess());
    await tester.pump();

    expect(find.text('ส่งรายงานเรียบร้อยแล้ว ขอบคุณที่ช่วยแจ้งข้อมูล'),
        findsOneWidget);
    expect(find.text('สมชาย ทดสอบ'), findsNothing);
    expect(find.text('081-234-5678'), findsNothing);
    expect(find.text('1,500'), findsNothing);
    expect(find.text('Shopee'), findsNothing);
    expect(find.text('ปฏิเสธรับสินค้า'), findsNothing);
    // ล้างแล้วต้องไม่มีข้อความเตือนค้าง
    expect(find.text('กรุณากรอกชื่อลูกค้า'), findsNothing);
  });
}
