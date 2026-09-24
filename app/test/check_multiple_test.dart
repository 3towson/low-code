import 'package:cod_customer_check/services/check_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ใช้ checkMultiple ตัวจริง แต่แทน checkText ด้วยการตอบผลที่เทสต์กำหนด
class _ScriptedCheckService extends CheckService {
  _ScriptedCheckService(this.responses)
    : super(FunctionsClient('http://localhost', const {}));

  final Map<String, CheckResult> responses;
  final calls = <String>[];

  /// จำนวนคำขอที่กำลังรอผลพร้อมกันมากที่สุด (ต้องเป็น 1 ถ้าตรวจทีละออเดอร์)
  int maxInFlight = 0;
  int _inFlight = 0;

  @override
  Future<CheckResult> checkText(String text) async {
    calls.add(text);
    _inFlight++;
    if (_inFlight > maxInFlight) maxInFlight = _inFlight;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    _inFlight--;
    return responses[text]!;
  }
}

CheckOk _ok(RiskLevel level, String masked) => CheckOk(
  level: level,
  countedReports: level.index,
  recommendation: 'คำแนะนำ ${level.value}',
  phoneMasked: masked,
);

void main() {
  test('เรียก checkText ครบตามจำนวนออเดอร์ ตามลำดับ และทีละออเดอร์', () async {
    final responses = {
      'ออเดอร์ 1': _ok(RiskLevel.green, '080-XXX-0001'),
      'ออเดอร์ 2': _ok(RiskLevel.yellow, '080-XXX-0002'),
      'ออเดอร์ 3': _ok(RiskLevel.red, '080-XXX-0003'),
    };
    final service = _ScriptedCheckService(responses);

    await service.checkMultiple(responses.keys.toList());

    expect(service.calls, ['ออเดอร์ 1', 'ออเดอร์ 2', 'ออเดอร์ 3']);
    expect(service.maxInFlight, 1);
  });

  test(
    'ผลลัพธ์ตรงกับ checkText ของแต่ละออเดอร์ และเก็บข้อความออเดอร์ไว้',
    () async {
      final responses = <String, CheckResult>{
        'ออเดอร์ 1': _ok(RiskLevel.red, '080-XXX-0001'),
        'ออเดอร์ 2': const CheckNoInternet(),
        'ออเดอร์ 3': const CheckNoPhone(),
        'ออเดอร์ 4': _ok(RiskLevel.green, '080-XXX-0004'),
      };
      final service = _ScriptedCheckService(responses);

      final results = await service.checkMultiple(responses.keys.toList());

      expect(results.map((r) => r.orderText), responses.keys);
      for (final r in results) {
        expect(r.result, same(responses[r.orderText]));
      }
    },
  );

  test('onResult ถูกเรียกทุกออเดอร์ตามลำดับก่อนจบ', () async {
    final responses = {
      'ออเดอร์ 1': _ok(RiskLevel.green, '080-XXX-0001'),
      'ออเดอร์ 2': _ok(RiskLevel.red, '080-XXX-0002'),
    };
    final service = _ScriptedCheckService(responses);
    final progress = <String>[];

    final results = await service.checkMultiple(
      responses.keys.toList(),
      onResult: (r) => progress.add('${r.orderText}:${service.calls.length}'),
    );

    // ผลออเดอร์แรกมาถึงก่อนเริ่มส่งออเดอร์ที่สอง
    expect(progress, ['ออเดอร์ 1:1', 'ออเดอร์ 2:2']);
    expect(results, hasLength(2));
  });

  test('ไม่มีออเดอร์ ไม่เรียก checkText และคืนรายการว่าง', () async {
    final service = _ScriptedCheckService(const {});

    final results = await service.checkMultiple(const []);

    expect(results, isEmpty);
    expect(service.calls, isEmpty);
  });
}
