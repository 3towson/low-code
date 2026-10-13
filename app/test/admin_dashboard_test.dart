import 'package:cod_customer_check/pages/admin_dashboard_page.dart';
import 'package:cod_customer_check/services/admin_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MockAdminService implements AdminService {
  MockAdminService({
    List<PendingReport>? reports,
    List<PendingMerchant>? merchants,
    AdminStats? stats,
  })  : _reports = reports ?? [],
        _merchants = merchants ?? [],
        _stats = stats ??
            const AdminStats(
              pendingCount: 0,
              approvedToday: 0,
              rejectedToday: 0,
            );

  List<PendingReport> _reports;
  List<PendingMerchant> _merchants;
  AdminStats _stats;
  final List<String> approvedIds = [];
  final List<Map<String, String>> rejectedRecords = [];
  final List<String> approvedMerchantIds = [];
  final List<Map<String, String>> rejectedMerchantRecords = [];
  final List<Map<String, String>> suspendedMerchantRecords = [];

  @override
  Future<List<PendingReport>> getPendingReports({
    int limit = 50,
    int offset = 0,
  }) async {
    return _reports;
  }

  @override
  Future<List<PendingMerchant>> getPendingMerchants({
    int limit = 50,
    int offset = 0,
  }) async {
    return _merchants;
  }

  @override
  Future<List<PendingMerchant>> listMerchants({
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    if (status == null || status.isEmpty || status == 'all') {
      return _merchants;
    }
    final filtered = _merchants
        .where((m) => (m.verificationStatus ?? 'pending') == status)
        .toList();
    if (filtered.isEmpty && _merchants.isNotEmpty && status == 'pending') {
      return _merchants;
    }
    return filtered;
  }

  @override
  Future<int> getPendingMerchantsCount() async {
    return _merchants.length;
  }

  @override
  Future<bool> approveMerchant(String sellerId) async {
    approvedMerchantIds.add(sellerId);
    _merchants = _merchants.where((m) => m.id != sellerId).toList();
    return true;
  }

  @override
  Future<bool> rejectMerchant(String sellerId, String reason) async {
    rejectedMerchantRecords.add({'id': sellerId, 'reason': reason});
    _merchants = _merchants.where((m) => m.id != sellerId).toList();
    return true;
  }

  @override
  Future<bool> suspendMerchant(String sellerId, String reason) async {
    suspendedMerchantRecords.add({'id': sellerId, 'reason': reason});
    _merchants = _merchants.where((m) => m.id != sellerId).toList();
    return true;
  }

  final List<String> unsuspendedMerchantIds = [];

  @override
  Future<bool> unsuspendMerchant(String sellerId) async {
    unsuspendedMerchantIds.add(sellerId);
    _merchants = _merchants.where((m) => m.id != sellerId).toList();
    return true;
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
  Future<String> getEvidenceSignedUrl(
    String evidencePath, {
    String bucket = 'report-evidences',
  }) async {
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

  testWidgets('สลับแท็บไปยังคำขออนุมัติร้านค้า และแสดงข้อมูลร้านค้า',
      (tester) async {
    final merchant = PendingMerchant(
      id: 'seller-001',
      shopName: 'ร้านบอส อุปกรณ์ช่าง',
      category: 'เครื่องมือช่าง',
      shopUrl: 'https://shopee.co.th/boss_tools',
      contactPhone: '0812345678',
      evidencePath: 'merchants/seller-001/proof1.jpg',
      submittedAt: DateTime(2026, 10, 10, 14, 0),
      createdAt: DateTime(2026, 10, 10, 13, 0),
    );

    final service = MockAdminService(
      reports: [],
      merchants: [merchant],
    );

    await tester.pumpWidget(MaterialApp(
      home: AdminDashboardPage(adminService: service),
    ));
    await tester.pumpAndSettle();

    // เริ่มต้นอยู่ที่แท็บรายงาน (ว่าง)
    expect(find.text('ไม่มีรายงานที่รอการตรวจสอบ'), findsOneWidget);

    // สลับไปยังแท็บร้านค้า
    await tester.tap(find.byKey(const Key('admin-tab-merchants')));
    await tester.pumpAndSettle();

    expect(find.text('ร้านบอส อุปกรณ์ช่าง'), findsOneWidget);
    expect(find.text('เครื่องมือช่าง'), findsOneWidget);
    expect(find.text('https://shopee.co.th/boss_tools'), findsOneWidget);
    expect(find.text('0812345678'), findsOneWidget);
    expect(find.text('อนุมัติร้านค้า (Verified)'), findsOneWidget);
    expect(find.text('ไม่อนุมัติ'), findsOneWidget);
  });

  testWidgets('อนุมัติร้านค้า เรียก approveMerchant และอัปเดตหน้าจอ',
      (tester) async {
    final merchant = PendingMerchant(
      id: 'seller-001',
      shopName: 'ร้านบอส อุปกรณ์ช่าง',
      category: 'เครื่องมือช่าง',
      shopUrl: 'https://shopee.co.th/boss_tools',
      contactPhone: '0812345678',
      evidencePath: 'merchants/seller-001/proof1.jpg',
      submittedAt: DateTime(2026, 10, 10, 14, 0),
      createdAt: DateTime(2026, 10, 10, 13, 0),
    );

    final service = MockAdminService(
      merchants: [merchant],
    );

    await tester.pumpWidget(MaterialApp(
      home: AdminDashboardPage(adminService: service),
    ));
    await tester.pumpAndSettle();

    // สลับไปยังแท็บร้านค้า
    await tester.tap(find.byKey(const Key('admin-tab-merchants')));
    await tester.pumpAndSettle();

    // กดปุ่มอนุมัติ
    await tester.tap(find.byKey(const Key('admin-approve-merchant-seller-001')));
    await tester.pumpAndSettle();

    expect(find.text('ยืนยันอนุมัติร้านค้า'), findsOneWidget);

    // กดยืนยันใน dialog
    await tester.tap(find.widgetWithText(FilledButton, 'อนุมัติร้านค้า'));
    await tester.pumpAndSettle();

    expect(service.approvedMerchantIds, ['seller-001']);
    expect(find.textContaining('อนุมัติร้านค้า "ร้านบอส อุปกรณ์ช่าง" เรียบร้อยแล้ว'),
        findsOneWidget);
    expect(find.text('ไม่มีคำขออนุมัติร้านค้าที่รอการตรวจสอบ'), findsOneWidget);
  });

  testWidgets('ปฏิเสธร้านค้า พร้อมระบุเหตุผล และเรียก rejectMerchant',
      (tester) async {
    final merchant = PendingMerchant(
      id: 'seller-001',
      shopName: 'ร้านบอส อุปกรณ์ช่าง',
      category: 'เครื่องมือช่าง',
      shopUrl: 'https://shopee.co.th/boss_tools',
      contactPhone: '0812345678',
      evidencePath: 'merchants/seller-001/proof1.jpg',
      submittedAt: DateTime(2026, 10, 10, 14, 0),
      createdAt: DateTime(2026, 10, 10, 13, 0),
    );

    final service = MockAdminService(
      merchants: [merchant],
    );

    await tester.pumpWidget(MaterialApp(
      home: AdminDashboardPage(adminService: service),
    ));
    await tester.pumpAndSettle();

    // สลับไปยังแท็บร้านค้า
    await tester.tap(find.byKey(const Key('admin-tab-merchants')));
    await tester.pumpAndSettle();

    // กดปุ่มไม่อนุมัติ
    await tester.tap(find.byKey(const Key('admin-reject-merchant-seller-001')));
    await tester.pumpAndSettle();

    expect(find.text('ไม่อนุมัติร้านค้า'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // แก้ไขเหตุผล
    await tester.enterText(
        find.byType(TextField), 'ยอดออเดอร์ยังไม่ถึง 50 ออเดอร์ตามเงื่อนไข');

    // กดยืนยันปฏิเสธ
    await tester.tap(find.widgetWithText(FilledButton, 'ยืนยันปฏิเสธ'));
    await tester.pumpAndSettle();

    expect(service.rejectedMerchantRecords.length, 1);
    expect(service.rejectedMerchantRecords.first['id'], 'seller-001');
    expect(service.rejectedMerchantRecords.first['reason'],
        'ยอดออเดอร์ยังไม่ถึง 50 ออเดอร์ตามเงื่อนไข');
    expect(find.text('ไม่มีคำขออนุมัติร้านค้าที่รอการตรวจสอบ'), findsOneWidget);
  });

  testWidgets('แสดง fallback displayName เมื่อ customerName เป็นค่าว่าง (P0-3)',
      (tester) async {
    final reportNoName = PendingReport(
      id: '87654321-abcd-ef01-2345-6789abcdef01',
      customerName: '',
      platform: 'tiktok',
      reason: 'fake_address',
      amount: null,
      otherDetails: null,
      evidencePath: null,
      shopName: 'ร้านค้าตัวอย่าง',
      createdAt: DateTime(2026, 10, 13, 10, 0),
    );

    final service = MockAdminService(reports: [reportNoName]);
    await tester.pumpWidget(MaterialApp(
      home: AdminDashboardPage(adminService: service),
    ));
    await tester.pumpAndSettle();

    // ต้องแสดง 'รายงาน #87654321' แทนชื่อลูกค้า
    expect(find.text('รายงาน #87654321'), findsOneWidget);
  });

  testWidgets('ระงับร้านค้าจากแท็บร้านค้า พร้อมระบุเหตุผล และเรียก suspendMerchant (P0-4)',
      (tester) async {
    final merchant = PendingMerchant(
      id: 'seller-suspend-01',
      shopName: 'ร้านปั่นยอด ปลอมหลักฐาน',
      category: 'เสื้อผ้าแฟชั่น',
      shopUrl: 'https://shopee.co.th/fraud_shop',
      contactPhone: '0899998888',
      evidencePath: 'merchants/seller-suspend-01/fake_proof.jpg',
      submittedAt: DateTime(2026, 10, 12, 10, 0),
      createdAt: DateTime(2026, 10, 12, 9, 0),
    );

    final service = MockAdminService(
      merchants: [merchant],
    );

    await tester.pumpWidget(MaterialApp(
      home: AdminDashboardPage(adminService: service),
    ));
    await tester.pumpAndSettle();

    // สลับไปยังแท็บร้านค้า
    await tester.tap(find.byKey(const Key('admin-tab-merchants')));
    await tester.pumpAndSettle();

    // มีปุ่มระงับร้านค้า
    expect(find.byKey(const Key('admin-suspend-merchant-seller-suspend-01')),
        findsOneWidget);

    // กดปุ่มระงับร้านค้า
    await tester.tap(
        find.byKey(const Key('admin-suspend-merchant-seller-suspend-01')));
    await tester.pumpAndSettle();

    expect(find.text('ยืนยันระงับร้านค้า'), findsNWidgets(2));
    expect(find.byType(TextField), findsOneWidget);

    // ระบุเหตุผลระงับ
    await tester.enterText(
        find.byType(TextField), 'ใช้สลิปปลอม และสร้างรายงานเท็จหลายรายการ');

    // กดยืนยันระงับ
    await tester.tap(find.byKey(const Key('admin-confirm-suspend-button')));
    await tester.pumpAndSettle();

    expect(service.suspendedMerchantRecords.length, 1);
    expect(service.suspendedMerchantRecords.first['id'], 'seller-suspend-01');
    expect(service.suspendedMerchantRecords.first['reason'],
        'ใช้สลิปปลอม และสร้างรายงานเท็จหลายรายการ');
    expect(find.text('ไม่มีคำขออนุมัติร้านค้าที่รอการตรวจสอบ'), findsOneWidget);
  });

  testWidgets('ระงับร้านค้าจากแท็บรายงานเมื่อพบรายงานเท็จ (P0-4)',
      (tester) async {
    final abusiveReport = PendingReport(
      id: 'rep-fraud-01',
      customerName: 'ลูกค้าผู้บริสุทธิ์',
      platform: 'shopee',
      reason: 'refused_delivery',
      amount: 1000,
      otherDetails: 'รายงานกลั่นแกล้ง',
      evidencePath: null,
      shopName: 'ร้านค้าสร้างรายงานเท็จ',
      createdAt: DateTime(2026, 10, 13, 11, 0),
      sellerId: 'bad-seller-007',
    );

    final service = MockAdminService(
      reports: [abusiveReport],
    );

    await tester.pumpWidget(MaterialApp(
      home: AdminDashboardPage(adminService: service),
    ));
    await tester.pumpAndSettle();

    // ตรวจสอบว่ามีปุ่มระงับร้านค้าที่การ์ดรายงาน
    expect(find.byKey(const Key('admin-suspend-report-seller-rep-fraud-01')),
        findsOneWidget);

    // กดปุ่มระงับร้านค้าจากรายงาน
    await tester.tap(
        find.byKey(const Key('admin-suspend-report-seller-rep-fraud-01')));
    await tester.pumpAndSettle();

    expect(find.text('ระงับร้านค้าผู้รายงาน'), findsOneWidget);

    // กดยืนยันระงับ
    await tester.tap(find.byKey(
        const Key('admin-confirm-suspend-report-merchant-button')));
    await tester.pumpAndSettle();

    expect(service.suspendedMerchantRecords.length, 1);
    expect(service.suspendedMerchantRecords.first['id'], 'bad-seller-007');
    expect(find.textContaining('ระงับร้านค้า "ร้านค้าสร้างรายงานเท็จ" เรียบร้อยแล้ว'),
        findsOneWidget);
  });

  testWidgets('ยกเลิกการระงับร้านค้า แสดงปุ่มและเรียก unsuspendMerchant เมื่อร้านค้ามีสถานะ suspended (N7/R1)',
      (tester) async {
    final suspendedMerchant = PendingMerchant(
      id: 'seller-suspended-01',
      shopName: 'ร้านค้าที่เคยถูกระงับ',
      shopUrl: 'https://suspended-shop.com',
      category: 'เสื้อผ้าและแฟชั่น',
      contactPhone: '0811112222',
      evidencePath: null,
      submittedAt: DateTime(2026, 10, 13, 10, 0),
      createdAt: DateTime(2026, 10, 13, 9, 0),
      verificationStatus: 'suspended',
    );

    final service = MockAdminService(
      merchants: [suspendedMerchant],
    );

    await tester.pumpWidget(MaterialApp(
      home: AdminDashboardPage(adminService: service),
    ));
    await tester.pumpAndSettle();

    // สลับไปยังแท็บร้านค้า
    await tester.tap(find.byKey(const Key('admin-tab-merchants')));
    await tester.pumpAndSettle();

    // มีปุ่มยกเลิกการระงับร้านค้า (แทนปุ่มระงับร้านค้า)
    expect(find.byKey(const Key('admin-unsuspend-merchant-seller-suspended-01')),
        findsOneWidget);
    expect(find.byKey(const Key('admin-suspend-merchant-seller-suspended-01')),
        findsNothing);

    // กดยกเลิกการระงับ
    await tester.tap(
        find.byKey(const Key('admin-unsuspend-merchant-seller-suspended-01')));
    await tester.pumpAndSettle();

    expect(find.text('ยืนยันยกเลิกการระงับร้านค้า'), findsOneWidget);

    // กดยืนยัน
    await tester.tap(find.byKey(const Key('admin-confirm-unsuspend-button')));
    await tester.pumpAndSettle();

    expect(service.unsuspendedMerchantIds, ['seller-suspended-01']);
    expect(find.textContaining('ยกเลิกการระงับร้านค้า "ร้านค้าที่เคยถูกระงับ" เรียบร้อยแล้ว'),
        findsOneWidget);
  });

  testWidgets('ตัวกรองร้านค้า (Filter Chips) สามารถสลับดูร้านที่ถูกระงับ และแสดงป้ายสถานะถูกต้อง (S1)',
      (tester) async {
    final pendingMerchant = PendingMerchant(
      id: 'seller-p1',
      shopName: 'ร้านรอตรวจ',
      shopUrl: 'https://pending.com',
      category: 'ไอที',
      contactPhone: '0811111111',
      evidencePath: null,
      submittedAt: DateTime(2026, 10, 13, 10, 0),
      createdAt: DateTime(2026, 10, 13, 9, 0),
      verificationStatus: 'pending',
    );
    final suspendedMerchant = PendingMerchant(
      id: 'seller-s1',
      shopName: 'ร้านที่โดนระงับ',
      shopUrl: 'https://suspended.com',
      category: 'แฟชั่น',
      contactPhone: '0822222222',
      evidencePath: null,
      submittedAt: DateTime(2026, 10, 13, 10, 0),
      createdAt: DateTime(2026, 10, 13, 9, 0),
      verificationStatus: 'suspended',
      rejectionReason: 'ส่งสลิปปลอม',
    );

    final service = MockAdminService(
      merchants: [pendingMerchant, suspendedMerchant],
    );

    await tester.pumpWidget(MaterialApp(
      home: AdminDashboardPage(adminService: service),
    ));
    await tester.pumpAndSettle();

    // สลับไปยังแท็บร้านค้า
    await tester.tap(find.byKey(const Key('admin-tab-merchants')));
    await tester.pumpAndSettle();

    // ค่าเริ่มต้นเป็น 'pending' -> เห็นร้านรอตรวจ แต่ไม่เห็นร้านที่ถูกระงับ
    expect(find.text('ร้านรอตรวจ'), findsOneWidget);
    expect(find.text('ร้านที่โดนระงับ'), findsNothing);

    // กด Filter Chip 'ถูกระงับ'
    await tester.tap(find.byKey(const Key('admin-filter-merchant-suspended')));
    await tester.pumpAndSettle();

    // ตอนนี้ต้องเห็นร้านที่โดนระงับ พร้อมป้าย 'ถูกระงับ (Suspended)' และปุ่ม 'ยกเลิกการระงับ'
    expect(find.text('ร้านที่โดนระงับ'), findsOneWidget);
    expect(find.text('ร้านรอตรวจ'), findsNothing);
    expect(find.text('ถูกระงับ (Suspended)'), findsOneWidget);
    expect(find.textContaining('เหตุผลที่ระงับ: ส่งสลิปปลอม'), findsOneWidget);
    expect(find.byKey(const Key('admin-unsuspend-merchant-seller-s1')), findsOneWidget);

    // กด Filter Chip 'ทั้งหมด'
    await tester.tap(find.byKey(const Key('admin-filter-merchant-all')));
    await tester.pumpAndSettle();

    // เห็นทั้งสองร้าน
    expect(find.text('ร้านรอตรวจ'), findsOneWidget);
    expect(find.text('ร้านที่โดนระงับ'), findsOneWidget);
  });
}

