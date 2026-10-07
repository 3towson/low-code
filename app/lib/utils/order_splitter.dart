/// แยกข้อความที่วางมาหลายออเดอร์เป็นออเดอร์ละก้อน
/// ใช้แค่ตัดสินว่ามีเบอร์หรือไม่ แอปยังส่งข้อความตามที่ผู้ใช้วางไปให้ Edge Function
library;

import 'phone_utils.dart';

/// จำนวนออเดอร์สูงสุดที่ตรวจได้ต่อครั้ง
const maxOrdersPerCheck = 10;

/// บรรทัดว่างตั้งแต่ 1 บรรทัดขึ้นไป (บรรทัดที่มีแต่ช่องว่างก็นับเป็นบรรทัดว่าง)
final RegExp _blankLines = RegExp(r'\n[ \t]*(?:\n[ \t]*)+');

/// เส้นคั่นออเดอร์ เช่น ---, ===, ___, *** (อย่างน้อย 3 ตัว) คั่นบรรทัด
final RegExp _dividerLine = RegExp(r'(?:^|\n)[ \t]*[-=_*~]{3,}[ \t]*(?:\n|$)');

/// ชุดตัวเลข (อารบิกหรือไทย) ที่คั่นด้วยช่องว่าง ขีด จุด หรือวงเล็บ เช่น +66 81-234-5678
final RegExp _digitRun = RegExp(r'[0-9๐-๙]+(?:[ \t\-.()]+[0-9๐-๙]+)*');
final RegExp _digitGroup = RegExp(r'[0-9๐-๙]+');

/// ดึงเบอร์มือถือไทยเบอร์แรกที่พบในข้อความ (normalize เป็น 0XXXXXXXXX แล้ว)
/// หรือ null ถ้าไม่พบเบอร์มือถือไทย
String? extractFirstThaiMobile(String text) {
  for (final run in _digitRun.allMatches(text)) {
    final groups = _digitGroup.allMatches(run[0]!).map((m) => m[0]!).toList();
    for (var i = 0; i < groups.length; i++) {
      var digits = '';
      for (var j = i; j < groups.length && digits.length < 11; j++) {
        digits += groups[j];
        final normalized = normalizeThaiPhone(digits);
        if (normalized != null) return normalized;
      }
    }
  }
  return null;
}

/// true เมื่อข้อความมีเบอร์มือถือไทยอยู่ด้วย
bool containsThaiMobile(String text) => extractFirstThaiMobile(text) != null;

/// ตัดรายการที่มีเบอร์ซ้ำกันออก เก็บเฉพาะรายการแรกที่พบ
List<String> _deduplicateByPhone(List<String> items) {
  final seen = <String>{};
  final unique = <String>[];
  for (final item in items) {
    final phone = extractFirstThaiMobile(item);
    if (phone == null || seen.add(phone)) {
      unique.add(item);
    }
  }
  return unique;
}

/// แยกข้อความเป็นออเดอร์ด้วยบรรทัดว่าง เก็บเฉพาะก้อนที่มีเบอร์มือถือไทยและไม่ซ้ำเบอร์
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
  final normalized = text.replaceAll('\r\n', '\n');

  // 1) หากมีเส้นคั่น เช่น ---, ===, *** ให้ตัดแบ่งตามเส้นคั่นก่อน
  // เพื่อรักษาเนื้อหาภายในออเดอร์ (เช่น กรณีมีเว้นบรรทัดย่อยในออเดอร์เดียวกัน) ไว้ครบถ้วน
  if (_dividerLine.hasMatch(normalized)) {
    final dividerSeparated = normalized
        .split(_dividerLine)
        .map((chunk) => chunk.trim())
        .where((chunk) => chunk.isNotEmpty && containsThaiMobile(chunk))
        .toList();
    if (dividerSeparated.length > 1) {
      return _deduplicateByPhone(dividerSeparated);
    }
  }

  // 2) แบ่งด้วยบรรทัดว่าง (blank lines)
  final blankSeparated = normalized
      .split(_blankLines)
      .map((chunk) => chunk.trim())
      .where((chunk) => chunk.isNotEmpty && containsThaiMobile(chunk))
      .toList();

  if (blankSeparated.length > 1) {
    return _deduplicateByPhone(blankSeparated);
  }

  // กรณีวางเบอร์เรียงทีละบรรทัด หรือคั่นด้วย comma/semicolon โดยไม่มีบรรทัดว่าง
  final lines = text
      .replaceAll('\r\n', '\n')
      .split(RegExp(r'[\n,;]+'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  if (lines.length > 1 && lines.every((l) => containsThaiMobile(l))) {
    return _deduplicateByPhone(lines);
  }

  return blankSeparated;
}
