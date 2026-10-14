import 'package:cod_customer_check/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeGoTrueClient implements GoTrueClient {
  UserAttributes? lastAttributes;
  SignOutScope? lastSignOutScope;
  String? lastResetEmail;
  String? lastResetRedirectTo;
  String? lastVerifyEmail;
  String? lastVerifyToken;
  OtpType? lastVerifyType;

  bool shouldThrow = false;
  AuthException? exceptionToThrow;

  @override
  Future<UserResponse> updateUser(
    UserAttributes attributes, {
    String? emailRedirectTo,
  }) async {
    lastAttributes = attributes;
    if (shouldThrow) {
      throw exceptionToThrow ??
          const AuthApiException('Error updating password', statusCode: '400');
    }
    return UserResponse.fromJson({
      'id': 'test-user-id',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'aud': 'authenticated',
      'created_at': '2026-01-01T00:00:00Z',
    });
  }

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.local}) async {
    lastSignOutScope = scope;
    if (shouldThrow) {
      throw exceptionToThrow ??
          const AuthApiException('Sign out error', statusCode: '500');
    }
  }

  @override
  Future<void> resetPasswordForEmail(
    String email, {
    String? redirectTo,
    String? captchaToken,
  }) async {
    lastResetEmail = email;
    lastResetRedirectTo = redirectTo;
  }

  @override
  Future<AuthResponse> verifyOTP({
    String? email,
    String? phone,
    String? token,
    required OtpType type,
    String? redirectTo,
    String? captchaToken,
    String? tokenHash,
  }) async {
    lastVerifyEmail = email;
    lastVerifyToken = token;
    lastVerifyType = type;
    if (shouldThrow) {
      throw exceptionToThrow ??
          const AuthApiException('Invalid code', statusCode: '400');
    }
    return AuthResponse(
      session: Session(
        accessToken: 'test-token',
        tokenType: 'bearer',
        user: const User(
          id: 'test-user-id',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-01-01T00:00:00Z',
        ),
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  group('AuthService - updatePassword & signOut unit tests', () {
    late _FakeGoTrueClient fakeAuth;
    late AuthService authService;

    setUp(() {
      fakeAuth = _FakeGoTrueClient();
      authService = AuthService(fakeAuth);
    });

    test('updatePassword สำเร็จ: ส่ง UserAttributes พร้อมรหัสผ่านใหม่', () async {
      final res = await authService.updatePassword('NewSecurePass123!');
      expect(fakeAuth.lastAttributes?.password, 'NewSecurePass123!');
      expect(res.user?.id, 'test-user-id');
    });

    test('updatePassword ล้มเหลว: โยน AuthException เมื่อ server มีข้อผิดพลาด', () async {
      fakeAuth.shouldThrow = true;
      fakeAuth.exceptionToThrow = const AuthApiException(
        'Password is too weak',
        statusCode: '422',
        code: 'weak_password',
      );

      expect(
        () => authService.updatePassword('123'),
        throwsA(isA<AuthException>()),
      );
    });

    test('updatePassword ล้มเหลวกรณี same_password: แปลง error ผ่าน authErrorMessage ได้ถูกต้อง', () async {
      fakeAuth.shouldThrow = true;
      fakeAuth.exceptionToThrow = const AuthApiException(
        'New password should be different from the old password',
        statusCode: '422',
        code: 'same_password',
      );

      try {
        await authService.updatePassword('OldPassword123!');
        fail('Should throw exception');
      } catch (e) {
        expect(authErrorMessage(e), 'รหัสผ่านใหม่ต้องไม่ซ้ำกับรหัสเดิม');
      }
    });

    test('authErrorMessage: otp_expired แสดงข้อความรหัสหมดอายุหรือไม่ถูกต้อง', () {
      const errByCode = AuthApiException('otp expired', code: 'otp_expired', statusCode: '400');
      expect(authErrorMessage(errByCode), 'รหัสหมดอายุหรือไม่ถูกต้อง กรุณาขอรหัสใหม่');

      const errByMsg = AuthApiException('Token has expired or is invalid', statusCode: '400');
      expect(authErrorMessage(errByMsg), 'รหัสหมดอายุหรือไม่ถูกต้อง กรุณาขอรหัสใหม่');
    });

    test('signOut: รองรับ SignOutScope.local (default) และ SignOutScope.global และรีเซ็ต inPasswordRecovery', () async {
      authService.inPasswordRecovery.value = true;
      await authService.signOut();
      expect(fakeAuth.lastSignOutScope, SignOutScope.local);
      expect(authService.inPasswordRecovery.value, false);

      authService.inPasswordRecovery.value = true;
      await authService.signOut(scope: SignOutScope.global);
      expect(fakeAuth.lastSignOutScope, SignOutScope.global);
      expect(authService.inPasswordRecovery.value, false);
    });

    test('resetPassword: เรียก resetPasswordForEmail โดยไม่ส่ง redirectTo', () async {
      await authService.resetPassword('user@shop.com');
      expect(fakeAuth.lastResetEmail, 'user@shop.com');
      expect(fakeAuth.lastResetRedirectTo, isNull);
    });

    test('verifyRecoveryCode: เรียก verifyOTP ด้วย OtpType.recovery และตั้ง inPasswordRecovery', () async {
      expect(authService.inPasswordRecovery.value, false);
      final res = await authService.verifyRecoveryCode('user@shop.com', '123456');

      expect(fakeAuth.lastVerifyEmail, 'user@shop.com');
      expect(fakeAuth.lastVerifyToken, '123456');
      expect(fakeAuth.lastVerifyType, OtpType.recovery);
      expect(res.session?.accessToken, 'test-token');
      expect(authService.inPasswordRecovery.value, true);
    });

    test('verifyRecoveryCode ล้มเหลว: คืนค่า inPasswordRecovery เป็น false', () async {
      fakeAuth.shouldThrow = true;
      fakeAuth.exceptionToThrow = const AuthApiException('Invalid code', statusCode: '400', code: 'otp_expired');

      await expectLater(
        () => authService.verifyRecoveryCode('user@shop.com', '000000'),
        throwsA(isA<AuthException>()),
      );
      expect(authService.inPasswordRecovery.value, false);
    });
  });
}
