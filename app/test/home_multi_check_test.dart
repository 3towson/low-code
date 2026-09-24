import 'dart:async';

import 'package:cod_customer_check/pages/home_page.dart';
import 'package:cod_customer_check/services/auth_service.dart';
import 'package:cod_customer_check/services/check_service.dart';
import 'package:cod_customer_check/services/report_service.dart';
import 'package:cod_customer_check/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ใช้ checkMultiple ตัวจริง checkText รอให้เทสต์ปล่อยผลทีละออเดอร์ผ่าน [respond]
class ControlledCheckService extends CheckService {
  ControlledCheckService()
    : super(FunctionsClient('http://localhost', const {}));

  final calls = <String>[];
  final _pending = <Completer<CheckResult>>[];

  int get waiting => _pending.length;

  @override
  Future<CheckResult> checkText(String text) {
    calls.add(text);
    final c = Completer<CheckResult>();
    _pending.add(c);
    return c.future;
  }

  void respond(CheckResult result) => _pending.removeAt(0).complete(result);
}

class _FakeAuthService implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeReportService implements ReportService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

String _order(int i) =>
    'ลูกค้าคนที่ $i\n'
    'โทร 080-000-${i.toString().padLeft(4, '0')}\nบ้านเลขที่ $i กทม.';

String _orders(int n) => List.generate(n, (i) => _order(i + 1)).join('\n\n');

CheckOk _ok(RiskLevel level, int i, {int count = 0}) => CheckOk(
  level: level,
  countedReports: count,
  recommendation: switch (level) {
    RiskLevel.green => 'ส่งได้ตามปกติ',
    RiskLevel.yellow => 'ควรโทรหรือทักยืนยันออเดอร์กับลูกค้าก่อนแพ็กสินค้า',
    RiskLevel.red => 'ไม่แนะนำให้ส่งแบบเก็บเงินปลายทาง ควรให้ลูกค้าโอนชำระก่อน',
  },
  phoneMasked: '080-XXX-${i.toString().padLeft(4, '0')}',
  customerName: 'ลูกค้าคนที่ $i',
);

Finder get _status => find.byKey(const Key('multi-status'));
Finder get _progress => find.byKey(const Key('multi-progress'));
Finder get _truncated => find.byKey(const Key('multi-truncated'));
Finder _item(int i) => find.byKey(Key('multi-item-$i'));

String _statusText(WidgetTester tester) => tester.widget<Text>(_status).data!;

Future<void> _pumpHome(
  WidgetTester tester,
  CheckService service, {
  ThemeData? theme,
}) async {
  tester.view.physicalSize = const Size(360, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: HomePage(
        authService: _FakeAuthService(),
        checkService: service,
        reportService: _FakeReportService(),
        signedIn: false,
      ),
    ),
  );
}

Future<void> _submit(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('check-text')), text);
  final button = find.byKey(const Key('check-submit'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

void main() {
  testWidgets('ออเดอร์เดียว ทำงานแบบเดิม (การ์ดผลเดียว ไม่มีรายการ)', (
    tester,
  ) async {
    final service = ControlledCheckService();
    await _pumpHome(tester, service);

    await _submit(tester, _order(1));
    expect(service.calls, [_order(1)]);
    service.respond(_ok(RiskLevel.red, 1));
    await tester.pump();

    expect(find.byKey(const Key('check-card-red')), findsOneWidget);
    expect(_status, findsNothing);
    expect(_item(0), findsNothing);
  });

  testWidgets('3 ออเดอร์ แสดง progress และผลสะสมระหว่างรอ ตรวจทีละออเดอร์', (
    tester,
  ) async {
    final service = ControlledCheckService();
    await _pumpHome(tester, service);

    await _submit(tester, _orders(3));
    expect(_statusText(tester), 'พบ 3 ออเดอร์ กำลังตรวจสอบ... 1/3');
    expect(tester.widget<LinearProgressIndicator>(_progress).value, 0);
    expect(service.calls, [_order(1)]);
    expect(service.waiting, 1);

    service.respond(_ok(RiskLevel.green, 1));
    await tester.pump();
    expect(_statusText(tester), 'พบ 3 ออเดอร์ กำลังตรวจสอบ... 2/3');
    expect(
      tester.widget<LinearProgressIndicator>(_progress).value,
      closeTo(1 / 3, 1e-9),
    );
    expect(_item(0), findsOneWidget);
    expect(_item(1), findsNothing);
    // ส่งออเดอร์ถัดไปหลังได้ผลออเดอร์ก่อนหน้าเท่านั้น
    expect(service.calls, [_order(1), _order(2)]);
    expect(service.waiting, 1);
    // ระหว่างตรวจ ปุ่มถูกปิด
    expect(
      tester
          .widget<ButtonStyleButton>(find.byKey(const Key('check-submit')))
          .onPressed,
      isNull,
    );

    service.respond(_ok(RiskLevel.yellow, 2));
    await tester.pump();
    expect(_statusText(tester), 'พบ 3 ออเดอร์ กำลังตรวจสอบ... 3/3');

    service.respond(_ok(RiskLevel.red, 3));
    await tester.pumpAndSettle();
    expect(_statusText(tester), 'ตรวจแล้ว 3 ออเดอร์');
    expect(_progress, findsNothing);
    expect(service.calls, [_order(1), _order(2), _order(3)]);
    for (var i = 0; i < 3; i++) {
      expect(_item(i), findsOneWidget);
    }
    expect(find.byKey(const Key('check-card-red')), findsNothing);
  });

  testWidgets('แต่ละ item แสดงชื่อ เบอร์ mask ระดับ สี ไอคอน และคำแนะนำสั้น', (
    tester,
  ) async {
    final service = ControlledCheckService();
    await _pumpHome(tester, service, theme: AppTheme.dark());
    await _submit(tester, _orders(3));
    service.respond(_ok(RiskLevel.green, 1));
    await tester.pump();
    service.respond(_ok(RiskLevel.yellow, 2));
    await tester.pump();
    service.respond(_ok(RiskLevel.red, 3));
    await tester.pumpAndSettle();

    const app = AppColors.dark;
    final expected = [
      (
        RiskLevel.green,
        'ความเสี่ยงต่ำ · ส่งได้ตามปกติ',
        app.success,
        Icons.check_rounded,
      ),
      (
        RiskLevel.yellow,
        'ควรระวัง · ยืนยันกับลูกค้าก่อนแพ็ก',
        app.warning,
        Icons.warning_amber_rounded,
      ),
      (
        RiskLevel.red,
        'ความเสี่ยงสูง · ให้โอนก่อน ไม่ส่ง COD',
        app.danger,
        Icons.close_rounded,
      ),
    ];
    for (final (i, (_, line, color, icon)) in expected.indexed) {
      final item = _item(i);
      Finder inItem(Finder f) => find.descendant(of: item, matching: f);
      expect(inItem(find.text('ลูกค้าคนที่ ${i + 1}')), findsOneWidget);
      expect(inItem(find.text('080-XXX-000${i + 1}')), findsOneWidget);
      expect(inItem(find.text(line)), findsOneWidget);
      expect(tester.widget<Icon>(inItem(find.byIcon(icon))).color, color);
      final shape = tester.widget<Card>(item).shape as RoundedRectangleBorder;
      expect(shape.side.color, color);
    }
  });

  testWidgets('กดขยาย item แล้วเห็นจำนวนรายงานและคำแนะนำเต็ม', (tester) async {
    final service = ControlledCheckService();
    await _pumpHome(tester, service);
    await _submit(tester, _orders(2));
    service.respond(_ok(RiskLevel.red, 1, count: 3));
    await tester.pump();
    service.respond(_ok(RiskLevel.green, 2));
    await tester.pumpAndSettle();

    final count = find.byKey(const Key('multi-count-0'));
    expect(count, findsNothing);

    await tester.ensureVisible(_item(0));
    await tester.tap(
      find.descendant(of: _item(0), matching: find.text('ลูกค้าคนที่ 1')),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(count).data, 'จำนวนรายงาน: 3 รายงาน');
    expect(
      find.descendant(
        of: _item(0),
        matching: find.text(
          'ไม่แนะนำให้ส่งแบบเก็บเงินปลายทาง ควรให้ลูกค้าโอนชำระก่อน',
        ),
      ),
      findsOneWidget,
    );
    // item อื่นยังไม่ขยาย
    expect(find.byKey(const Key('multi-count-1')), findsNothing);
  });

  testWidgets('เกิน 10 ออเดอร์ ตรวจ 10 รายการแรกและแสดงข้อความแจ้ง', (
    tester,
  ) async {
    final service = ControlledCheckService();
    await _pumpHome(tester, service);

    await _submit(tester, _orders(12));
    expect(
      tester.widget<Text>(_truncated).data,
      'ตรวจได้สูงสุด 10 ออเดอร์ต่อครั้ง ระบบตรวจ 10 รายการแรกแล้ว',
    );
    expect(_statusText(tester), 'พบ 10 ออเดอร์ กำลังตรวจสอบ... 1/10');

    for (var i = 1; i <= 10; i++) {
      service.respond(_ok(RiskLevel.green, i));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(service.calls, List.generate(10, (i) => _order(i + 1)));
    expect(_statusText(tester), 'ตรวจแล้ว 10 ออเดอร์');
    expect(_truncated, findsOneWidget);
  });

  testWidgets('ไม่เกิน 10 ออเดอร์ ไม่แสดงข้อความแจ้ง', (tester) async {
    final service = ControlledCheckService();
    await _pumpHome(tester, service);

    await _submit(tester, _orders(10));

    expect(_truncated, findsNothing);
    expect(_statusText(tester), 'พบ 10 ออเดอร์ กำลังตรวจสอบ... 1/10');
  });

  testWidgets(
    'ออเดอร์ที่ตรวจไม่สำเร็จ แสดงเป็น item error ไม่หยุดตรวจออเดอร์อื่น',
    (tester) async {
      final service = ControlledCheckService();
      await _pumpHome(tester, service);
      await _submit(tester, _orders(3));

      service.respond(const CheckNoInternet());
      await tester.pump();
      service.respond(const CheckNoPhone());
      await tester.pump();
      service.respond(_ok(RiskLevel.red, 3));
      await tester.pumpAndSettle();

      expect(service.calls, hasLength(3));
      expect(
        find.descendant(
          of: _item(0),
          matching: find.textContaining('ตรวจไม่สำเร็จ'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _item(1),
          matching: find.text('ไม่พบเบอร์โทรในออเดอร์นี้'),
        ),
        findsOneWidget,
      );
      // ใช้บรรทัดแรกของออเดอร์เป็นหัวข้อ เพื่อให้รู้ว่าเป็นออเดอร์ไหน
      expect(
        find.descendant(of: _item(0), matching: find.text('ลูกค้าคนที่ 1')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _item(2), matching: find.text('ลูกค้าคนที่ 3')),
        findsOneWidget,
      );
    },
  );

  testWidgets('ตรวจแบบออเดอร์เดียวต่อจากหลายออเดอร์ รายการเดิมหายไป', (
    tester,
  ) async {
    final service = ControlledCheckService();
    await _pumpHome(tester, service);
    await _submit(tester, _orders(2));
    service.respond(_ok(RiskLevel.green, 1));
    await tester.pump();
    service.respond(_ok(RiskLevel.green, 2));
    await tester.pumpAndSettle();
    expect(_item(0), findsOneWidget);

    await _submit(tester, _order(5));
    service.respond(_ok(RiskLevel.yellow, 5));
    await tester.pumpAndSettle();

    expect(_item(0), findsNothing);
    expect(_status, findsNothing);
    expect(find.byKey(const Key('check-card-yellow')), findsOneWidget);
  });
}
