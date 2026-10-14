import 'dart:async';

import 'package:cod_customer_check/app.dart';
import 'package:cod_customer_check/pages/login_page.dart';
import 'package:cod_customer_check/pages/reset_password_page.dart';
import 'package:cod_customer_check/services/app_settings.dart';
import 'package:cod_customer_check/services/auth_service.dart';
import 'package:cod_customer_check/services/check_service.dart';
import 'package:cod_customer_check/services/report_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuthService implements AuthService {
  _FakeAuthService();

  final _controller = StreamController<AuthState>.broadcast();
  Session? _currentSession;

  @override
  final ValueNotifier<bool> inPasswordRecovery = ValueNotifier<bool>(false);

  int updatePasswordCalls = 0;
  String? lastUpdatedPassword;
  int signOutCalls = 0;
  SignOutScope? lastSignOutScope;

  Object? updatePasswordError;

  static Session newTestSession() => Session(
        accessToken: 'recovery-token',
        tokenType: 'bearer',
        user: const User(
          id: 'recovery-user-1',
          appMetadata: {},
          userMetadata: {'shop_name': 'ร้านทดสอบกู้รหัส'},
          aud: 'authenticated',
          createdAt: '2026-01-01T00:00:00Z',
        ),
      );

  @override
  Stream<AuthState> get onAuthStateChange => _controller.stream;

  @override
  Session? get currentSession => _currentSession;

  @override
  User? get currentUser => _currentSession?.user;

  @override
  String get shopName => 'ร้านทดสอบกู้รหัส';

  @override
  bool get isAdmin => false;

  @override
  Future<bool> checkIsAdmin() async => false;

  @override
  Future<void> resetPassword(String email) async {}

  @override
  Future<AuthResponse> verifyRecoveryCode(String email, String code) async {
    return AuthResponse(session: newTestSession());
  }

  @override
  Future<UserResponse> updatePassword(String newPassword) async {
    updatePasswordCalls++;
    lastUpdatedPassword = newPassword;
    if (updatePasswordError != null) {
      throw updatePasswordError!;
    }
    return UserResponse.fromJson({
      'id': 'recovery-user-1',
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
    _currentSession = null;
    inPasswordRecovery.value = false;
    _controller.add(const AuthState(AuthChangeEvent.signedOut, null));
  }

  void emitRecovery(Session session) {
    _currentSession = session;
    inPasswordRecovery.value = true;
    _controller.add(AuthState(AuthChangeEvent.passwordRecovery, session));
  }

  void emitSignedIn(Session session) {
    _currentSession = session;
    _controller.add(AuthState(AuthChangeEvent.signedIn, session));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeCheckService implements CheckService {
  @override
  Future<CheckResult> checkText(String text) async {
    return const CheckOk(
      level: RiskLevel.green,
      countedReports: 0,
      recommendation: 'ส่งได้ตามปกติ',
      phoneMasked: '081-XXX-4567',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeReportService implements ReportService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Widget _buildApp(
  _FakeAuthService auth, {
  AppSettingsController? settingsController,
}) {
  return CodCheckApp(
    authService: auth,
    checkService: _FakeCheckService(),
    reportService: _FakeReportService(),
    settingsController: settingsController,
    animatePulse: false,
  );
}

void main() {
  group('AuthGate & ResetPasswordPage (Step 3) Flow Tests', () {
    testWidgets(
      'เมื่อได้รับ event passwordRecovery ต้อง push ResetPasswordPage และไม่แสดงปุ่มที่ล็อกอินแล้วบน Home',
      (tester) async {
        final auth = _FakeAuthService();
        await tester.pumpWidget(_buildApp(auth));
        await tester.pumpAndSettle();

        // ก่อนมี recovery: อยู่ที่หน้า Home แบบยังไม่ได้ล็อกอิน
        expect(find.byKey(const Key('home-login')), findsOneWidget);
        expect(find.byKey(const Key('home-logout')), findsNothing);
        expect(find.byType(ResetPasswordPage), findsNothing);

        // ส่ง event passwordRecovery เข้า stream
        final recoverySession = _FakeAuthService.newTestSession();
        auth.emitRecovery(recoverySession);
        await tester.pumpAndSettle();

        // 1. ต้องเห็นหน้า ResetPasswordPage ที่ขั้น 3
        expect(find.byType(ResetPasswordPage), findsOneWidget);
        expect(find.byKey(const Key('new-password-field')), findsOneWidget);

        // 2. ต้องไม่เห็นปุ่มของผู้ใช้ที่ล็อกอินแล้วบน Home (เช่น ปุ่มออกจากระบบ หรือชื่อร้าน)
        expect(find.byKey(const Key('home-logout')), findsNothing);
        expect(find.byKey(const Key('home-shop-name')), findsNothing);

        // 3. ถ้ามี event signedIn ตามมาตามหลัง flag inPasswordRecovery ต้องกันไว้ ไม่พาไปหน้า Home
        auth.emitSignedIn(recoverySession);
        await tester.pumpAndSettle();

        expect(find.byType(ResetPasswordPage), findsOneWidget);
        expect(find.byKey(const Key('home-logout')), findsNothing);
        expect(find.byKey(const Key('home-shop-name')), findsNothing);
      },
    );

    testWidgets(
      'ResetPasswordPage ถูกห่อด้วย PopScope(canPop: false) กดยกเลิกในขั้น 3 จะเรียก signOut()',
      (tester) async {
        final auth = _FakeAuthService();
        await tester.pumpWidget(_buildApp(auth));
        await tester.pumpAndSettle();

        auth.emitRecovery(_FakeAuthService.newTestSession());
        await tester.pumpAndSettle();

        expect(find.byType(ResetPasswordPage), findsOneWidget);

        // จำลองกด back route
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        // ต้องเรียก signOut() และหน้า ResetPasswordPage ปิดไป
        expect(auth.signOutCalls, 1);
        expect(find.byType(ResetPasswordPage), findsNothing);
      },
    );

    testWidgets(
      'ResetPasswordPage ตรวจสอบความถูกต้องของรหัสผ่านตาม validators.dart',
      (tester) async {
        final auth = _FakeAuthService();
        await tester.pumpWidget(
          MaterialApp(
            home: ResetPasswordPage(authService: auth, initialStep: 3),
          ),
        );
        await tester.pumpAndSettle();

        final submitBtn = find.byKey(const Key('set-new-password-submit-button'));
        final newPassField = find.byKey(const Key('new-password-field'));
        final confirmPassField = find.byKey(const Key('confirm-password-field'));

        // 1. กดบันทึกโดยไม่กรอก
        await tester.tap(submitBtn);
        await tester.pump();

        expect(find.text('กรุณากรอกรหัสผ่าน'), findsOneWidget);
        expect(find.text('กรุณายืนยันรหัสผ่าน'), findsOneWidget);
        expect(auth.updatePasswordCalls, 0);

        // 2. รหัสสั้นกว่า 8 ตัวอักษร
        await tester.enterText(newPassField, '1234567');
        await tester.enterText(confirmPassField, '1234567');
        await tester.tap(submitBtn);
        await tester.pump();

        expect(find.text('รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร'), findsOneWidget);
        expect(auth.updatePasswordCalls, 0);

        // 3. รหัสผ่านไม่ตรงกัน
        await tester.enterText(newPassField, 'NewPass1234');
        await tester.enterText(confirmPassField, 'DifferentPass1234');
        await tester.tap(submitBtn);
        await tester.pump();

        expect(find.text('รหัสผ่านไม่ตรงกัน'), findsOneWidget);
        expect(auth.updatePasswordCalls, 0);
      },
    );

    testWidgets(
      'ResetPasswordPage เมื่อ updatePassword ล้มเหลวกรณี same_password จะแสดงข้อความเตือน',
      (tester) async {
        final auth = _FakeAuthService();
        auth.updatePasswordError = const AuthApiException(
          'New password should be different from the old password',
          statusCode: '422',
          code: 'same_password',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ResetPasswordPage(authService: auth, initialStep: 3),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('new-password-field')),
          'SamePassword123!',
        );
        await tester.enterText(
          find.byKey(const Key('confirm-password-field')),
          'SamePassword123!',
        );

        await tester.tap(find.byKey(const Key('set-new-password-submit-button')));
        await tester.pumpAndSettle();

        expect(find.text('รหัสผ่านใหม่ต้องไม่ซ้ำกับรหัสเดิม'), findsOneWidget);
        expect(find.byType(ResetPasswordPage), findsOneWidget);
        expect(auth.signOutCalls, 0);
      },
    );

    testWidgets(
      'ResetPasswordPage กดยกเลิกในขั้น 3 จะเรียก signOut() และกลับหน้า Home แบบยังไม่ล็อกอิน',
      (tester) async {
        final auth = _FakeAuthService();
        await tester.pumpWidget(_buildApp(auth));
        await tester.pumpAndSettle();

        auth.emitRecovery(_FakeAuthService.newTestSession());
        await tester.pumpAndSettle();

        expect(find.byType(ResetPasswordPage), findsOneWidget);

        // กดยกเลิก
        await tester.tap(find.byKey(const Key('set-new-password-cancel-button')));
        await tester.pumpAndSettle();

        expect(auth.signOutCalls, 1);
        expect(find.byType(ResetPasswordPage), findsNothing);
        expect(find.byKey(const Key('home-login')), findsOneWidget);
        expect(find.byKey(const Key('home-logout')), findsNothing);
      },
    );

    testWidgets(
      'ResetPasswordPage บันทึกสำเร็จ: เรียก updatePassword, signOut(scope: global), แสดงข้อความ และพาไปหน้า Login',
      (tester) async {
        final auth = _FakeAuthService();
        await tester.pumpWidget(_buildApp(auth));
        await tester.pumpAndSettle();

        auth.emitRecovery(_FakeAuthService.newTestSession());
        await tester.pumpAndSettle();

        expect(find.byType(ResetPasswordPage), findsOneWidget);

        // กรอกรหัสใหม่ที่ถูกต้อง
        await tester.enterText(
          find.byKey(const Key('new-password-field')),
          'MyBrandNewPass123!',
        );
        await tester.enterText(
          find.byKey(const Key('confirm-password-field')),
          'MyBrandNewPass123!',
        );

        // กดบันทึก
        await tester.tap(find.byKey(const Key('set-new-password-submit-button')));
        await tester.pumpAndSettle();

        // 1. เรียก updatePassword ถูกต้อง
        expect(auth.updatePasswordCalls, 1);
        expect(auth.lastUpdatedPassword, 'MyBrandNewPass123!');

        // 2. เรียก signOut ด้วย scope: SignOutScope.global
        expect(auth.signOutCalls, 1);
        expect(auth.lastSignOutScope, SignOutScope.global);

        // 3. แสดงข้อความสำเร็จ
        expect(
          find.text('ตั้งรหัสผ่านใหม่สำเร็จ กรุณาเข้าสู่ระบบ'),
          findsOneWidget,
        );

        // 4. พาไปหน้า Login
        expect(find.byType(LoginPage), findsOneWidget);
        expect(find.byType(ResetPasswordPage), findsNothing);
      },
    );
  });
}
