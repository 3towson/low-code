import 'package:cod_customer_check/services/check_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// จำลองผลของ functions.invoke โดยไม่ยิง network จริง
class FakeFunctionsClient implements FunctionsClient {
  FakeFunctionsClient(this.handler);

  final Future<FunctionResponse> Function() handler;
  String? calledName;
  Object? calledBody;

  @override
  Future<FunctionResponse> invoke(
    String functionName, {
    Map<String, String>? headers,
    Object? body,
    Iterable<dynamic>? files,
    Map<String, dynamic>? queryParameters,
    HttpMethod method = HttpMethod.post,
    String? region,
    Future<void>? abortSignal,
  }) {
    calledName = functionName;
    calledBody = body;
    return handler();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Future<CheckResult> _run(Future<FunctionResponse> Function() handler) {
  return CheckService(FakeFunctionsClient(handler)).checkText('ข้อความ');
}

const _ok = {
  'status': 'OK',
  'level': 'yellow',
  'counted_reports': 1,
  'recommendation': 'ควรโทรหรือทักยืนยันออเดอร์กับลูกค้าก่อนแพ็กสินค้า',
  'customer_name': 'สมชาย',
  'phone_masked': '080-XXX-0002',
  'ai_unavailable': false,
};

void main() {
  test('checkText ส่ง {text} และ checkPhone ส่ง {phone} ไปที่ check-customer',
      () async {
    final fake = FakeFunctionsClient(
        () async => const FunctionResponse(data: _ok, status: 200));
    await CheckService(fake).checkText('ออเดอร์ 0800000002');
    expect(fake.calledName, 'check-customer');
    expect(fake.calledBody, {'text': 'ออเดอร์ 0800000002'});

    await CheckService(fake).checkPhone('๐๘๐-๐๐๐-๐๐๐๒');
    expect(fake.calledBody, {'phone': '๐๘๐-๐๐๐-๐๐๐๒'});
  });

  test('200 OK -> CheckOk ครบทุกฟิลด์', () async {
    final r = await _run(() async => const FunctionResponse(data: _ok, status: 200));
    expect(r, isA<CheckOk>());
    final ok = r as CheckOk;
    expect(ok.level, RiskLevel.yellow);
    expect(ok.countedReports, 1);
    expect(ok.recommendation, _ok['recommendation']);
    expect(ok.customerName, 'สมชาย');
    expect(ok.phoneMasked, '080-XXX-0002');
    expect(ok.aiUnavailable, isFalse);
  });

  test('customer_name null และ ai_unavailable true', () async {
    final r = await _run(() async => FunctionResponse(
        data: {..._ok, 'customer_name': null, 'ai_unavailable': true},
        status: 200));
    final ok = r as CheckOk;
    expect(ok.customerName, isNull);
    expect(ok.aiUnavailable, isTrue);
  });

  test('level ไม่รู้จัก -> CheckError', () async {
    final r = await _run(() async => FunctionResponse(
        data: {..._ok, 'level': 'purple'}, status: 200));
    expect(r, isA<CheckError>());
  });

  test('200 NO_PHONE_DETECTED -> CheckNoPhone', () async {
    final r = await _run(() async => const FunctionResponse(
        data: {'status': 'NO_PHONE_DETECTED'}, status: 200));
    expect(r, isA<CheckNoPhone>());
  });

  test('400 INVALID_PHONE -> CheckInvalidPhone', () async {
    final r = await _run(() async => throw const FunctionsHttpException(
        status: 400, details: {'status': 'INVALID_PHONE'}));
    expect(r, isA<CheckInvalidPhone>());
    expect((r as CheckInvalidPhone).message,
        'เบอร์โทรไม่ถูกต้อง ต้องเป็นเบอร์มือถือไทย 10 หลัก');
  });

  test('ส่ง request ไม่ถึง server -> CheckNoInternet', () async {
    final r = await _run(() async => throw const FunctionsFetchException(
        details: 'ClientException with SocketException: Failed host lookup'));
    expect(r, isA<CheckNoInternet>());
  });

  test('หมดเวลารอ -> CheckNoInternet', () async {
    final service = CheckService(
      FakeFunctionsClient(() => Future.delayed(
          const Duration(seconds: 1),
          () => const FunctionResponse(data: _ok, status: 200))),
      timeout: const Duration(milliseconds: 10),
    );
    expect(await service.checkText('x'), isA<CheckNoInternet>());
  });

  test('401 -> CheckError ใช้ข้อความจาก server', () async {
    final r = await _run(() async => throw const FunctionsHttpException(
        status: 401, details: {'error': 'กรุณาเข้าสู่ระบบก่อนใช้งาน'}));
    expect(r, isA<CheckError>());
    expect((r as CheckError).message, 'กรุณาเข้าสู่ระบบก่อนใช้งาน');
  });

  test('502 ที่ body ไม่ใช่ JSON -> CheckError ข้อความทั่วไปภาษาไทย', () async {
    final r = await _run(() async =>
        throw const FunctionsHttpException(status: 502, details: 'Bad Gateway'));
    expect(r, isA<CheckError>());
    expect((r as CheckError).message, 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง');
  });
}
