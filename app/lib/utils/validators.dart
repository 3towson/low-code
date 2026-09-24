/// ตัวตรวจสอบค่าในฟอร์ม ใช้กับ TextFormField.validator
/// คืนค่า null เมื่อถูกต้อง หรือข้อความเตือนภาษาไทยเมื่อไม่ถูกต้อง
library;

const int minPasswordLength = 8;
const int maxShopNameLength = 100;

final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'กรุณากรอกอีเมล';
  if (!_emailPattern.hasMatch(email)) return 'รูปแบบอีเมลไม่ถูกต้อง';
  return null;
}

/// ใช้ตอนสมัคร: บังคับความยาวขั้นต่ำ
String? validatePassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'กรุณากรอกรหัสผ่าน';
  if (password.length < minPasswordLength) {
    return 'รหัสผ่านต้องมีอย่างน้อย $minPasswordLength ตัวอักษร';
  }
  return null;
}

/// ใช้ตอน login: ตรวจแค่ว่ากรอกแล้ว ความถูกต้องให้ server ตัดสิน
String? validateLoginPassword(String? value) {
  if ((value ?? '').isEmpty) return 'กรุณากรอกรหัสผ่าน';
  return null;
}

String? validateConfirmPassword(String? value, String password) {
  final confirm = value ?? '';
  if (confirm.isEmpty) return 'กรุณายืนยันรหัสผ่าน';
  if (confirm != password) return 'รหัสผ่านไม่ตรงกัน';
  return null;
}

String? validateShopName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) return 'กรุณากรอกชื่อร้าน';
  if (name.length > maxShopNameLength) {
    return 'ชื่อร้านต้องไม่เกิน $maxShopNameLength ตัวอักษร';
  }
  return null;
}
