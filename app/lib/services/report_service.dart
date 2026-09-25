import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../localization/app_strings.dart';

/// ค่า platform ที่ Edge Function รับ ([value] คือค่าที่ส่งจริง)
enum ReportPlatform {
  shopee('shopee', 'Shopee'),
  lazada('lazada', 'Lazada'),
  facebook('facebook', 'Facebook'),
  line('line', 'LINE'),
  tiktok('tiktok', 'TikTok'),
  other('other', 'อื่นๆ');

  const ReportPlatform(this.value, this.label);

  final String value;
  final String label;

  String localizedLabel(AppStrings strings) {
    if (this == other) return strings.reasonOther;
    return label;
  }
}

/// ค่า reason ที่ Edge Function รับ ([value] คือค่าที่ส่งจริง)
enum ReportReason {
  refusedDelivery('refused_delivery', 'ปฏิเสธรับสินค้า'),
  unreachable('unreachable', 'ติดต่อไม่ได้'),
  fakeAddress('fake_address', 'ที่อยู่ปลอมหรือผิด'),
  other('other', 'อื่นๆ');

  const ReportReason(this.value, this.label);

  final String value;
  final String label;

  String localizedLabel(AppStrings strings) {
    switch (this) {
      case refusedDelivery:
        return strings.reasonRefused;
      case unreachable:
        return strings.reasonUnreachable;
      case fakeAddress:
        return strings.reasonFakeAddress;
      case other:
        return strings.reasonOther;
    }
  }
}

class ReportInput {
  const ReportInput({
    required this.customerName,
    required this.phone,
    required this.platform,
    required this.reason,
    this.amount,
  });

  final String customerName;

  /// เบอร์ตามที่ผู้ใช้กรอก Edge Function เป็นคน normalize และ hash
  final String phone;
  final ReportPlatform platform;
  final ReportReason reason;
  final num? amount;

  Map<String, dynamic> toJson() => {
        'customer_name': customerName.trim(),
        'phone': phone,
        'platform': platform.value,
        'reason': reason.value,
        if (amount != null) 'amount': amount,
      };
}

/// ผลการส่งรายงาน
sealed class ReportResult {
  const ReportResult();
}

class ReportSuccess extends ReportResult {
  const ReportSuccess();
}

/// ร้านนี้รายงานเบอร์นี้ไปแล้วในช่วง 7 วัน (HTTP 409)
class ReportDuplicate extends ReportResult {
  const ReportDuplicate(this.message);
  final String message;
}

/// server ตรวจแล้วข้อมูลไม่ถูกต้อง (HTTP 400) [messages] เป็นข้อความจาก server
class ReportInvalid extends ReportResult {
  const ReportInvalid(this.messages);
  final List<String> messages;
}

class ReportNoInternet extends ReportResult {
  const ReportNoInternet();
  String get message => noInternetMessage;
}

/// error อื่น เช่น session หมดอายุ (401) หรือ server ขัดข้อง (5xx)
class ReportError extends ReportResult {
  const ReportError(this.message);
  final String message;
}

const noInternetMessage =
    'ไม่สามารถเชื่อมต่ออินเทอร์เน็ตได้ กรุณาตรวจสอบการเชื่อมต่อแล้วลองใหม่';
const _genericMessage = 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';
const _duplicateFallback = 'คุณรายงานเบอร์นี้ไปแล้วในช่วง 7 วันที่ผ่านมา';
const _invalidFallback = 'ข้อมูลไม่ถูกต้อง กรุณาตรวจสอบแล้วลองใหม่';

/// เรียก Edge Function report-customer (token ของผู้ใช้แนบให้อัตโนมัติ)
/// ทดสอบ widget ได้โดยสร้าง fake ที่ implements ReportService
class ReportService {
  ReportService(this._functions, {this.timeout = const Duration(seconds: 20)});

  final FunctionsClient _functions;
  final Duration timeout;

  Future<ReportResult> submit(ReportInput input) async {
    try {
      final res = await _functions
          .invoke('report-customer', body: input.toJson())
          .timeout(timeout);
      final data = res.data;
      if (data is Map && data['status'] == 'CREATED') return const ReportSuccess();
      return const ReportError(_genericMessage);
    } on FunctionsFetchException {
      // ส่ง request ไม่ถึง server
      return const ReportNoInternet();
    } on FunctionException catch (e) {
      return reportResultFromError(e.status, e.details);
    } on TimeoutException {
      return const ReportNoInternet();
    } catch (e) {
      // error ระดับ network ที่หลุดมาตอนอ่าน response
      final text = e.toString();
      if (text.contains('SocketException') ||
          text.contains('ClientException') ||
          text.contains('Failed host lookup')) {
        return const ReportNoInternet();
      }
      return const ReportError(_genericMessage);
    }
  }
}

/// แปลง response ที่ไม่ใช่ 2xx เป็น [ReportResult]
ReportResult reportResultFromError(int status, Object? details) {
  final body = details is Map ? details : const {};

  if (status == 409 || body['status'] == 'DUPLICATE') {
    return ReportDuplicate(_nonEmptyString(body['message']) ?? _duplicateFallback);
  }

  if (status == 400 || body['status'] == 'INVALID_INPUT') {
    final errors = body['errors'];
    final messages = <String>[
      if (errors is List)
        for (final e in errors)
          if (e is Map && _nonEmptyString(e['message']) != null)
            _nonEmptyString(e['message'])!,
    ];
    return ReportInvalid(messages.isEmpty ? const [_invalidFallback] : messages);
  }

  // 401/403/405/500 server ส่งข้อความภาษาไทยมาใน error
  return ReportError(_nonEmptyString(body['error']) ?? _genericMessage);
}

String? _nonEmptyString(Object? v) =>
    v is String && v.trim().isNotEmpty ? v : null;
