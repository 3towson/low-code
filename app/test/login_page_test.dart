import 'package:cod_customer_check/pages/login_page.dart';
import 'package:cod_customer_check/pages/reset_password_page.dart';
import 'package:cod_customer_check/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// ไม่ต่อ Supabase จริง นับแค่ว่ามีการเรียก signIn หรือไม่
class FakeAuthService implements AuthService {
  @override
  final ValueNotifier<bool> inPasswordRecovery = ValueNotifier<bool>(false);

  int signInCalls = 0;

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls++;
  }

  int resetPasswordCalls = 0;
  String? lastResetEmail;

  @override
  Future<void> resetPassword(String email) async {
    resetPasswordCalls++;
    lastResetEmail = email;
  }

  int signUpCalls = 0;

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String shopName,
  }) async {
    signUpCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Finder get _loginButton => find.widgetWithText(FilledButton, 'เข้าสู่ระบบ');

void main() {
  testWidgets('กดเข้าสู่ระบบโดยไม่กรอก ต้องแสดงข้อความเตือนและไม่เรียก signIn',
      (tester) async {
    final auth = FakeAuthService();
    await tester.pumpWidget(MaterialApp(home: LoginPage(authService: auth)));

    expect(find.text('กรุณากรอกอีเมล'), findsNothing);
    expect(find.text('กรุณากรอกรหัสผ่าน'), findsNothing);

    await tester.tap(_loginButton);
    await tester.pump();

    expect(find.text('กรุณากรอกอีเมล'), findsOneWidget);
    expect(find.text('กรุณากรอกรหัสผ่าน'), findsOneWidget);
    expect(auth.signInCalls, 0);
  });

  testWidgets('อีเมลผิดรูปแบบ ต้องแสดงข้อความเตือน', (tester) async {
    final auth = FakeAuthService();
    await tester.pumpWidget(MaterialApp(home: LoginPage(authService: auth)));

    await tester.enterText(find.byType(TextFormField).at(0), 'not-an-email');
    await tester.enterText(find.byType(TextFormField).at(1), 'whatever1');
    await tester.tap(_loginButton);
    await tester.pump();

    expect(find.text('รูปแบบอีเมลไม่ถูกต้อง'), findsOneWidget);
    expect(auth.signInCalls, 0);
  });

  testWidgets('กรอกครบแล้วเรียก signIn', (tester) async {
    final auth = FakeAuthService();
    await tester.pumpWidget(MaterialApp(home: LoginPage(authService: auth)));

    await tester.enterText(find.byType(TextFormField).at(0), 'shop@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'whatever1');
    await tester.tap(_loginButton);
    await tester.pumpAndSettle();

    expect(auth.signInCalls, 1);
  });

  testWidgets('ปุ่มลืมรหัสผ่านแสดงในแท็บเข้าสู่ระบบ และเมื่อกดจะเปิด ResetPasswordPage',
      (tester) async {
    final auth = FakeAuthService();
    await tester.pumpWidget(MaterialApp(home: LoginPage(authService: auth)));

    final forgotBtn = find.byKey(const Key('auth-forgot-password-button'));
    expect(forgotBtn, findsOneWidget);

    await tester.tap(forgotBtn);
    await tester.pumpAndSettle();

    expect(find.byType(ResetPasswordPage), findsOneWidget);
    expect(find.byKey(const Key('reset-password-email-field')), findsOneWidget);
    expect(find.byKey(const Key('reset-password-send-code-button')), findsOneWidget);
  });

  testWidgets('ส่งอีเมลใน ResetPasswordPage แล้วจะเรียก resetPassword และไปขั้น 2',
      (tester) async {
    final auth = FakeAuthService();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: LoginPage(authService: auth))),
    );

    await tester.tap(find.byKey(const Key('auth-forgot-password-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('reset-password-email-field')),
      'user@example.com',
    );
    await tester.tap(find.byKey(const Key('reset-password-send-code-button')));
    await tester.pumpAndSettle();

    expect(auth.resetPasswordCalls, 1);
    expect(auth.lastResetEmail, 'user@example.com');
    expect(find.byKey(const Key('reset-password-code-field')), findsOneWidget);
    expect(find.byKey(const Key('reset-password-email-notice')), findsOneWidget);
  });

  testWidgets(
      'แท็บสมัครสมาชิก: ไม่สามารถสมัครได้ถ้าไม่ติ๊ก checkbox Terms และ Privacy',
      (tester) async {
    final auth = FakeAuthService();
    await tester.pumpWidget(MaterialApp(home: LoginPage(authService: auth)));

    // สลับไปยังแท็บสมัครสมาชิก
    await tester.tap(find.byKey(const Key('auth-tab-signup')));
    await tester.pumpAndSettle();

    // กรอกข้อมูลฟอร์มสมัคร: ชื่อร้าน, อีเมล, รหัสผ่าน
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(3));
    await tester.enterText(fields.at(0), 'ร้านค้าของฉัน');
    await tester.enterText(fields.at(1), 'shop@example.com');
    await tester.enterText(fields.at(2), 'password123');

    // ไม่ติ๊ก checkbox แล้วกดปุ่มสมัครสมาชิก
    await tester.tap(find.byKey(const Key('auth-submit-button')));
    await tester.pumpAndSettle();

    // ต้องแสดงข้อความแจ้งเตือน และไม่เรียก signUp
    expect(
      find.text('กรุณายอมรับข้อกำหนดการใช้งานและนโยบายความเป็นส่วนตัวก่อนสมัครสมาชิก'),
      findsOneWidget,
    );
    expect(auth.signUpCalls, 0);

    // ติ๊ก checkbox ยอมรับข้อกำหนด
    await tester.tap(find.byKey(const Key('login-privacy-checkbox')));
    await tester.pumpAndSettle();

    // กดปุ่มสมัครสมาชิกอีกครั้ง
    await tester.tap(find.byKey(const Key('auth-submit-button')));
    await tester.pumpAndSettle();

    // ต้องเรียก signUp สำเร็จ 1 ครั้ง
    expect(auth.signUpCalls, 1);
  });
}
