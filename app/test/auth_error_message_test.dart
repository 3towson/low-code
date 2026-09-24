import 'package:cod_customer_check/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('authErrorMessage', () {
    test('รหัสผ่านผิด (มี code)', () {
      const e = AuthApiException('Invalid login credentials',
          statusCode: '400', code: 'invalid_credentials');
      expect(authErrorMessage(e), 'อีเมลหรือรหัสผ่านไม่ถูกต้อง');
    });
    test('รหัสผ่านผิด (server ไม่ส่ง code)', () {
      const e = AuthException('Invalid login credentials', statusCode: '400');
      expect(authErrorMessage(e), 'อีเมลหรือรหัสผ่านไม่ถูกต้อง');
    });
    test('ยังไม่ยืนยันอีเมล', () {
      const e = AuthApiException('Email not confirmed',
          statusCode: '400', code: 'email_not_confirmed');
      expect(authErrorMessage(e),
          'ยังไม่ได้ยืนยันอีเมล กรุณากดลิงก์ยืนยันในอีเมลก่อนเข้าสู่ระบบ');
    });
    test('ไม่มีอินเทอร์เน็ต', () {
      final e = AuthRetryableFetchException(
          message: 'ClientException with SocketException: Failed host lookup');
      expect(authErrorMessage(e),
          'ไม่สามารถเชื่อมต่ออินเทอร์เน็ตได้ กรุณาตรวจสอบการเชื่อมต่อแล้วลองใหม่');
    });
    test('เซิร์ฟเวอร์ 5xx ไม่นับเป็นปัญหาเน็ต', () {
      final e = AuthRetryableFetchException(message: 'x', statusCode: '503');
      expect(authErrorMessage(e),
          'เซิร์ฟเวอร์ขัดข้องชั่วคราว กรุณาลองใหม่อีกครั้ง');
    });
    test('error ที่ไม่รู้จักไม่แสดงข้อความภาษาอังกฤษ', () {
      const e = AuthApiException('Something odd', statusCode: '400', code: 'x');
      expect(authErrorMessage(e), 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง');
    });
  });
}
