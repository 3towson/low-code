import 'dart:async';

import 'package:cod_customer_check/app.dart';
import 'package:cod_customer_check/pages/check_customer_page.dart';
import 'package:cod_customer_check/pages/login_page.dart';
import 'package:cod_customer_check/pages/report_customer_page.dart';
import 'package:cod_customer_check/services/auth_service.dart';
import 'package:cod_customer_check/services/check_service.dart';
import 'package:cod_customer_check/services/report_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ไม่ต่อ Supabase จริง signIn/signOut ส่ง event ผ่าน onAuthStateChange เหมือนของจริง
class FakeAuthService implements AuthService {
  FakeAuthService({bool signedIn = false}) {
    if (signedIn) _session = _newSession();
  }

  final _controller = StreamController<AuthState>.broadcast();
  Session? _session;
  int signInCalls = 0;

  /// ตั้งเป็น error เพื่อจำลอง login ไม่สำเร็จ
  Object? signInError;

  static Session _newSession() => Session(
        accessToken: 'test-token',
        tokenType: 'bearer',
        user: const User(
          id: 'user-1',
          appMetadata: {},
          userMetadata: {'shop_name': 'ร้านทดสอบ'},
          aud: 'authenticated',
          createdAt: '2026-01-01T00:00:00Z',
        ),
      );

  @override
  Stream<AuthState> get onAuthStateChange => _controller.stream;

  @override
  Session? get currentSession => _session;

  @override
  String get shopName => 'ร้านทดสอบ';

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls++;
    final error = signInError;
    if (error != null) throw error;
    _session = _newSession();
    _controller.add(AuthState(AuthChangeEvent.signedIn, _session));
  }

  @override
  Future<void> signOut() async => expire();

  /// จำลอง session หมดอายุหรือถูกออกจากระบบ
  void expire() {
    _session = null;
    _controller.add(const AuthState(AuthChangeEvent.signedOut, null));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// ตอบผลทันที เก็บคำขอที่ส่งมา
class FakeCheckService implements CheckService {
  final calls = <String>[];

  @override
  Future<CheckResult> checkText(String text) async {
    calls.add('text:$text');
    return const CheckOk(
      level: RiskLevel.red,
      countedReports: 2,
      recommendation: 'ไม่แนะนำให้ส่งแบบเก็บเงินปลายทาง ควรให้ลูกค้าโอนชำระก่อน',
      phoneMasked: '080-XXX-0002',
      customerName: 'สมชาย ใจดี',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class FakeReportService implements ReportService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

const _order = 'สมชาย ใจดี 080-000-0002 บ้านเลขที่ 1 กทม.';

Finder get _loginButton => find.byKey(const Key('home-login'));
Finder get _logoutButton => find.byKey(const Key('home-logout'));
Finder get _shopName => find.byKey(const Key('home-shop-name'));
Finder get _reportButton => find.byKey(const Key('home-report'));

/// จอมือถือ 360x740 เพื่อจับ overflow
Future<FakeCheckService> _pumpApp(
  WidgetTester tester,
  FakeAuthService auth, {
  ThemeMode? themeMode,
}) async {
  tester.view.physicalSize = const Size(360, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final check = FakeCheckService();
  await tester.pumpWidget(themeMode == null
      ? CodCheckApp(
          authService: auth,
          checkService: check,
          reportService: FakeReportService(),
        )
      : CodCheckApp(
          authService: auth,
          checkService: check,
          reportService: FakeReportService(),
          themeMode: themeMode,
        ));
  await tester.pumpAndSettle();
  return check;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _submitLogin(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'shop@example.com');
  await tester.enterText(fields.at(1), 'password123');
  await _tap(tester, find.widgetWithText(FilledButton, 'เข้าสู่ระบบ'));
}

void _popTop(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator)).pop();

void main() {
  testWidgets('เปิดแอปครั้งแรกเห็นหน้า Home ได้เลยโดยไม่ต้อง login',
      (tester) async {
    await _pumpApp(tester, FakeAuthService());

    expect(find.byType(LoginPage), findsNothing);
    expect(find.text('COD Risk Shield'), findsOneWidget);
    expect(find.text('ตรวจก่อนส่ง ป้องกันพัสดุตีกลับ'), findsOneWidget);
    expect(find.byKey(const Key('check-text')), findsOneWidget);
    expect(find.text('ตรวจสอบความเสี่ยง'), findsOneWidget);
    expect(_reportButton, findsOneWidget);
  });

  testWidgets('แสดง stats 3 ตัวเลข', (tester) async {
    await _pumpApp(tester, FakeAuthService());

    for (final (value, label) in [
      ('2,480+', 'ร้านค้า'),
      ('18,340 ชิ้น', 'ป้องกันแล้ว'),
      ('฿917,000', 'ประหยัดได้'),
    ]) {
      expect(find.text(value), findsOneWidget);
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('ยังไม่ login แสดงปุ่มเข้าสู่ระบบ ไม่แสดงชื่อร้านและปุ่ม logout',
      (tester) async {
    await _pumpApp(tester, FakeAuthService());

    expect(_loginButton, findsOneWidget);
    expect(_shopName, findsNothing);
    expect(_logoutButton, findsNothing);
  });

  testWidgets('login แล้วแสดงชื่อร้านและปุ่ม logout ไม่แสดงปุ่มเข้าสู่ระบบ',
      (tester) async {
    await _pumpApp(tester, FakeAuthService(signedIn: true));

    expect(tester.widget<Text>(_shopName).data, 'ร้านทดสอบ');
    expect(_logoutButton, findsOneWidget);
    expect(_loginButton, findsNothing);
  });

  testWidgets('ตรวจสอบโดยไม่ login ผลแสดงใต้ปุ่มในหน้าเดียวกัน',
      (tester) async {
    final check = await _pumpApp(tester, FakeAuthService());

    await tester.enterText(find.byKey(const Key('check-text')), _order);
    await _tap(tester, find.byKey(const Key('check-submit')));

    expect(check.calls, ['text:$_order']);
    expect(find.byType(CheckCustomerPage), findsNothing);
    expect(find.byKey(const Key('check-card-red')), findsOneWidget);
    // ผลอยู่ใต้ปุ่มตรวจสอบ และอยู่เหนือปุ่มรายงาน
    final submitY =
        tester.getTopLeft(find.byKey(const Key('check-submit'))).dy;
    final cardY = tester.getTopLeft(find.byKey(const Key('check-card-red'))).dy;
    final reportY = tester.getTopLeft(_reportButton).dy;
    expect(submitY < cardY && cardY < reportY, isTrue);
  });

  testWidgets(
      'ยังไม่ login กดรายงานลูกค้า ไปหน้า Login ก่อน '
      'login สำเร็จแล้วเข้าหน้ารายงานทันที', (tester) async {
    final auth = FakeAuthService();
    await _pumpApp(tester, auth);

    await _tap(tester, _reportButton);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(ReportCustomerPage), findsNothing);

    await _submitLogin(tester);
    expect(auth.signInCalls, 1);
    expect(find.byType(ReportCustomerPage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);

    // ย้อนกลับจากหน้ารายงานมาหน้า Home (ไม่ใช่หน้า Login) ในสถานะ login แล้ว
    _popTop(tester);
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsNothing);
    expect(_shopName, findsOneWidget);
    expect(_logoutButton, findsOneWidget);
  });

  testWidgets('login แล้วกดรายงานลูกค้า เข้าหน้ารายงานเลย', (tester) async {
    final auth = FakeAuthService(signedIn: true);
    await _pumpApp(tester, auth);

    await _tap(tester, _reportButton);

    expect(find.byType(ReportCustomerPage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
    expect(auth.signInCalls, 0);
  });

  testWidgets('login ไม่สำเร็จ อยู่หน้า Login ต่อและแสดง error',
      (tester) async {
    final auth = FakeAuthService()
      ..signInError = const AuthException('Invalid login credentials',
          code: 'invalid_credentials');
    await _pumpApp(tester, auth);

    await _tap(tester, _reportButton);
    await _submitLogin(tester);

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(ReportCustomerPage), findsNothing);
    expect(find.text('อีเมลหรือรหัสผ่านไม่ถูกต้อง'), findsOneWidget);
  });

  testWidgets('ปุ่มย้อนกลับในหน้า Login กลับหน้า Home โดยยังไม่ login',
      (tester) async {
    await _pumpApp(tester, FakeAuthService());

    await _tap(tester, _reportButton);
    await _tap(tester, find.byType(BackButton));

    expect(find.byType(LoginPage), findsNothing);
    expect(find.byType(ReportCustomerPage), findsNothing);
    expect(_loginButton, findsOneWidget);
  });

  testWidgets('กดเข้าสู่ระบบมุมขวาบน login สำเร็จแล้วกลับหน้า Home',
      (tester) async {
    await _pumpApp(tester, FakeAuthService());

    await _tap(tester, _loginButton);
    expect(find.byType(LoginPage), findsOneWidget);

    await _submitLogin(tester);
    expect(find.byType(LoginPage), findsNothing);
    expect(find.byType(ReportCustomerPage), findsNothing);
    expect(_shopName, findsOneWidget);
    expect(_logoutButton, findsOneWidget);
  });

  testWidgets('ผลตรวจยังอยู่หลัง login จากหน้า Home', (tester) async {
    await _pumpApp(tester, FakeAuthService());
    await tester.enterText(find.byKey(const Key('check-text')), _order);
    await _tap(tester, find.byKey(const Key('check-submit')));

    await _tap(tester, _loginButton);
    await _submitLogin(tester);

    expect(find.byKey(const Key('check-card-red')), findsOneWidget);
  });

  testWidgets('กด logout กลับเป็นสถานะยังไม่ login', (tester) async {
    await _pumpApp(tester, FakeAuthService(signedIn: true));

    await _tap(tester, _logoutButton);

    expect(_loginButton, findsOneWidget);
    expect(_shopName, findsNothing);
    expect(_logoutButton, findsNothing);
  });

  testWidgets('session หมดอายุตอนอยู่หน้ารายงาน กลับหน้า Home',
      (tester) async {
    final auth = FakeAuthService(signedIn: true);
    await _pumpApp(tester, auth);
    await _tap(tester, _reportButton);
    expect(find.byType(ReportCustomerPage), findsOneWidget);

    auth.expire();
    await tester.pumpAndSettle();

    expect(find.byType(ReportCustomerPage), findsNothing);
    expect(_loginButton, findsOneWidget);
  });

  testWidgets('ค่าเริ่มต้นเป็น dark theme', (tester) async {
    await _pumpApp(tester, FakeAuthService());

    final context = tester.element(find.text('COD Risk Shield'));
    final theme = Theme.of(context);
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, const Color(0xFF0F172A));
    expect(theme.colorScheme.primary, const Color(0xFF3B82F6));
  });

  // overflow จะทำให้เทสต์ล้มเองผ่าน FlutterError
  for (final mode in [ThemeMode.dark, ThemeMode.light]) {
    for (final signedIn in [false, true]) {
      testWidgets('จอ 360px ไม่ overflow ($mode, login = $signedIn)',
          (tester) async {
        await _pumpApp(tester, FakeAuthService(signedIn: signedIn),
            themeMode: mode);
        await tester.enterText(find.byKey(const Key('check-text')), _order);
        await _tap(tester, find.byKey(const Key('check-submit')));

        expect(find.byKey(const Key('check-card-red')), findsOneWidget);
        expect(_shopName, signedIn ? findsOneWidget : findsNothing);
      });
    }
  }
}
