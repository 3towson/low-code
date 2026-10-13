import 'dart:typed_data';

import 'package:cod_customer_check/pages/home_page.dart';
import 'package:cod_customer_check/pages/report_customer_page.dart';
import 'package:cod_customer_check/services/auth_service.dart';
import 'package:cod_customer_check/services/check_service.dart';
import 'package:cod_customer_check/services/merchant_kyc_service.dart';
import 'package:cod_customer_check/services/report_service.dart';
import 'package:cod_customer_check/widgets/merchant_kyc_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final Uint8List kTransparentPng = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

class MockMerchantKycService extends MerchantKycService {
  MockMerchantKycService({
    MerchantKycInfo? initialInfo,
    this.submitResult = true,
  })  : _currentInfo = initialInfo ??
            const MerchantKycInfo(
              shopName: 'ร้านค้าทดสอบ',
              status: MerchantKycStatus.unverified,
            ),
        super(null);

  MerchantKycInfo _currentInfo;
  final bool submitResult;

  int submitCallCount = 0;
  String? lastSubmittedUrl;
  String? lastSubmittedCategory;
  String? lastSubmittedPhone;
  List<EvidenceFile>? lastSubmittedEvidences;

  @override
  Future<MerchantKycInfo> getKycStatus() async {
    return _currentInfo;
  }

  @override
  Future<bool> submitKyc({
    required String shopUrl,
    required String category,
    required String contactPhone,
    required List<EvidenceFile> evidences,
    String? userId,
    Map<EvidenceFile, String>? uploadedPathCache,
  }) async {
    submitCallCount++;
    lastSubmittedUrl = shopUrl;
    lastSubmittedCategory = category;
    lastSubmittedPhone = contactPhone;
    lastSubmittedEvidences = evidences;

    if (submitResult) {
      _currentInfo = MerchantKycInfo(
        shopName: _currentInfo.shopName,
        status: MerchantKycStatus.pending,
        shopUrl: shopUrl,
        category: category,
        contactPhone: contactPhone,
        evidencePath: 'merchants/proof.jpg',
        submittedAt: DateTime.now(),
      );
      return true;
    }
    return false;
  }
}

class FakeAuthService implements AuthService {
  FakeAuthService({
    this.mockShopName = 'ร้านค้าทดสอบ',
    this.isAdmin = false,
  });

  final String mockShopName;
  @override
  final bool isAdmin;

  @override
  Future<bool> checkIsAdmin() async => isAdmin;

  @override
  String get shopName => mockShopName;

  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class FakeCheckService implements CheckService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class FakeReportService implements ReportService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  group('MerchantKycDialog Form Tests', () {
    testWidgets('ตรวจจับ Validation เมื่อฟอร์มว่างและไม่มีรูปภาพหลักฐาน',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final kycService = MockMerchantKycService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MerchantKycDialog(
              shopName: 'ร้านแฟชั่นเก๋ๆ',
              kycService: kycService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // ตรวจสอบชื่อร้านค้า
      expect(find.text('ร้านแฟชั่นเก๋ๆ'), findsOneWidget);

      // กดปุ่มส่งข้อมูลทันทีโดยไม่กรอกอะไร
      final submitBtn = find.byKey(const Key('kyc-submit-button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // ต้องแสดง Error validation
      expect(find.text('กรุณาระบุลิงก์หน้าร้านจริง'), findsOneWidget);
      expect(find.text('กรุณากรอกเบอร์โทร'), findsOneWidget);
      expect(kycService.submitCallCount, 0);
    });

    testWidgets('ตรวจจับ Validation เมื่อกรอกเบอร์โทรผิดรูปแบบ', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final kycService = MockMerchantKycService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MerchantKycDialog(
              shopName: 'ร้านแฟชั่นเก๋ๆ',
              kycService: kycService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // กรอก URL ถูกต้อง แต่กรอกเบอร์โทรผิด
      await tester.enterText(
          find.byKey(const Key('kyc-store-url')), 'https://shopee.co.th/shop');
      await tester.enterText(
          find.byKey(const Key('kyc-contact-phone')), '12345');

      final submitBtn = find.byKey(const Key('kyc-submit-button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // ต้องแจ้งเตือนเบอร์โทรไม่ถูกต้อง
      expect(
        find.text('เบอร์โทรไม่ถูกต้อง ต้องเป็นเบอร์มือถือไทย 10 หลัก'),
        findsOneWidget,
      );
      expect(kycService.submitCallCount, 0);
    });

    testWidgets('ตรวจจับ Validation เมื่อไม่ได้แนบรูปหลักฐานยอดขาย >50 ออเดอร์',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final kycService = MockMerchantKycService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MerchantKycDialog(
              shopName: 'ร้านแฟชั่นเก๋ๆ',
              kycService: kycService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('kyc-store-url')), 'https://shopee.co.th/shop');
      await tester.enterText(
          find.byKey(const Key('kyc-contact-phone')), '0812345678');

      // กดส่งข้อมูล
      final submitBtn = find.byKey(const Key('kyc-submit-button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // ต้องแจ้งเตือนเรื่องรูปภาพ
      expect(
        find.text(
            'กรุณาแนบภาพหลักฐานยอดขายหรือประวัติการส่งพัสดุอย่างน้อย 1 ภาพ'),
        findsOneWidget,
      );
      expect(kycService.submitCallCount, 0);
    });

    testWidgets('แนบภาพหลักฐานและส่งข้อมูลสำเร็จ เรียก submitKyc',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final kycService = MockMerchantKycService();
      bool submittedCallbackFired = false;

      final sampleEvidence = EvidenceFile(
        name: 'proof.png',
        bytes: kTransparentPng,
        extension: 'png',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showDialog(
                    context: ctx,
                    builder: (_) => MerchantKycDialog(
                      shopName: 'ร้านแฟชั่นเก๋ๆ',
                      kycService: kycService,
                      imagePickerOverride: () async => sampleEvidence,
                      onSubmitted: () => submittedCallbackFired = true,
                    ),
                  ),
                  child: const Text('Open KYC'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // เปิด dialog
      await tester.tap(find.text('Open KYC'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('kyc-store-url')), 'https://shopee.co.th/chicshop');
      await tester.enterText(
          find.byKey(const Key('kyc-contact-phone')), '0899998888');

      // กดแนบรูปภาพ
      final addBtn = find.byKey(const Key('kyc-add-evidence'));
      await tester.ensureVisible(addBtn);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // กดส่งข้อมูล
      final submitBtn = find.byKey(const Key('kyc-submit-button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(kycService.submitCallCount, 1);
      expect(kycService.lastSubmittedUrl, 'https://shopee.co.th/chicshop');
      expect(kycService.lastSubmittedPhone, '0899998888');
      expect(kycService.lastSubmittedEvidences?.length, 1);
      expect(submittedCallbackFired, isTrue);
      expect(
        find.textContaining('ยื่นคำขอยืนยันตัวตนสำเร็จ'),
        findsOneWidget,
      );
    });

    testWidgets('แสดงแบนเนอร์แจ้งเตือนเหตุผลเมื่อถูกปฏิเสธมาก่อน (isRejected)',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final kycService = MockMerchantKycService();
      const rejectedInfo = MerchantKycInfo(
        shopName: 'ร้านแฟชั่นเก๋ๆ',
        status: MerchantKycStatus.rejected,
        rejectionReason: 'ภาพสรุปยอดจัดส่งไม่ชัดเจน ไม่สามารถอ่านยอดออเดอร์ได้',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MerchantKycDialog(
              shopName: 'ร้านแฟชั่นเก๋ๆ',
              kycService: kycService,
              initialInfo: rejectedInfo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('คำขอก่อนหน้าไม่ผ่านการอนุมัติ'),
        findsOneWidget,
      );
      expect(
        find.textContaining('ภาพสรุปยอดจัดส่งไม่ชัดเจน ไม่สามารถอ่านยอดออเดอร์ได้'),
        findsOneWidget,
      );
    });
  });

  group('HomePage KYC Gate & Badges Tests', () {
    testWidgets('ร้านค้า unverified แสดง badge ยืนยันร้าน และบล็อกการเปิดฟอร์มรายงาน',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final kycService = MockMerchantKycService(
        initialInfo: const MerchantKycInfo(
          shopName: 'ร้านน้องใหม่',
          status: MerchantKycStatus.unverified,
        ),
      );

      final authService = FakeAuthService(mockShopName: 'ร้านน้องใหม่');

      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(
            signedIn: true,
            animatePulse: false,
            authService: authService,
            checkService: FakeCheckService(),
            reportService: FakeReportService(),
            kycService: kycService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Badge ยืนยันร้าน
      expect(find.text('ยืนยันร้าน'), findsOneWidget);

      // กดปุ่มรายงานลูกค้า
      final reportBtn = find.byKey(const Key('home-report'));
      await tester.ensureVisible(reportBtn);
      await tester.tap(reportBtn);
      await tester.pumpAndSettle();

      // ต้องแสดง Dialog บล็อกและแนะนำให้ยื่นยืนยันตัวตน
      expect(find.text('ต้องยืนยันตัวตนร้านค้าก่อนรายงาน'), findsOneWidget);
      expect(
        find.textContaining('ร้านค้าต้องส่งหลักฐานการเปิดร้านและประวัติการส่งสินค้าจริง'),
        findsOneWidget,
      );
    });

    testWidgets('ร้านค้า pending แสดง badge รออนุมัติ และแสดง dialog อยู่ระหว่างตรวจสอบ',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final kycService = MockMerchantKycService(
        initialInfo: const MerchantKycInfo(
          shopName: 'ร้านรอผล',
          status: MerchantKycStatus.pending,
        ),
      );

      final authService = FakeAuthService(mockShopName: 'ร้านรอผล');

      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(
            signedIn: true,
            animatePulse: false,
            authService: authService,
            checkService: FakeCheckService(),
            reportService: FakeReportService(),
            kycService: kycService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Badge รออนุมัติ
      expect(find.text('รออนุมัติ'), findsOneWidget);

      // กดปุ่มรายงานลูกค้า
      final reportBtn = find.byKey(const Key('home-report'));
      await tester.ensureVisible(reportBtn);
      await tester.tap(reportBtn);
      await tester.pumpAndSettle();

      // ต้องแสดง Dialog รออนุมัติ
      expect(find.text('อยู่ระหว่างรอการอนุมัติร้านค้า'), findsOneWidget);
    });

    testWidgets('ร้านค้า approved แสดง badge Verified และเปิดหน้า ReportCustomerPage ได้',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final kycService = MockMerchantKycService(
        initialInfo: const MerchantKycInfo(
          shopName: 'ร้านพี่เสือ',
          status: MerchantKycStatus.approved,
        ),
      );

      final authService = FakeAuthService(mockShopName: 'ร้านพี่เสือ');

      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(
            signedIn: true,
            animatePulse: false,
            authService: authService,
            checkService: FakeCheckService(),
            reportService: FakeReportService(),
            kycService: kycService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Badge Verified
      expect(find.text('Verified'), findsOneWidget);

      // กดปุ่มรายงานลูกค้า
      final reportBtn = find.byKey(const Key('home-report'));
      await tester.ensureVisible(reportBtn);
      await tester.tap(reportBtn);
      await tester.pumpAndSettle();

      // เปิดหน้ารายงานลูกค้าได้สำเร็จ
      expect(find.byType(ReportCustomerPage), findsOneWidget);
    });
  });
}
