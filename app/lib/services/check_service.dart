import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'report_service.dart' show noInternetMessage;

/// ระดับความเสี่ยงที่ Edge Function check-customer ส่งกลับมา
enum RiskLevel {
  green('green', 'ความเสี่ยงต่ำ'),
  yellow('yellow', 'ควรระวัง'),
  red('red', 'ความเสี่ยงสูง');

  const RiskLevel(this.value, this.label);

  final String value;

  /// ข้อความกำกับสี ต้องแสดงคู่กับสีเสมอ
  final String label;

  static RiskLevel? fromValue(Object? v) {
    for (final l in values) {
      if (l.value == v) return l;
    }
    return null;
  }
}

/// ผลการตรวจสอบลูกค้า
sealed class CheckResult {
  const CheckResult();
}

class CheckOk extends CheckResult {
  const CheckOk({
    required this.level,
    required this.countedReports,
    required this.recommendation,
    required this.phoneMasked,
    this.customerName,
    this.aiUnavailable = false,
  });

  final RiskLevel level;
  final int countedReports;
  final String recommendation;

  /// เช่น 080-XXX-0001 (server mask ให้แล้ว)
  final String phoneMasked;

  /// ชื่อที่แยกได้จากข้อความของผู้ใช้เอง (null เมื่อตรวจด้วยเบอร์ หรือแยกชื่อไม่ได้)
  final String? customerName;

  /// true เมื่อระบบแยกชื่ออัตโนมัติ (AI) ใช้ไม่ได้ ผลจึงมาจาก regex อย่างเดียว
  final bool aiUnavailable;
}

/// ไม่พบเบอร์โทรในข้อความออเดอร์
class CheckNoPhone extends CheckResult {
  const CheckNoPhone();
  String get message => noPhoneMessage;
}

/// เบอร์ที่กรอกเองไม่ใช่เบอร์มือถือไทย (HTTP 400 INVALID_PHONE)
class CheckInvalidPhone extends CheckResult {
  const CheckInvalidPhone();
  String get message => invalidPhoneMessage;
}

class CheckNoInternet extends CheckResult {
  const CheckNoInternet();
  String get message => noInternetMessage;
}

/// error อื่น เช่น session หมดอายุ (401) หรือ server ขัดข้อง (5xx)
class CheckError extends CheckResult {
  const CheckError(this.message);
  final String message;
}

const noPhoneMessage = 'ไม่พบเบอร์โทรในข้อความ กรุณากรอกเบอร์ลูกค้าเอง';
const invalidPhoneMessage = 'เบอร์โทรไม่ถูกต้อง ต้องเป็นเบอร์มือถือไทย 10 หลัก';
const _genericMessage = 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';

/// ผลตรวจของหนึ่งออเดอร์เมื่อตรวจหลายออเดอร์พร้อมกัน
class MultiCheckResult {
  const MultiCheckResult({required this.orderText, required this.result});

  /// ข้อความออเดอร์ชุดนั้นตามที่ผู้ใช้วาง
  final String orderText;
  final CheckResult result;
}

/// เรียก Edge Function check-customer (token ของผู้ใช้แนบให้อัตโนมัติ)
/// ทดสอบ widget ได้โดยสร้าง fake ที่ implements CheckService
class CheckService {
  CheckService(this._functions, {this.timeout = const Duration(seconds: 25)});

  final FunctionsClient _functions;

  /// Gemini ใน Edge Function ถูกจำกัดไว้ 10 วินาทีแล้ว เผื่อเวลาเครือข่าย
  final Duration timeout;

  /// ส่งข้อความออเดอร์ทั้งก้อน server เป็นคนแยกชื่อและเบอร์
  Future<CheckResult> checkText(String text) => _invoke({'text': text});

  /// ส่งเบอร์ตามที่ผู้ใช้กรอก server เป็นคน normalize และ hash
  Future<CheckResult> checkPhone(String phone) => _invoke({'phone': phone});

  /// ตรวจหลายออเดอร์ทีละออเดอร์ตามลำดับ (ไม่ส่งพร้อมกันเพราะติด rate limit)
  /// [onResult] ถูกเรียกทุกครั้งที่ได้ผลหนึ่งออเดอร์ ใช้แสดงผลสะสมระหว่างรอ
  Future<List<MultiCheckResult>> checkMultiple(
    List<String> orders, {
    void Function(MultiCheckResult result)? onResult,
  }) async {
    final results = <MultiCheckResult>[];
    for (final order in orders) {
      final result = MultiCheckResult(
        orderText: order,
        result: await checkText(order),
      );
      results.add(result);
      onResult?.call(result);
    }
    return results;
  }

  Future<CheckResult> _invoke(Map<String, String> body) async {
    try {
      final res = await _functions
          .invoke('check-customer', body: body)
          .timeout(timeout);
      return checkResultFromData(res.data);
    } on FunctionsFetchException {
      // ส่ง request ไม่ถึง server
      return const CheckNoInternet();
    } on FunctionException catch (e) {
      return checkResultFromError(e.status, e.details);
    } on TimeoutException {
      return const CheckNoInternet();
    } catch (e) {
      // error ระดับ network ที่หลุดมาตอนอ่าน response
      final text = e.toString();
      if (text.contains('SocketException') ||
          text.contains('ClientException') ||
          text.contains('Failed host lookup')) {
        return const CheckNoInternet();
      }
      return const CheckError(_genericMessage);
    }
  }
}

/// แปลง response 2xx เป็น [CheckResult]
CheckResult checkResultFromData(Object? data) {
  if (data is! Map) return const CheckError(_genericMessage);
  switch (data['status']) {
    case 'NO_PHONE_DETECTED':
      return const CheckNoPhone();
    case 'OK':
      final level = RiskLevel.fromValue(data['level']);
      final count = data['counted_reports'];
      final recommendation = _nonEmptyString(data['recommendation']);
      final masked = _nonEmptyString(data['phone_masked']);
      if (level == null || count is! num || recommendation == null || masked == null) {
        return const CheckError(_genericMessage);
      }
      return CheckOk(
        level: level,
        countedReports: count.toInt(),
        recommendation: recommendation,
        phoneMasked: masked,
        customerName: _nonEmptyString(data['customer_name']),
        aiUnavailable: data['ai_unavailable'] == true,
      );
    default:
      return const CheckError(_genericMessage);
  }
}

/// แปลง response ที่ไม่ใช่ 2xx เป็น [CheckResult]
CheckResult checkResultFromError(int status, Object? details) {
  final body = details is Map ? details : const {};
  if (body['status'] == 'INVALID_PHONE') return const CheckInvalidPhone();
  // 400/401/405/500 server ส่งข้อความภาษาไทยมาใน error
  return CheckError(_nonEmptyString(body['error']) ?? _genericMessage);
}

String? _nonEmptyString(Object? v) =>
    v is String && v.trim().isNotEmpty ? v : null;
