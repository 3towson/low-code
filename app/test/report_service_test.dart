import 'package:cod_customer_check/services/report_service.dart';
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

const _input = ReportInput(
  customerName: '  สมชาย  ',
  phone: '๐๘๑-๒๓๔-๕๖๗๘',
  platform: ReportPlatform.line,
  reason: ReportReason.fakeAddress,
  evidencePath: 'user123/evidence.jpg',
);

Future<ReportResult> _run(Future<FunctionResponse> Function() handler) {
  return ReportService(FakeFunctionsClient(handler)).submit(_input);
}

void main() {
  test('ส่งไปที่ report-customer ด้วยค่า enum และไม่ส่ง amount เมื่อไม่กรอก',
      () async {
    final fake = FakeFunctionsClient(
        () async => const FunctionResponse(data: {'status': 'CREATED'}, status: 201));
    await ReportService(fake).submit(_input);
    expect(fake.calledName, 'report-customer');
    expect(fake.calledBody, {
      'customer_name': 'สมชาย',
      'phone': '๐๘๑-๒๓๔-๕๖๗๘',
      'platform': 'line',
      'reason': 'fake_address',
      'evidence_path': 'user123/evidence.jpg',
    });
  });

  test('ส่ง other_details และ evidence_path ไปที่ report-customer เมื่อมีค่า', () async {
    final fake = FakeFunctionsClient(
        () async => const FunctionResponse(data: {'status': 'CREATED'}, status: 201));
    const inputWithOther = ReportInput(
      customerName: 'สมศักดิ์',
      phone: '0812345678',
      platform: ReportPlatform.other,
      reason: ReportReason.other,
      evidencePath: 'user123/evidence2.jpg',
      otherDetails: 'เหตุผล: ขอยกเลิกกลางคัน',
    );
    await ReportService(fake).submit(inputWithOther);
    expect(fake.calledBody, {
      'customer_name': 'สมศักดิ์',
      'phone': '0812345678',
      'platform': 'other',
      'reason': 'other',
      'evidence_path': 'user123/evidence2.jpg',
      'other_details': 'เหตุผล: ขอยกเลิกกลางคัน',
    });
  });

  test('ส่ง amount: 0 ได้ถูกต้อง', () async {
    final fake = FakeFunctionsClient(
        () async => const FunctionResponse(data: {'status': 'CREATED'}, status: 201));
    const inputWithZero = ReportInput(
      customerName: 'สมศักดิ์',
      phone: '0812345678',
      platform: ReportPlatform.shopee,
      reason: ReportReason.refusedDelivery,
      evidencePath: 'user123/evidence0.jpg',
      amount: 0,
    );
    await ReportService(fake).submit(inputWithZero);
    expect(fake.calledBody, containsPair('amount', 0));
  });

  test('201 CREATED -> ReportSuccess', () async {
    final r = await _run(() async =>
        const FunctionResponse(data: {'status': 'CREATED'}, status: 201));
    expect(r, isA<ReportSuccess>());
  });

  test('409 DUPLICATE -> ReportDuplicate พร้อมข้อความจาก server', () async {
    final r = await _run(() async => throw const FunctionsHttpException(
          status: 409,
          details: {'status': 'DUPLICATE', 'message': 'ข้อความจาก server'},
        ));
    expect(r, isA<ReportDuplicate>());
    expect((r as ReportDuplicate).message, 'ข้อความจาก server');
  });

  test('400 INVALID_INPUT -> ReportInvalid พร้อมข้อความทุก field', () async {
    final r = await _run(() async => throw const FunctionsHttpException(
          status: 400,
          details: {
            'status': 'INVALID_INPUT',
            'errors': [
              {'field': 'phone', 'message': 'เบอร์ไม่ถูก'},
              {'field': 'customer_name', 'message': 'ชื่อไม่ถูก'},
            ],
          },
        ));
    expect(r, isA<ReportInvalid>());
    expect((r as ReportInvalid).messages, ['เบอร์ไม่ถูก', 'ชื่อไม่ถูก']);
  });

  test('details เป็น JSON String สามารถแกะข้อความ error ได้ถูกต้อง', () async {
    final r = await _run(() async => throw const FunctionsHttpException(
          status: 400,
          details: '{"status":"INVALID_INPUT","errors":[{"field":"evidence_path","message":"กรุณาแนบรูปภาพหลักฐาน"}]}',
        ));
    expect(r, isA<ReportInvalid>());
    expect((r as ReportInvalid).messages, ['กรุณาแนบรูปภาพหลักฐาน']);
  });

  test('ส่ง request ไม่ถึง server -> ReportNoInternet', () async {
    final r = await _run(() async => throw const FunctionsFetchException(
        details: 'ClientException with SocketException: Failed host lookup'));
    expect(r, isA<ReportNoInternet>());
  });

  test('401 -> ReportError ใช้ข้อความจาก server', () async {
    final r = await _run(() async => throw const FunctionsHttpException(
        status: 401, details: {'error': 'กรุณาเข้าสู่ระบบก่อนใช้งาน'}));
    expect(r, isA<ReportError>());
    expect((r as ReportError).message, 'กรุณาเข้าสู่ระบบก่อนใช้งาน');
  });

  test('403 -> ReportError ข้อความเตือนยืนยันอีเมลจาก server', () async {
    final r = await _run(() async => throw const FunctionsHttpException(
        status: 403, details: {'error': 'กรุณายืนยันอีเมลก่อนรายงานลูกค้า'}));
    expect(r, isA<ReportError>());
    expect((r as ReportError).message, 'กรุณายืนยันอีเมลก่อนรายงานลูกค้า');
  });

  test('500 ที่ body ไม่ใช่ JSON -> ReportError ข้อความทั่วไปภาษาไทย', () async {
    final r = await _run(() async => throw const FunctionsHttpException(
        status: 502, details: 'Bad Gateway'));
    expect(r, isA<ReportError>());
    expect((r as ReportError).message, 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง');
  });
}
