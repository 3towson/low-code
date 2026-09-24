import 'package:cod_customer_check/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateEmail', () {
    test('อีเมลถูกต้อง', () {
      expect(validateEmail('shop@example.com'), isNull);
      expect(validateEmail('a.b+c@sub.example.co.th'), isNull);
    });
    test('ตัดช่องว่างหัวท้ายก่อนตรวจ', () {
      expect(validateEmail('  shop@example.com  '), isNull);
    });
    test('ว่างหรือ null', () {
      expect(validateEmail(''), 'กรุณากรอกอีเมล');
      expect(validateEmail('   '), 'กรุณากรอกอีเมล');
      expect(validateEmail(null), 'กรุณากรอกอีเมล');
    });
    test('รูปแบบผิด', () {
      for (final bad in [
        'shop',
        'shop@',
        '@example.com',
        'shop@example',
        'shop example@x.com',
        'shop@@example.com',
      ]) {
        expect(validateEmail(bad), 'รูปแบบอีเมลไม่ถูกต้อง', reason: bad);
      }
    });
  });

  group('validatePassword (สมัคร)', () {
    test('ยาว 8 ตัวพอดีผ่าน', () {
      expect(validatePassword('12345678'), isNull);
    });
    test('ยาวกว่า 8 มีช่องว่างหรือภาษาไทยก็ผ่าน', () {
      expect(validatePassword('pass word 123'), isNull);
      expect(validatePassword('รหัสผ่านยาวพอ'), isNull);
    });
    test('ว่างหรือ null', () {
      expect(validatePassword(''), 'กรุณากรอกรหัสผ่าน');
      expect(validatePassword(null), 'กรุณากรอกรหัสผ่าน');
    });
    test('สั้นกว่า 8 ตัว', () {
      expect(validatePassword('1234567'), 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร');
      expect(validatePassword('a'), 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร');
    });
  });

  group('validateLoginPassword', () {
    test('กรอกแล้วผ่านโดยไม่สนความยาว', () {
      expect(validateLoginPassword('x'), isNull);
    });
    test('ว่างหรือ null', () {
      expect(validateLoginPassword(''), 'กรุณากรอกรหัสผ่าน');
      expect(validateLoginPassword(null), 'กรุณากรอกรหัสผ่าน');
    });
  });

  group('validateConfirmPassword', () {
    test('ตรงกันผ่าน', () {
      expect(validateConfirmPassword('12345678', '12345678'), isNull);
    });
    test('ว่างหรือ null', () {
      expect(validateConfirmPassword('', '12345678'), 'กรุณายืนยันรหัสผ่าน');
      expect(validateConfirmPassword(null, '12345678'), 'กรุณายืนยันรหัสผ่าน');
    });
    test('ไม่ตรงกัน', () {
      expect(validateConfirmPassword('12345679', '12345678'),
          'รหัสผ่านไม่ตรงกัน');
    });
  });

  group('validateShopName', () {
    test('ชื่อร้านถูกต้อง', () {
      expect(validateShopName('ร้านป้าแดง'), isNull);
      expect(validateShopName('A'), isNull);
      expect(validateShopName('ก' * 100), isNull);
    });
    test('ว่าง มีแต่ช่องว่าง หรือ null', () {
      expect(validateShopName(''), 'กรุณากรอกชื่อร้าน');
      expect(validateShopName('   '), 'กรุณากรอกชื่อร้าน');
      expect(validateShopName(null), 'กรุณากรอกชื่อร้าน');
    });
    test('ยาวเกิน 100 ตัว', () {
      expect(validateShopName('ก' * 101), 'ชื่อร้านต้องไม่เกิน 100 ตัวอักษร');
    });
  });
}
