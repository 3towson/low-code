import 'package:cod_customer_check/pages/login_page.dart';
import 'package:cod_customer_check/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// ไม่ต่อ Supabase จริง นับแค่ว่ามีการเรียก signIn หรือไม่
class FakeAuthService implements AuthService {
  int signInCalls = 0;

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls++;
  }

  int resetPasswordCalls = 0;
  String? lastResetEmail;

  @override
  Future<void> resetPassword({required String email, String? redirectTo}) async {
    resetPasswordCalls++;
    lastResetEmail = email;
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

  testWidgets('ปุ่มลืมรหัสผ่านแสดงในแท็บเข้าสู่ระบบ และเมื่อกดจะเปิด dialog รีเซ็ตรหัสผ่าน',
      (tester) async {
    final auth = FakeAuthService();
    await tester.pumpWidget(MaterialApp(home: LoginPage(authService: auth)));

    final forgotBtn = find.byKey(const Key('auth-forgot-password-button'));
    expect(forgotBtn, findsOneWidget);

    await tester.tap(forgotBtn);
    await tester.pumpAndSettle();

    expect(find.text('รีเซ็ตรหัสผ่าน'), findsOneWidget);
    expect(find.byKey(const Key('forgot-password-email-field')), findsOneWidget);
    expect(find.byKey(const Key('forgot-password-submit-button')), findsOneWidget);
  });

  testWidgets('กรอกอีเมลใน dialog รีเซ็ตรหัสผ่านแล้วส่งสำเร็จ จะเรียก resetPassword',
      (tester) async {
    final auth = FakeAuthService();
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: LoginPage(authService: auth))));

    await tester.tap(find.byKey(const Key('auth-forgot-password-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('forgot-password-email-field')), 'user@example.com');
    await tester.tap(find.byKey(const Key('forgot-password-submit-button')));
    await tester.pumpAndSettle();

    expect(auth.resetPasswordCalls, 1);
    expect(auth.lastResetEmail, 'user@example.com');
    expect(find.text('ส่งลิงก์รีเซ็ตรหัสผ่านไปยังอีเมลเรียบร้อยแล้ว'), findsOneWidget);
  });
}

