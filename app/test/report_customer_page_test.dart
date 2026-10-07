import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cod_customer_check/pages/report_customer_page.dart';
import 'package:cod_customer_check/services/evidence_storage_service.dart';
import 'package:cod_customer_check/services/report_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _testEvidence = EvidenceFile(
  name: 'slip_chat_evidence.jpg',
  bytes: base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  ),
  extension: 'jpg',
);

class FakeEvidenceStorageService implements EvidenceStorageService {
  @override
  Future<String> uploadEvidence({
    required String userId,
    required Uint8List bytes,
    required String extension,
  }) async {
    return '$userId/mock_evidence.$extension';
  }

  @override
  Future<String> createSignedUrl(String path, {int expiresIn = 900}) async {
    return 'https://example.com/signed/$path';
  }
}

/// ไม่ต่อ Supabase จริง เก็บ input ที่ส่งมา และให้เทสต์เป็นคนปล่อยผลผ่าน [respond]
class FakeReportService implements ReportService {
  final inputs = <ReportInput>[];
  Completer<ReportResult> _pending = Completer();

  void respond(ReportResult result) {
    _pending.complete(result);
    _pending = Completer();
  }

  @override
  Future<ReportResult> submit(ReportInput input) {
    inputs.add(input);
    return _pending.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Finder get _submit => find.byKey(const Key('report-submit'));

Future<void> _pumpPage(
  WidgetTester tester,
  FakeReportService service, {
  EvidenceStorageService? storageService,
  bool attachEvidence = true,
  EvidenceFile? initialEvidence,
  Future<EvidenceFile?> Function()? imagePickerOverride,
}) {
  final resolvedEvidence =
      attachEvidence ? (initialEvidence ?? _testEvidence) : null;
  return tester.pumpWidget(
    MaterialApp(
      home: ReportCustomerPage(
        reportService: service,
        storageService: storageService ?? FakeEvidenceStorageService(),
        initialEvidence: resolvedEvidence,
        imagePickerOverride: imagePickerOverride,
      ),
    ),
  );
}

Future<void> _tapSubmit(WidgetTester tester) async {
  await tester.ensureVisible(_submit);
  await tester.tap(_submit, warnIfMissed: false);
  await tester.pump();
}

Future<void> _select(WidgetTester tester, String key, String label) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _fillValid(WidgetTester tester,
    {String phone = '081-234-5678'}) async {
  await tester.enterText(find.byKey(const Key('report-name')), 'สมชาย ทดสอบ');
  await tester.enterText(find.byKey(const Key('report-phone')), phone);
  await _select(tester, 'report-platform', 'Shopee');
  await _select(tester, 'report-reason', 'ปฏิเสธรับสินค้า');
  await tester.enterText(find.byKey(const Key('report-amount')), '1,500');
}

bool _buttonEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_submit).onPressed != null;

void main() {
  testWidgets('ช่องบังคับว่าง ต้องแสดงข้อความเตือนและไม่ส่ง', (tester) async {
    final service = FakeReportService();
    await _pumpPage(tester, service, attachEvidence: false);

    await _tapSubmit(tester);

    expect(find.text('กรุณากรอกชื่อลูกค้า'), findsOneWidget);
    expect(find.text('กรุณากรอกเบอร์โทร'), findsOneWidget);
    expect(find.text('กรุณาเลือกแพลตฟอร์ม'), findsOneWidget);
    expect(find.text('กรุณาเลือกเหตุผล'), findsOneWidget);
    expect(
        find.text('กรุณาแนบภาพแคปหน้าจอหลักฐาน (แชท/สลิป/ประวัติจัดส่ง)'),
        findsOneWidget);
    expect(service.inputs, isEmpty);
  });

  testWidgets('ไม่ได้แนบรูปหลักฐาน แสดงข้อความเตือนและไม่ส่ง', (tester) async {
    final service = FakeReportService();
    await _pumpPage(tester, service, attachEvidence: false);
    await _fillValid(tester);

    await _tapSubmit(tester);

    expect(find.text('กรุณาแนบภาพแคปหน้าจอหลักฐาน (แชท/สลิป/ประวัติจัดส่ง)'),
        findsOneWidget);
    expect(service.inputs, isEmpty);
  });

  testWidgets('เลือกรูปหลักฐานผ่าน imagePickerOverride แสดงตัวอย่างและลบได้',
      (tester) async {
    final service = FakeReportService();
    var pickedCount = 0;
    await _pumpPage(
      tester,
      service,
      attachEvidence: false,
      imagePickerOverride: () async {
        pickedCount++;
        return _testEvidence;
      },
    );

    // ยังไม่มีรูป
    expect(find.text('slip_chat_evidence.jpg'), findsNothing);

    // กดเลือกรูป
    await tester.ensureVisible(find.byKey(const Key('report-pick-evidence')));
    await tester.tap(find.byKey(const Key('report-pick-evidence')));
    await tester.pumpAndSettle();

    expect(pickedCount, 1);
    expect(find.text('slip_chat_evidence.jpg'), findsOneWidget);

    // กดลบรูป
    await tester.ensureVisible(find.byKey(const Key('report-remove-evidence')));
    await tester.tap(find.byKey(const Key('report-remove-evidence')));
    await tester.pumpAndSettle();

    expect(find.text('slip_chat_evidence.jpg'), findsNothing);
    expect(find.text('กดเพื่อเลือกรูปภาพหลักฐาน'), findsOneWidget);
  });

  testWidgets('เบอร์ผิด ต้องแสดงข้อความเตือนและไม่ส่ง', (tester) async {
    final service = FakeReportService();
    await _pumpPage(tester, service);

    await _fillValid(tester, phone: '02-123-4567');
    await _tapSubmit(tester);

    expect(find.text('เบอร์โทรไม่ถูกต้อง ต้องเป็นเบอร์มือถือไทย 10 หลัก'),
        findsOneWidget);
    expect(service.inputs, isEmpty);
  });

  testWidgets('ระหว่างส่งปุ่มถูกปิด แสดง loading และกดรัวๆ ส่งครั้งเดียว',
      (tester) async {
    final service = FakeReportService();
    await _pumpPage(tester, service);
    await _fillValid(tester);

    expect(_buttonEnabled(tester), isTrue);
    await _tapSubmit(tester);
    await _tapSubmit(tester);
    await _tapSubmit(tester);

    expect(_buttonEnabled(tester), isFalse);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(service.inputs, hasLength(1));

    // ส่งค่า enum ตาม PROJECT_CONTEXT พร้อม evidence_path
    expect(service.inputs.single.toJson(), {
      'customer_name': 'สมชาย ทดสอบ',
      'phone': '081-234-5678',
      'platform': 'shopee',
      'reason': 'refused_delivery',
      'evidence_path': 'user/mock_evidence.jpg',
      'amount': 1500,
    });

    service.respond(const ReportSuccess());
    await tester.pump();
    expect(_buttonEnabled(tester), isTrue);
  });

  testWidgets('ผลแบบรายงานซ้ำ แสดงข้อความจาก server และไม่ล้างฟอร์ม',
      (tester) async {
    final service = FakeReportService();
    await _pumpPage(tester, service);
    await _fillValid(tester);

    await _tapSubmit(tester);
    service.respond(const ReportDuplicate(
        'คุณรายงานเบอร์นี้ไปแล้วในช่วง 7 วันที่ผ่านมา'));
    await tester.pump();

    expect(find.text('คุณรายงานเบอร์นี้ไปแล้วในช่วง 7 วันที่ผ่านมา'),
        findsOneWidget);
    expect(find.text('081-234-5678'), findsOneWidget);
    expect(_buttonEnabled(tester), isTrue);
  });

  testWidgets('ผลแบบข้อมูลไม่ถูกต้อง แสดงข้อความจาก server', (tester) async {
    final service = FakeReportService();
    await _pumpPage(tester, service);
    await _fillValid(tester);

    await _tapSubmit(tester);
    service.respond(const ReportInvalid(['ชื่อลูกค้าห้ามมีเบอร์โทร']));
    await tester.pump();

    expect(find.text('ชื่อลูกค้าห้ามมีเบอร์โทร'), findsOneWidget);
  });

  testWidgets('สำเร็จ แสดงข้อความยืนยันและล้างฟอร์ม', (tester) async {
    final service = FakeReportService();
    await _pumpPage(tester, service);
    await _fillValid(tester);

    await _tapSubmit(tester);
    service.respond(const ReportSuccess());
    await tester.pump();

    expect(find.text('ส่งรายงานเรียบร้อยแล้ว ขอบคุณที่ช่วยแจ้งข้อมูล'),
        findsOneWidget);
    expect(find.text('สมชาย ทดสอบ'), findsNothing);
    expect(find.text('081-234-5678'), findsNothing);
    expect(find.text('1,500'), findsNothing);
    expect(find.text('Shopee'), findsNothing);
    expect(find.text('ปฏิเสธรับสินค้า'), findsNothing);
    // ล้างแล้วต้องไม่มีข้อความเตือนค้าง
    expect(find.text('กรุณากรอกชื่อลูกค้า'), findsNothing);
    expect(
        find.text('กรุณาแนบภาพแคปหน้าจอหลักฐาน (แชท/สลิป/ประวัติจัดส่ง)'),
        findsNothing);
  });

  testWidgets(
      'เลือกแพลตฟอร์มหรือเหตุผลเป็นอื่นๆ จะมีช่องกรอกข้อความเพิ่มขึ้นมาและต้องกรอก',
      (tester) async {
    final service = FakeReportService();
    await _pumpPage(tester, service);

    // ยังไม่ได้เลือก 'อื่นๆ' ต้องยังไม่เจอช่องกรอกเพิ่ม
    expect(find.byKey(const Key('report-platform-other')), findsNothing);
    expect(find.byKey(const Key('report-reason-other')), findsNothing);

    // กรอกข้อมูลทั่วไป
    await tester.enterText(
        find.byKey(const Key('report-name')), 'สมชาย ทดสอบ');
    await tester.enterText(
        find.byKey(const Key('report-phone')), '081-234-5678');

    // เลือกแพลตฟอร์มเป็น 'อื่นๆ'
    await _select(tester, 'report-platform', 'อื่นๆ');
    expect(find.byKey(const Key('report-platform-other')), findsOneWidget);

    // เลือกเหตุผลเป็น 'อื่นๆ'
    await _select(tester, 'report-reason', 'อื่นๆ');
    expect(find.byKey(const Key('report-reason-other')), findsOneWidget);

    // กดส่งขณะที่ยังไม่ได้กรอกช่องอื่นๆ
    await _tapSubmit(tester);
    expect(find.text('กรุณาระบุแพลตฟอร์ม'), findsOneWidget);
    expect(find.text('กรุณาระบุเหตุผล'), findsOneWidget);
    expect(service.inputs, isEmpty);

    // กรอกช่องอื่นๆ
    await tester.enterText(
        find.byKey(const Key('report-platform-other')), 'Instagram');
    await tester.enterText(
        find.byKey(const Key('report-reason-other')), 'เปลี่ยนใจไม่รับ');

    await _tapSubmit(tester);
    expect(service.inputs, hasLength(1));
    expect(service.inputs.single.toJson(), {
      'customer_name': 'สมชาย ทดสอบ',
      'phone': '081-234-5678',
      'platform': 'other',
      'reason': 'other',
      'evidence_path': 'user/mock_evidence.jpg',
      'other_details': 'แพลตฟอร์ม: Instagram | เหตุผล: เปลี่ยนใจไม่รับ',
    });

    service.respond(const ReportSuccess());
    await tester.pump();

    // หลังส่งสำเร็จ ฟอร์มต้องถูกรีเซ็ต
    expect(find.byKey(const Key('report-platform-other')), findsNothing);
    expect(find.byKey(const Key('report-reason-other')), findsNothing);
  });

  testWidgets('แนบภาพหลักฐานได้สูงสุด 3 รูป และส่ง path รวมกันสำเร็จ',
      (tester) async {
    final service = FakeReportService();
    var pickCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReportCustomerPage(
            reportService: service,
            storageService: FakeEvidenceStorageService(),
            imagePickerOverride: () async {
              pickCount++;
              return EvidenceFile(
                name: 'evidence_$pickCount.jpg',
                bytes: Uint8List.fromList([1, 2, 3]),
                extension: 'jpg',
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // รูปที่ 1
    await tester.ensureVisible(find.byKey(const Key('report-pick-evidence')));
    await tester.tap(find.byKey(const Key('report-pick-evidence')));
    await tester.pumpAndSettle();
    expect(find.text('evidence_1.jpg'), findsOneWidget);
    expect(find.text('เพิ่มรูปภาพอีก (1/3)'), findsOneWidget);

    // รูปที่ 2
    await tester.ensureVisible(find.byKey(const Key('report-pick-evidence')));
    await tester.tap(find.byKey(const Key('report-pick-evidence')));
    await tester.pumpAndSettle();
    expect(find.text('evidence_2.jpg'), findsOneWidget);
    expect(find.text('เพิ่มรูปภาพอีก (2/3)'), findsOneWidget);

    // รูปที่ 3
    await tester.ensureVisible(find.byKey(const Key('report-pick-evidence')));
    await tester.tap(find.byKey(const Key('report-pick-evidence')));
    await tester.pumpAndSettle();
    expect(find.text('evidence_3.jpg'), findsOneWidget);
    expect(find.text('เพิ่มรูปภาพอีก (3/3)'), findsNothing);

    // กรอกข้อมูลฟอร์ม
    await _fillValid(tester);
    await _tapSubmit(tester);

    expect(service.inputs, hasLength(1));
    expect(service.inputs.single.evidencePath,
        'user/mock_evidence.jpg,user/mock_evidence.jpg,user/mock_evidence.jpg');
  });
}

