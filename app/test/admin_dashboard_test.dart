import 'package:cod_customer_check/pages/admin_dashboard_page.dart';
import 'package:cod_customer_check/services/admin_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MockAdminService implements AdminService {
  MockAdminService({
    List<PendingReport>? reports,
    AdminStats? stats,
  })  : _reports = reports ?? [],
        _stats = stats ??
            const AdminStats(
              pendingCount: 0,
              approvedToday: 0,
              rejectedToday: 0,
            );

  List<PendingReport> _reports;
  AdminStats _stats;
  final List<String> approvedIds = [];
  final List<Map<String, String>> rejectedRecords = [];

  @override
  Future<List<PendingReport>> getPendingReports({
    int limit = 50,
    int offset = 0,
  }) async {
    return _reports;
  }

  @override
  Future<AdminStats> getStats() async {
    return _stats;
  }

  @override
  Future<bool> approveReport(String reportId) async {
    approvedIds.add(reportId);
    _reports = _reports.where((r) => r.id != reportId).toList();
    _stats = AdminStats(
      pendingCount: _stats.pendingCount - 1,
      approvedToday: _stats.approvedToday + 1,
      rejectedToday: _stats.rejectedToday,
    );
    return true;
  }

  @override
  Future<bool> rejectReport(String reportId, String reason) async {
    rejectedRecords.add({'id': reportId, 'reason': reason});
    _reports = _reports.where((r) => r.id != reportId).toList();
    _stats = AdminStats(
      pendingCount: _stats.pendingCount - 1,
      approvedToday: _stats.approvedToday,
      rejectedToday: _stats.rejectedToday + 1,
    );
    return true;
  }

  @override
  Future<String> getEvidenceSignedUrl(String evidencePath) async {
    return 'https://example.com/evidence/$evidencePath';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

final _testReport = PendingReport(
  id: 'rep-001',
  customerName: 'สมชาย เบี้ยวนัด',
  platform: 'shopee',
  reason: 'refused_delivery',
  amount: 1200,
  otherDetails: 'โทรไม่ติด ปิดเครื่อง',
  evidencePath: 'merchants/rep-001.jpg',
  shopName: 'ร้านแชมป์ไอที',
  createdAt: DateTime(2026, 10, 7, 9, 30),
);

void main() {
  testWidgets('แสดงสถานะว่าง เมื่อไม่มีรายงานค้างตรวจ', (tester) async {
    final service = MockAdminService(reports: []);
    await tester.pumpWidget(MaterialApp(
      home: AdminDashboardPage(adminService: service),
    ));
    await tester.pumpAndSettle();

    expect(find.text('ไม่มีรายงานที่รอการตรวจสอบ'), findsOneWidget);
    expect(find.text('รายงานลูกค้าทั้งหมดได้รับการตรวจสอบและอนุมัติครบถ้วนแล้ว'),
        findsOneWidget);
    expect(find.text('รอการตรวจสอบ'), findsOneWidget);
    expect(find.text('อนุมัติแล้ววันนี้'), findsOneWidget);
    expect(find.text('ปฏิเสธแล้ววันนี้'), findsOneWidget);
  });

  testWidgets('แสดงรายการรายงานที่ค้างตรวจและข้อมูลสำคัญ', (tester) async {
    final service = MockAdminService(
      reports: [_testReport],
      stats: const AdminStats(
        pendingCount: 1,
        approvedToday: 10,
        rejectedToday: 2,
      ),
    );

    await tester.pumpWidget(MaterialApp(
      home: AdminDashboardPage(adminService: service),
    ));
    await tester.pumpAndSettle();

    expect(find.text('สมชาย เบี้ยวนัด'), findsOneWidget);
    expect(find.text('SHOPEE'), findsOneWidget);
    expect(find.text('฿1200'), findsOneWidget);
    expect(find.textContaining('ร้านแชมป์ไอที'), findsOneWidget);
    expect(find.textContaining('โทรไม่ติด ปิดเครื่อง'), findsOneWidget);
    expect(find.text('ดูรูปหลักฐาน'), findsOneWidget);
    expect(find.text('อนุมัติ'), findsOneWidget);
    expect(find.text('ปฏิเสธ'), findsOneWidget);
  });

  testWidgets('กดอนุมัติ แสดง dialog ยืนยัน และเรียก approveReport',
      (tester) async {
    final service = MockAdminService(
      reports: [_testReport],
      stats: const AdminStats(
        pendingCount: 1,
        approvedToday: 0,
        rejectedToday: 0,
      ),
    );

    await tester.pumpWidget(MaterialApp(
      home: AdminDashboardPage(adminService: service),
    ));
    await tester.pumpAndSettle();

    // กดปุ่มอนุมัติ
    await tester.tap(find.text('อนุมัติ'));
    await tester.pumpAndSettle();

    expect(find.text('ยืนยันอนุมัติรายงาน'), findsOneWidget);
    expect(find.textContaining('คุณต้องการอนุมัติรายงานของลูกค้า "สมชาย เบี้ยวนัด"'),
        findsOneWidget);

    // กดยืนยันใน dialog
    await tester.tap(find.widgetWithText(FilledButton, 'อนุมัติ').last);
    await tester.pumpAndSettle();

    expect(service.approvedIds, ['rep-001']);
    expect(find.textContaining('อนุมัติรายงาน "สมชาย เบี้ยวนัด" เรียบร้อยแล้ว'),
        findsOneWidget);
    expect(find.text('ไม่มีรายงานที่รอการตรวจสอบ'), findsOneWidget);
  });

  testWidgets('กดปฏิเสธ แสดง dialog ให้ระบุเหตุผล และเรียก rejectReport',
      (tester) async {
    final service = MockAdminService(
      reports: [_testReport],
      stats: const AdminStats(
        pendingCount: 1,
        approvedToday: 0,
        rejectedToday: 0,
      ),
    );

    await tester.pumpWidget(MaterialApp(
      home: AdminDashboardPage(adminService: service),
    ));
    await tester.pumpAndSettle();

    // กดปุ่มปฏิเสธ
    await tester.tap(find.text('ปฏิเสธ'));
    await tester.pumpAndSettle();

    expect(find.text('ปฏิเสธรายงาน'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // แก้ไขเหตุผล
    await tester.enterText(
        find.byType(TextField), 'ภาพหลักฐานไม่สามารถอ่านเบอร์โทรได้');

    // กดยืนยันปฏิเสธ
    await tester.tap(find.widgetWithText(FilledButton, 'ยืนยันปฏิเสธ'));
    await tester.pumpAndSettle();

    expect(service.rejectedRecords.length, 1);
    expect(service.rejectedRecords.first['id'], 'rep-001');
    expect(service.rejectedRecords.first['reason'],
        'ภาพหลักฐานไม่สามารถอ่านเบอร์โทรได้');
    expect(find.text('ไม่มีรายงานที่รอการตรวจสอบ'), findsOneWidget);
  });

  testWidgets('กดดูรูปหลักฐาน เปิด EvidenceViewerDialog', (tester) async {
    final service = MockAdminService(
      reports: [_testReport],
      stats: const AdminStats(
        pendingCount: 1,
        approvedToday: 0,
        rejectedToday: 0,
      ),
    );

    await tester.pumpWidget(MaterialApp(
      home: AdminDashboardPage(adminService: service),
    ));
    await tester.pumpAndSettle();

    // กดดูรูปหลักฐาน
    await tester.tap(find.text('ดูรูปหลักฐาน'));
    await tester.pump();

    expect(find.text('หลักฐานของ "สมชาย เบี้ยวนัด"'), findsOneWidget);
  });
}
