import 'dart:async';

import 'package:cod_customer_check/pages/report_customer_page.dart';
import 'package:cod_customer_check/services/check_service.dart';
import 'package:cod_customer_check/services/report_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// ไม่ต่อ Supabase จริง เก็บข้อความที่ส่งมา และให้เทสต์เป็นคนปล่อยผลผ่าน [respond]
class FakeCheckService implements CheckService {
  final texts = <String>[];
  Completer<CheckResult> _pending = Completer();

  void respond(CheckResult result) {
    _pending.complete(result);
    _pending = Completer();
  }

  @override
  Future<CheckResult> checkText(String text) {
    texts.add(text);
    return _pending.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _UnusedReportService implements ReportService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

const _chat = 'สั่งเสื้อ 2 ตัวค่ะ ส่งคุณสมหญิง ใจดี 081-234-5678 เก็บปลายทาง';

Finder get _chatField => find.byKey(const Key('report-chat'));
Finder get _extractButton => find.byKey(const Key('report-ai-extract'));
Finder get _submitButton => find.byKey(const Key('report-submit'));
Finder get _aiMessage => find.byKey(const Key('report-ai-message'));

Future<void> _pumpPage(WidgetTester tester, FakeCheckService service) {
  return tester.pumpWidget(
    MaterialApp(
      home: ReportCustomerPage(
        reportService: _UnusedReportService(),
        checkService: service,
      ),
    ),
  );
}

Future<void> _tapExtract(WidgetTester tester) async {
  await tester.ensureVisible(_extractButton);
  await tester.tap(_extractButton, warnIfMissed: false);
  await tester.pump();
}

String _fieldText(WidgetTester tester, String key) =>
    tester.widget<TextFormField>(find.byKey(Key(key))).controller!.text;

bool _extractEnabled(WidgetTester tester) =>
    tester.widget<OutlinedButton>(_extractButton).onPressed != null;

bool _submitEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_submitButton).onPressed != null;

void main() {
  testWidgets('แสดงช่องวางแชทพร้อม placeholder และปุ่ม AI สกัดข้อมูล', (
    tester,
  ) async {
    await _pumpPage(tester, FakeCheckService());

    expect(find.text('วางแชทหรือข้อความออเดอร์ที่นี่...'), findsOneWidget);
    expect(find.text('AI สกัดข้อมูล'), findsOneWidget);
  });

  testWidgets('ไม่ส่ง checkService มา ไม่แสดงช่องวางแชท', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReportCustomerPage(reportService: _UnusedReportService()),
      ),
    );

    expect(_chatField, findsNothing);
    expect(_extractButton, findsNothing);
  });

  testWidgets('กดสกัดแล้วกรอกชื่อและเบอร์อัตโนมัติ และแก้ไขต่อได้', (
    tester,
  ) async {
    final service = FakeCheckService();
    await _pumpPage(tester, service);

    await tester.enterText(_chatField, _chat);
    await _tapExtract(tester);
    expect(service.texts, [_chat]);

    service.respond(
      const CheckOk(
        level: RiskLevel.green,
        countedReports: 0,
        recommendation: 'ส่งได้ตามปกติ',
        phoneMasked: '081-XXX-5678',
        customerName: 'สมหญิง ใจดี',
        phone: '0812345678',
      ),
    );
    await tester.pump();

    expect(_fieldText(tester, 'report-name'), 'สมหญิง ใจดี');
    expect(_fieldText(tester, 'report-phone'), '0812345678');
    expect(
      tester.widget<Text>(_aiMessage).data,
      'กรอกชื่อและเบอร์โทรให้แล้ว กรุณาตรวจสอบก่อนบันทึก',
    );

    // ผู้ใช้แก้ค่าที่ AI กรอกได้
    await tester.enterText(
      find.byKey(const Key('report-name')),
      'สมหญิง แก้ไข',
    );
    expect(_fieldText(tester, 'report-name'), 'สมหญิง แก้ไข');
  });

  testWidgets(
    'server ส่งมาแค่เบอร์ที่ mask กรอกชื่อ และให้ผู้ใช้กรอกเบอร์เอง',
    (tester) async {
      final service = FakeCheckService();
      await _pumpPage(tester, service);

      await tester.enterText(_chatField, _chat);
      await _tapExtract(tester);
      service.respond(
        const CheckOk(
          level: RiskLevel.green,
          countedReports: 0,
          recommendation: 'ส่งได้ตามปกติ',
          phoneMasked: '081-XXX-5678',
          customerName: 'สมหญิง ใจดี',
        ),
      );
      await tester.pump();

      expect(_fieldText(tester, 'report-name'), 'สมหญิง ใจดี');
      expect(_fieldText(tester, 'report-phone'), isEmpty);
      expect(
        tester.widget<Text>(_aiMessage).data,
        'กรอกชื่อให้แล้ว พบเบอร์ 081-XXX-5678 กรุณากรอกเบอร์เต็มเอง',
      );
    },
  );

  testWidgets('กดสกัดแล้วได้ NO_PHONE_DETECTED แสดงข้อความ ไม่แตะฟอร์ม', (
    tester,
  ) async {
    final service = FakeCheckService();
    await _pumpPage(tester, service);
    await tester.enterText(find.byKey(const Key('report-name')), 'กรอกเองก่อน');

    await tester.enterText(_chatField, 'ส่งของด่วนนะคะ');
    await _tapExtract(tester);
    service.respond(const CheckNoPhone());
    await tester.pump();

    expect(find.text('ไม่พบเบอร์โทรในข้อความ กรุณากรอกเอง'), findsOneWidget);
    expect(_fieldText(tester, 'report-name'), 'กรอกเองก่อน');
    expect(_fieldText(tester, 'report-phone'), isEmpty);
    expect(_extractEnabled(tester), isTrue);
  });

  testWidgets('ปุ่มถูกปิดระหว่างรอ แสดง loading และกดรัวๆ เรียกครั้งเดียว', (
    tester,
  ) async {
    final service = FakeCheckService();
    await _pumpPage(tester, service);
    await tester.enterText(_chatField, _chat);

    expect(_extractEnabled(tester), isTrue);
    await _tapExtract(tester);
    await _tapExtract(tester);
    await _tapExtract(tester);

    expect(_extractEnabled(tester), isFalse);
    expect(_submitEnabled(tester), isFalse);
    expect(find.text('กำลังสกัดข้อมูล...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(service.texts, hasLength(1));

    service.respond(const CheckNoPhone());
    await tester.pump();

    expect(_extractEnabled(tester), isTrue);
    expect(_submitEnabled(tester), isTrue);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('error แสดงข้อความสั้นๆ ไม่ crash และกดใหม่ได้', (tester) async {
    final service = FakeCheckService();
    await _pumpPage(tester, service);

    await tester.enterText(_chatField, _chat);
    await _tapExtract(tester);
    service.respond(const CheckError('เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง'), findsOneWidget);
    expect(_fieldText(tester, 'report-name'), isEmpty);
    expect(_extractEnabled(tester), isTrue);

    await tester.pump(const Duration(seconds: 1));
    await _tapExtract(tester);
    service.respond(const CheckNoInternet());
    await tester.pump();
    expect(find.text(const CheckNoInternet().message), findsOneWidget);
  });

  testWidgets('ข้อความว่าง ไม่เรียก server และแจ้งให้วางข้อความก่อน', (
    tester,
  ) async {
    final service = FakeCheckService();
    await _pumpPage(tester, service);

    await tester.enterText(_chatField, '   ');
    await _tapExtract(tester);

    expect(service.texts, isEmpty);
    expect(find.text('กรุณาวางข้อความแชทก่อน'), findsOneWidget);
  });

  test(
    'checkResultFromData อ่าน phone ถ้า server ส่งมา และเป็น null ถ้าไม่มี',
    () {
      final base = {
        'status': 'OK',
        'level': 'green',
        'counted_reports': 0,
        'recommendation': 'ส่งได้ตามปกติ',
        'phone_masked': '081-XXX-5678',
      };
      final withPhone =
          checkResultFromData({...base, 'phone': '0812345678'}) as CheckOk;
      final withoutPhone = checkResultFromData(base) as CheckOk;

      expect(withPhone.phone, '0812345678');
      expect(withoutPhone.phone, isNull);
    },
  );
}
