import 'package:cod_customer_check/utils/order_splitter.dart';
import 'package:flutter_test/flutter_test.dart';

String _order(int i) =>
    'ลูกค้า $i\nโทร 08000000${i.toString().padLeft(2, '0')}\n'
    'ที่อยู่ $i/1 ถ.สุขุมวิท กทม.';

void main() {
  group('splitOrders', () {
    test('ข้อความ 3 ชุดแบ่งด้วยบรรทัดว่าง ได้ 3 ออเดอร์', () {
      final text = '${_order(1)}\n\n${_order(2)}\n\n${_order(3)}';
      expect(splitOrders(text), [_order(1), _order(2), _order(3)]);
    });

    test(
      'บรรทัดว่างซ้ำหลายบรรทัด บรรทัดที่มีแต่ช่องว่าง และ CRLF แบ่งได้ถูก',
      () {
        final text = '${_order(1)}\n\n\n\n${_order(2)}\n   \n\t\n${_order(3)}'
            .replaceAll('\n', '\r\n');
        expect(splitOrders(text), [_order(1), _order(2), _order(3)]);
      },
    );

    test('chunk ที่ไม่มีเบอร์ถูกทิ้ง', () {
      final text =
          'สวัสดีค่ะ ออเดอร์วันนี้\n\n${_order(1)}\n\n'
          'ขอบคุณค่ะ\n\n${_order(2)}';
      expect(splitOrders(text), [_order(1), _order(2)]);
    });

    test('ข้อความไม่มีบรรทัดว่างเลย คืนข้อความทั้งก้อน', () {
      final text = '${_order(1)}\n${_order(2)}';
      expect(splitOrders(text), [text]);
    });

    test('แบ่งได้หลายก้อนแต่มีเบอร์แค่ก้อนเดียว คืนข้อความทั้งก้อน', () {
      final text = 'สวัสดีค่ะ\n\n${_order(1)}\n\nขอบคุณค่ะ';
      expect(splitOrders(text), [text]);
    });

    test('ไม่มีเบอร์เลย คืนข้อความทั้งก้อน', () {
      const text = 'สวัสดีค่ะ\n\nขอบคุณค่ะ';
      expect(splitOrders(text), [text]);
    });

    test('เกิน 10 ชุด ได้แค่ 10 ชุดแรก', () {
      final text = List.generate(12, (i) => _order(i + 1)).join('\n\n');
      final orders = splitOrders(text);
      expect(orders, hasLength(maxOrdersPerCheck));
      expect(orders, List.generate(10, (i) => _order(i + 1)));
    });
  });

  group('exceedsOrderLimit', () {
    test('11 ชุดขึ้นไป เป็น true', () {
      final text = List.generate(11, (i) => _order(i + 1)).join('\n\n');
      expect(exceedsOrderLimit(text), isTrue);
    });

    test('10 ชุดพอดี เป็น false', () {
      final text = List.generate(10, (i) => _order(i + 1)).join('\n\n');
      expect(exceedsOrderLimit(text), isFalse);
      expect(splitOrders(text), hasLength(10));
    });
  });

  group('นับว่ามีเบอร์', () {
    const formats = {
      'เลขไทย': 'โทร ๐๘๑๒๓๔๕๖๗๘',
      '+66': 'โทร +66812345678',
      '+66 มีเว้นวรรค': 'โทร +66 81 234 5678',
      'ขีด': 'โทร 081-234-5678',
      'เว้นวรรค': 'โทร 081 234 5678',
      'จุดและวงเล็บ': 'โทร (081) 234.5678',
      'ติดกับตัวเลขอื่น': 'บ้านเลขที่ 12 081 234 5678 หมู่ 4',
    };
    for (final MapEntry(key: name, value: phoneLine) in formats.entries) {
      test('$name: "$phoneLine"', () {
        expect(containsThaiMobile(phoneLine), isTrue);
        final text = 'ลูกค้า ก\n$phoneLine\n\nลูกค้า ข\n$phoneLine';
        expect(splitOrders(text), hasLength(2));
      });
    }

    const notMobile = {
      'เบอร์บ้าน': 'โทร 02-123-4567',
      'สั้นเกินไป': 'โทร 081-234-567',
      'ยาวเกินไปในก้อนเดียว': 'เลขพัสดุ 08123456789',
      'บ้านเลขที่และรหัสไปรษณีย์': '99/12 หมู่ 3 ต.บางพลี 10540',
    };
    for (final MapEntry(key: name, value: line) in notMobile.entries) {
      test('ไม่นับ $name: "$line"', () {
        expect(containsThaiMobile(line), isFalse);
      });
    }
  });
}
