/// แยกข้อความที่วางมาหลายออเดอร์เป็นออเดอร์ละก้อน
/// ใช้แค่ตัดสินว่ามีเบอร์หรือไม่ แอปยังส่งข้อความตามที่ผู้ใช้วางไปให้ Edge Function
library;

import 'phone_utils.dart';

/// จำนวนออเดอร์สูงสุดที่ตรวจได้ต่อครั้ง
const maxOrdersPerCheck = 10;

/// บรรทัดว่างตั้งแต่ 1 บรรทัดขึ้นไป (บรรทัดที่มีแต่ช่องว่างก็นับเป็นบรรทัดว่าง)
final RegExp _blankLines = RegExp(r'\n[ \t]*(?:\n[ \t]*)+');

/// ชุดตัวเลข (อารบิกหรือไทย) ที่คั่นด้วยช่องว่าง ขีด จุด หรือวงเล็บ เช่น +66 81-234-5678
final RegExp _digitRun = RegExp(r'[0-9๐-๙]+(?:[ \t\-.()]+[0-9๐-๙]+)*');
final RegExp _digitGroup = RegExp(r'[0-9๐-๙]+');

/// แยกข้อความเป็นออเดอร์ด้วยบรรทัดว่าง เก็บเฉพาะก้อนที่มีเบอร์มือถือไทย
/// ถ้าได้ไม่ถึง 2 ออเดอร์ คืนข้อความทั้งก้อน (ให้ server แยกเองเหมือนเดิม)
/// ได้ไม่เกิน [maxOrdersPerCheck] ออเดอร์ ใช้ [exceedsOrderLimit] เพื่อรู้ว่าถูกตัดหรือไม่
List<String> splitOrders(String text) {
  final orders = _ordersWithPhone(text);
  if (orders.length <= 1) return [text];
  return orders.take(maxOrdersPerCheck).toList();
}

/// true เมื่อข้อความมีออเดอร์ที่มีเบอร์เกิน [maxOrdersPerCheck]
bool exceedsOrderLimit(String text) =>
    _ordersWithPhone(text).length > maxOrdersPerCheck;

List<String> _ordersWithPhone(String text) {
  return text
      .replaceAll('\r\n', '\n')
      .split(_blankLines)
      .map((chunk) => chunk.trim())
      .where((chunk) => chunk.isNotEmpty && containsThaiMobile(chunk))
      .toList();
}

/// true เมื่อข้อความมีเบอร์มือถือไทยอยู่ด้วย
/// ลองต่อกลุ่มตัวเลขที่ติดกันทีละช่วง เพราะเบอร์อาจอยู่ติดกับตัวเลขอื่น
/// เช่น "081 234 5678 บ้านเลขที่ 12"
bool containsThaiMobile(String text) {
  for (final run in _digitRun.allMatches(text)) {
    final groups = _digitGroup.allMatches(run[0]!).map((m) => m[0]!).toList();
    for (var i = 0; i < groups.length; i++) {
      var digits = '';
      for (var j = i; j < groups.length && digits.length < 11; j++) {
        digits += groups[j];
        if (normalizeThaiPhone(digits) != null) return true;
      }
    }
  }
  return false;
}
