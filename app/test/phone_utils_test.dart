import 'package:cod_customer_check/utils/phone_utils.dart';
import 'package:flutter_test/flutter_test.dart';

// เคสเดียวกับ supabase/functions/_shared/phone.test.ts (ส่วนที่ 4)
const _valid = [
  '081-234-5678',
  '081 234 5678',
  '+66812345678',
  '66812345678',
  '๐๘๑๒๓๔๕๖๗๘',
  '(081)2345678',
];

const _invalid = ['02-123-4567', '12345', '08123456789', '0512345678', ''];

void main() {
  group('normalizeThaiPhone', () {
    for (final raw in _valid) {
      test('"$raw" -> 0812345678', () {
        expect(normalizeThaiPhone(raw), '0812345678');
      });
    }
    for (final raw in _invalid) {
      test('"$raw" -> null', () {
        expect(normalizeThaiPhone(raw), isNull);
      });
    }
    test('null -> null', () {
      expect(normalizeThaiPhone(null), isNull);
    });
  });

  group('validateThaiPhone', () {
    test('เบอร์ถูกต้องทุกรูปแบบผ่าน', () {
      for (final raw in _valid) {
        expect(validateThaiPhone(raw), isNull, reason: raw);
      }
    });
    test('ว่างหรือ null', () {
      expect(validateThaiPhone(''), 'กรุณากรอกเบอร์โทร');
      expect(validateThaiPhone('   '), 'กรุณากรอกเบอร์โทร');
      expect(validateThaiPhone(null), 'กรุณากรอกเบอร์โทร');
    });
    test('เบอร์ผิด', () {
      for (final raw in _invalid.where((s) => s.isNotEmpty)) {
        expect(validateThaiPhone(raw),
            'เบอร์โทรไม่ถูกต้อง ต้องเป็นเบอร์มือถือไทย 10 หลัก',
            reason: raw);
      }
    });
  });
}
