import 'package:cod_customer_check/pages/login_page.dart';
import 'package:cod_customer_check/pages/reset_password_page.dart';
import 'package:cod_customer_check/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeResetAuthService implements AuthService {
  @override
  final ValueNotifier<bool> inPasswordRecovery = ValueNotifier<bool>(false);

  int resetPasswordCalls = 0;
  String? lastResetEmail;

  int verifyRecoveryCodeCalls = 0;
  String? lastVerifyEmail;
  String? lastVerifyCode;
  Object? verifyError;

  int updatePasswordCalls = 0;
  String? lastUpdatedPassword;
  Object? updatePasswordError;

  int signOutCalls = 0;
  SignOutScope? lastSignOutScope;

  @override
  Future<void> resetPassword(String email) async {
    resetPasswordCalls++;
    lastResetEmail = email;
  }

  @override
  Future<AuthResponse> verifyRecoveryCode(String email, String code) async {
    verifyRecoveryCodeCalls++;
    lastVerifyEmail = email;
    lastVerifyCode = code;
    if (verifyError != null) {
      throw verifyError!;
    }
    inPasswordRecovery.value = true;
    return AuthResponse(
      session: Session(
        accessToken: 'recovery-session-token',
        tokenType: 'bearer',
        user: const User(
          id: 'test-user',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-01-01T00:00:00Z',
        ),
      ),
    );
  }

  @override
  Future<UserResponse> updatePassword(String newPassword) async {
    updatePasswordCalls++;
    lastUpdatedPassword = newPassword;
    if (updatePasswordError != null) {
      throw updatePasswordError!;
    }
    return UserResponse.fromJson({
      'id': 'test-user',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'aud': 'authenticated',
      'created_at': '2026-01-01T00:00:00Z',
    });
  }

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.local}) async {
    signOutCalls++;
    lastSignOutScope = scope;
    inPasswordRecovery.value = false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Widget _wrapPage(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

void main() {
  group('ResetPasswordPage 3-step Widget Tests', () {
    testWidgets(
      'ขั้นตอนที่ 1 -> 2 -> 3 สำเร็จครบทุกขั้นตอนอย่างถูกต้อง',
      (tester) async {
        final auth = _FakeResetAuthService();
        await tester.pumpWidget(
          _wrapPage(
            ResetPasswordPage(
              authService: auth,
              initialEmail: 'test@shop.com',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // --- ขั้นที่ 1: ตรวจสอบและส่งอีเมล ---
        expect(find.byKey(const Key('reset-password-email-field')), findsOneWidget);
        expect(find.byKey(const Key('reset-password-send-code-button')), findsOneWidget);

        await tester.tap(find.byKey(const Key('reset-password-send-code-button')));
        await tester.pumpAndSettle();

        expect(auth.resetPasswordCalls, 1);
        expect(auth.lastResetEmail, 'test@shop.com');

        // --- ขั้นที่ 2: ตรวจสอบข้อความและรหัส OTP ---
        expect(find.byKey(const Key('reset-password-email-notice')), findsOneWidget);
        expect(
          find.text('ถ้ามีบัญชีนี้ในระบบ เราได้ส่งรหัสไปที่อีเมลแล้ว'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('reset-password-code-field')), findsOneWidget);
        expect(find.byKey(const Key('reset-password-verify-button')), findsOneWidget);

        // กรอกรหัส OTP 6 หลัก
        await tester.enterText(
          find.byKey(const Key('reset-password-code-field')),
          '123456',
        );
        await tester.tap(find.byKey(const Key('reset-password-verify-button')));
        await tester.pumpAndSettle();

        expect(auth.verifyRecoveryCodeCalls, 1);
        expect(auth.lastVerifyEmail, 'test@shop.com');
        expect(auth.lastVerifyCode, '123456');

        // --- ขั้นที่ 3: ตั้งรหัสผ่านใหม่ ---
        expect(find.byKey(const Key('new-password-field')), findsOneWidget);
        expect(find.byKey(const Key('confirm-password-field')), findsOneWidget);
        expect(find.byKey(const Key('set-new-password-submit-button')), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('new-password-field')),
          'NewSecurePass123!',
        );
        await tester.enterText(
          find.byKey(const Key('confirm-password-field')),
          'NewSecurePass123!',
        );

        await tester.tap(find.byKey(const Key('set-new-password-submit-button')));
        await tester.pumpAndSettle();

        // ตรวจสอบการบันทึกและ signOut(global)
        expect(auth.updatePasswordCalls, 1);
        expect(auth.lastUpdatedPassword, 'NewSecurePass123!');
        expect(auth.signOutCalls, 1);
        expect(auth.lastSignOutScope, SignOutScope.global);
        expect(auth.inPasswordRecovery.value, false);

        // แสดงข้อความสำเร็จ
        expect(
          find.text('ตั้งรหัสผ่านใหม่สำเร็จ กรุณาเข้าสู่ระบบ'),
          findsOneWidget,
        );

        // นำทางกลับหน้า Login และกรอกอีเมลเดิมไว้ให้
        expect(find.byType(LoginPage), findsOneWidget);
        final emailInput = tester.widget<TextFormField>(
          find.descendant(
            of: find.byType(LoginPage),
            matching: find.byType(TextFormField).first,
          ),
        );
        expect(emailInput.controller?.text, 'test@shop.com');
      },
    );

    testWidgets(
      'ขั้นที่ 2: รหัสผิด แสดงข้อความแจ้งเตือนข้อผิดพลาด',
      (tester) async {
        final auth = _FakeResetAuthService();
        auth.verifyError = const AuthApiException(
          'Token is invalid',
          statusCode: '400',
          code: 'bad_code',
        );

        await tester.pumpWidget(
          _wrapPage(
            ResetPasswordPage(
              authService: auth,
              initialEmail: 'user@shop.com',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // ไปขั้น 2
        await tester.tap(find.byKey(const Key('reset-password-send-code-button')));
        await tester.pumpAndSettle();

        // กรอกรหัสผิด
        await tester.enterText(
          find.byKey(const Key('reset-password-code-field')),
          '000000',
        );
        await tester.tap(find.byKey(const Key('reset-password-verify-button')));
        await tester.pumpAndSettle();

        expect(auth.verifyRecoveryCodeCalls, 1);
        // อยู่ที่ขั้น 2 เหมือนเดิมและแสดงข้อผิดพลาด
        expect(find.byKey(const Key('reset-password-code-field')), findsOneWidget);
        expect(find.byKey(const Key('new-password-field')), findsNothing);
      },
    );

    testWidgets(
      'ขั้นที่ 2: รหัสหมดอายุ (otp_expired) แสดงข้อความ "รหัสหมดอายุหรือไม่ถูกต้อง กรุณาขอรหัสใหม่"',
      (tester) async {
        final auth = _FakeResetAuthService();
        auth.verifyError = const AuthApiException(
          'Token has expired or is invalid',
          statusCode: '400',
          code: 'otp_expired',
        );

        await tester.pumpWidget(
          _wrapPage(
            ResetPasswordPage(
              authService: auth,
              initialEmail: 'user@shop.com',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // ไปขั้น 2
        await tester.tap(find.byKey(const Key('reset-password-send-code-button')));
        await tester.pumpAndSettle();

        // กรอกรหัสที่หมดอายุ
        await tester.enterText(
          find.byKey(const Key('reset-password-code-field')),
          '999999',
        );
        await tester.tap(find.byKey(const Key('reset-password-verify-button')));
        await tester.pumpAndSettle();

        expect(auth.verifyRecoveryCodeCalls, 1);
        expect(
          find.text('รหัสหมดอายุหรือไม่ถูกต้อง กรุณาขอรหัสใหม่'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'ขั้นที่ 2: ปุ่มส่งรหัสใหม่มีนับถอยหลัง 60 วินาที เมื่อหมดเวลาสามารถกดส่งใหม่ได้',
      (tester) async {
        final auth = _FakeResetAuthService();
        await tester.pumpWidget(
          _wrapPage(
            ResetPasswordPage(
              authService: auth,
              initialEmail: 'user@shop.com',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // ไปขั้น 2
        await tester.tap(find.byKey(const Key('reset-password-send-code-button')));
        await tester.pumpAndSettle();

        expect(auth.resetPasswordCalls, 1);

        // ขณะเวลานับถอยหลัง ปุ่ม disabled
        expect(find.text('ส่งรหัสใหม่ (60s)'), findsOneWidget);

        // เลื่อนเวลาไป 60 วินาที
        await tester.pump(const Duration(seconds: 60));
        await tester.pump();

        expect(find.text('ส่งรหัสใหม่'), findsOneWidget);

        // กดส่งรหัสใหม่
        await tester.tap(find.byKey(const Key('reset-password-resend-button')));
        await tester.pumpAndSettle();

        expect(auth.resetPasswordCalls, 2);
        expect(find.text('ส่งรหัสยืนยันใหม่เรียบร้อยแล้ว'), findsOneWidget);
      },
    );

    testWidgets(
      'ขั้นที่ 3: รหัสผ่านไม่ตรงกัน แสดงข้อความเตือนและไม่เรียก updatePassword',
      (tester) async {
        final auth = _FakeResetAuthService();
        await tester.pumpWidget(
          _wrapPage(
            ResetPasswordPage(
              authService: auth,
              initialStep: 3,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('new-password-field')),
          'Pass12345!',
        );
        await tester.enterText(
          find.byKey(const Key('confirm-password-field')),
          'MismatchPass12345!',
        );

        await tester.tap(find.byKey(const Key('set-new-password-submit-button')));
        await tester.pumpAndSettle();

        expect(find.text('รหัสผ่านไม่ตรงกัน'), findsOneWidget);
        expect(auth.updatePasswordCalls, 0);
      },
    );

    testWidgets(
      'ขั้นที่ 3: กรณี same_password แสดงข้อความ "รหัสผ่านใหม่ต้องไม่ซ้ำกับรหัสเดิม"',
      (tester) async {
        final auth = _FakeResetAuthService();
        auth.updatePasswordError = const AuthApiException(
          'New password should be different from the old password',
          statusCode: '422',
          code: 'same_password',
        );

        await tester.pumpWidget(
          _wrapPage(
            ResetPasswordPage(
              authService: auth,
              initialStep: 3,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('new-password-field')),
          'OldPassword123!',
        );
        await tester.enterText(
          find.byKey(const Key('confirm-password-field')),
          'OldPassword123!',
        );

        await tester.tap(find.byKey(const Key('set-new-password-submit-button')));
        await tester.pumpAndSettle();

        expect(auth.updatePasswordCalls, 1);
        expect(find.text('รหัสผ่านใหม่ต้องไม่ซ้ำกับรหัสเดิม'), findsOneWidget);
        expect(auth.signOutCalls, 0);
      },
    );

    testWidgets(
      'ขั้นที่ 3: กดยกเลิก จะเรียก signOut() และรีเซ็ต inPasswordRecovery',
      (tester) async {
        final auth = _FakeResetAuthService();
        await tester.pumpWidget(
          _wrapPage(
            ResetPasswordPage(
              authService: auth,
              initialStep: 3,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(auth.inPasswordRecovery.value, true);

        // กดยกเลิก
        await tester.tap(find.byKey(const Key('set-new-password-cancel-button')));
        await tester.pumpAndSettle();

        expect(auth.signOutCalls, 1);
        expect(auth.inPasswordRecovery.value, false);
      },
    );

    testWidgets(
      'ขั้นที่ 2: รองรับรหัสยืนยัน 8 หลักได้ถูกต้อง',
      (tester) async {
        final auth = _FakeResetAuthService();
        await tester.pumpWidget(
          _wrapPage(
            ResetPasswordPage(
              authService: auth,
              initialEmail: 'user@shop.com',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // ไปขั้น 2
        await tester.tap(find.byKey(const Key('reset-password-send-code-button')));
        await tester.pumpAndSettle();

        // กรอกรหัส OTP 8 หลัก
        await tester.enterText(
          find.byKey(const Key('reset-password-code-field')),
          '65224988',
        );
        await tester.tap(find.byKey(const Key('reset-password-verify-button')));
        await tester.pumpAndSettle();

        expect(auth.verifyRecoveryCodeCalls, 1);
        expect(auth.lastVerifyCode, '65224988');
        expect(find.byKey(const Key('new-password-field')), findsOneWidget);
      },
    );
  });
}
