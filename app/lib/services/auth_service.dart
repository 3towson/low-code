import 'package:supabase_flutter/supabase_flutter.dart';

/// ห่อ Supabase Auth ไว้ที่เดียว หน้าอื่นเรียกผ่าน class นี้เท่านั้น
/// (ทดสอบ widget ได้โดยสร้าง fake ที่ implements AuthService)
class AuthService {
  AuthService(
    this._auth, {
    this.functions,
    this.client,
    this.rpcCaller,
  });

  final GoTrueClient _auth;
  final FunctionsClient? functions;
  final SupabaseClient? client;
  final Future<dynamic> Function(String fn, {Map<String, dynamic>? params})?
      rpcCaller;
  bool? _isAdminCached;

  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  Session? get currentSession => _auth.currentSession;

  User? get currentUser => _auth.currentUser;

  /// ชื่อร้านจาก user metadata ถ้าไม่มีใช้ส่วนหน้าของอีเมล (ตรงกับ trigger handle_new_user)
  String get shopName {
    final user = _auth.currentUser;
    final name = (user?.userMetadata?['shop_name'] as String?)?.trim() ?? '';
    if (name.isNotEmpty) return name;
    final email = user?.email ?? '';
    return email.isNotEmpty ? email.split('@').first : 'ร้านค้า';
  }

  /// ตรวจสอบว่าเป็นผู้ดูแลระบบ (Admin) หรือไม่
  bool get isAdmin {
    if (_isAdminCached != null) return _isAdminCached!;
    final user = _auth.currentUser;
    if (user == null) return false;
    final role = user.appMetadata['role'];
    return role == 'admin';
  }

  /// ตรวจสอบสิทธิ์ Admin จาก database RPC is_admin() หรือ fallback ไปที่ appMetadata (P1-2)
  Future<bool> checkIsAdmin() async {
    final user = _auth.currentUser;
    if (user == null) {
      _isAdminCached = false;
      return false;
    }
    if (user.appMetadata['role'] == 'admin') {
      _isAdminCached = true;
      return true;
    }
    try {
      dynamic res;
      if (rpcCaller != null) {
        res = await rpcCaller!('is_admin');
      } else {
        final c = client ?? Supabase.instance.client;
        res = await c.rpc('is_admin');
      }
      _isAdminCached = res == true;
      return _isAdminCached!;
    } catch (_) {
      return isAdmin;
    }
  }

  /// สมัครสมาชิก โปรเจกต์บังคับยืนยันอีเมล จึงยังไม่ได้ session กลับมา
  Future<void> signUp({
    required String email,
    required String password,
    required String shopName,
  }) async {
    await _auth.signUp(
      email: email.trim(),
      password: password,
      data: {'shop_name': shopName.trim()},
    );
  }

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithPassword(email: email.trim(), password: password);
  }

  /// ส่งอีเมลลิงก์สำหรับรีเซ็ตรหัสผ่าน (Forgot Password)
  Future<void> resetPassword({required String email, String? redirectTo}) async {
    await _auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: redirectTo ?? 'https://3towson.github.io/low-code/reset-password.html',
    );
  }

  /// ล้าง session ในเครื่องก่อนแล้วค่อยแจ้ง server ถ้าแจ้ง server ไม่สำเร็จ
  /// (เช่นไม่มีเน็ต) ผู้ใช้ก็ออกจากระบบในเครื่องแล้ว จึงไม่ต้องแสดง error
  Future<void> signOut() async {
    _isAdminCached = null;
    try {
      await _auth.signOut();
    } on AuthException {
      // ignore
    }
  }

  /// ลบบัญชีผู้ใช้ถาวรผ่าน Edge Function 'delete-account' (ตามเกณฑ์ Apple 5.1.1(v) และ Google Play)
  Future<void> deleteAccount() async {
    final funcClient = functions ?? Supabase.instance.client.functions;
    try {
      final res = await funcClient.invoke('delete-account');
      if (res.status >= 400) {
        final data = res.data;
        final msg = (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'ลบบัญชีไม่สำเร็จ';
        throw Exception(msg);
      }
    } on FunctionsFetchException {
      throw Exception(_noInternet);
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map && details['error'] != null) {
        throw Exception(details['error'].toString());
      }
      throw Exception('ลบบัญชีไม่สำเร็จ (${e.status})');
    }
    await signOut();
  }
}

/// แปลง error จาก Supabase Auth เป็นข้อความภาษาไทยที่ผู้ใช้เข้าใจได้
String authErrorMessage(Object error) {
  if (error is AuthRetryableFetchException) {
    // statusCode เป็น null เมื่อส่ง request ไม่ถึง server (ไม่มีเน็ต, DNS, timeout)
    if (error.statusCode == null) return _noInternet;
    return 'เซิร์ฟเวอร์ขัดข้องชั่วคราว กรุณาลองใหม่อีกครั้ง';
  }

  if (error is AuthException) {
    final code = error.code;
    final message = error.message.toLowerCase();

    if (code == 'invalid_credentials' ||
        message.contains('invalid login credentials')) {
      return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
    }
    if (code == 'email_not_confirmed' ||
        message.contains('email not confirmed')) {
      return 'ยังไม่ได้ยืนยันอีเมล กรุณากดลิงก์ยืนยันในอีเมลก่อนเข้าสู่ระบบ';
    }
    switch (code) {
      case 'user_already_exists':
      case 'email_exists':
        return 'อีเมลนี้ถูกใช้สมัครแล้ว';
      case 'weak_password':
        return 'รหัสผ่านไม่ปลอดภัยพอ กรุณาตั้งรหัสผ่านที่คาดเดายากกว่านี้';
      case 'email_address_invalid':
        return 'รูปแบบอีเมลไม่ถูกต้อง';
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return 'ทำรายการบ่อยเกินไป กรุณารอสักครู่แล้วลองใหม่';
      case 'signup_disabled':
        return 'ระบบปิดรับสมัครชั่วคราว';
    }
    return _generic;
  }

  // error ระดับ network ที่หลุดมาโดยไม่ถูกห่อเป็น AuthException
  final text = error.toString();
  if (text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup')) {
    return _noInternet;
  }
  return _generic;
}

const _noInternet =
    'ไม่สามารถเชื่อมต่ออินเทอร์เน็ตได้ กรุณาตรวจสอบการเชื่อมต่อแล้วลองใหม่';
const _generic = 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';
