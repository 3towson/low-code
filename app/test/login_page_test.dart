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
}
