/// ตรวจเบอร์โทรในฟอร์มฝั่งแอป กฎเดียวกับ supabase/functions/_shared/phone.ts
/// ใช้แค่ตรวจว่ากรอกถูกก่อนส่ง แอปส่งเบอร์ตามที่ผู้ใช้กรอกไป
/// ให้ Edge Function normalize และ hash เอง ห้าม hash ในแอป
library;

final RegExp _thaiMobile = RegExp(r'^0[689]\d{8}$');
final RegExp _nonDigit = RegExp(r'\D');

/// แปลงเลขไทย ๐-๙ (U+0E50-U+0E59) เป็น 0-9
String _thaiDigitsToArabic(String s) {
  return String.fromCharCodes(
    s.runes.map((c) => c >= 0x0E50 && c <= 0x0E59 ? c - 0x0E50 + 0x30 : c),
  );
}

/// คืนเบอร์มือถือไทยรูปแบบ 0XXXXXXXXX หรือ null ถ้าไม่ใช่เบอร์มือถือไทย
String? normalizeThaiPhone(String? raw) {
  var digits = _thaiDigitsToArabic(raw ?? '').replaceAll(_nonDigit, '');
  if (digits.startsWith('66') && digits.length == 11) {
    digits = '0${digits.substring(2)}';
  }
  return _thaiMobile.hasMatch(digits) ? digits : null;
}

/// ใช้กับ TextFormField.validator
String? validateThaiPhone(String? value) {
  if ((value ?? '').trim().isEmpty) return 'กรุณากรอกเบอร์โทร';
  if (normalizeThaiPhone(value) == null) {
    return 'เบอร์โทรไม่ถูกต้อง ต้องเป็นเบอร์มือถือไทย 10 หลัก';
  }
  return null;
}
