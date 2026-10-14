import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cod_customer_check/services/app_settings.dart';
import 'package:cod_customer_check/services/auth_service.dart';
import 'package:cod_customer_check/widgets/delete_account_dialog.dart';
import 'package:cod_customer_check/widgets/settings_dialog.dart';

class _FakeAuthService implements AuthService {
  _FakeAuthService({
    this.failOnDelete = false,
    this.shopNameValue = 'ร้านค้าตัวอย่าง',
    this.userEmail = 'merchant@test.local',
  });

  final bool failOnDelete;
  final String shopNameValue;
  final String userEmail;
  int deleteCalls = 0;
  int signOutCalls = 0;

  @override
  String get shopName => shopNameValue;

  @override
  User? get currentUser => User(
        id: 'user-test-id',
        appMetadata: {},
        userMetadata: {'shop_name': shopNameValue},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z',
        email: userEmail,
      );

  @override
  Future<void> deleteAccount() async {
    deleteCalls++;
    if (failOnDelete) {
      throw Exception('ลบบัญชีไม่สำเร็จ: ข้อผิดพลาดจากระบบ');
    }
    await signOut();
  }

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.local}) async {
    signOutCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Widget _wrap(Widget child, {AppSettingsController? controller}) {
  return AppSettingsScope(
    controller: controller ?? AppSettingsController(),
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('DeleteAccountDialog 2-Step Confirmation Tests', () {
    setUp(() {});

    testWidgets('ขั้นตอนที่ 1 แสดงข้อมูล Transparency ชัดเจน และกดยกเลิกได้',
        (tester) async {
      tester.view.physicalSize = const Size(500, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final auth = _FakeAuthService();
      bool? result;

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                result = await DeleteAccountDialog.show(ctx, authService: auth);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // ตรวจพบ Dialog และหัวข้อขั้นตอนที่ 1
      expect(find.byKey(const Key('delete-account-dialog')), findsOneWidget);
      expect(find.text('ขอลบบัญชีผู้ใช้'), findsOneWidget);
      expect(find.text('ขั้นตอนที่ 1 จาก 2: ข้อมูลและผลกระทบ'), findsOneWidget);

      // ตรวจสอบข้อมูล Transparency (ข้อมูลที่ถูกลบ vs ข้อมูลที่เก็บต่อแบบนิรนาม)
      expect(find.text('ข้อมูลที่จะถูกลบถาวรทันที'), findsOneWidget);
      expect(find.text('ข้อมูลที่จัดเก็บต่อในรูปแบบนิรนาม'), findsOneWidget);
      expect(find.byKey(const Key('delete-account-continue-btn')), findsOneWidget);
      expect(find.byKey(const Key('delete-account-cancel-btn')), findsOneWidget);

      // กดยกเลิก
      await tester.tap(find.byKey(const Key('delete-account-cancel-btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('delete-account-dialog')), findsNothing);
      expect(result, isFalse);
      expect(auth.deleteCalls, 0);
    });

    testWidgets('กดดำเนินการต่อไปยังขั้นตอนที่ 2 และย้อนกลับมาได้', (tester) async {
      tester.view.physicalSize = const Size(500, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final auth = _FakeAuthService();

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => DeleteAccountDialog.show(ctx, authService: auth),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // กดไปขั้นตอนที่ 2
      final continueBtn = find.byKey(const Key('delete-account-continue-btn'));
      await tester.ensureVisible(continueBtn);
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      expect(find.text('ยืนยันการลบบัญชีถาวร'), findsOneWidget);
      expect(find.text('ขั้นตอนที่ 2 จาก 2: ยืนยันการดำเนินการ'), findsOneWidget);
      expect(find.byKey(const Key('delete-account-confirm-checkbox')), findsOneWidget);
      expect(find.byKey(const Key('delete-account-confirm-btn')), findsOneWidget);

      // กดย้อนกลับ
      final backBtn = find.byKey(const Key('delete-account-back-btn'));
      await tester.ensureVisible(backBtn);
      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      expect(find.text('ขั้นตอนที่ 1 จาก 2: ข้อมูลและผลกระทบ'), findsOneWidget);
    });

    testWidgets('ขั้นตอนที่ 2: ปุ่มลบจะถูกปิดจนกว่าจะติ๊กยืนยัน และลบสำเร็จ',
        (tester) async {
      tester.view.physicalSize = const Size(500, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final auth = _FakeAuthService();
      bool? result;

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                result = await DeleteAccountDialog.show(ctx, authService: auth);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // ไปขั้นตอนที่ 2
      final continueBtn = find.byKey(const Key('delete-account-continue-btn'));
      await tester.ensureVisible(continueBtn);
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      final confirmBtnFinder = find.byKey(const Key('delete-account-confirm-btn'));
      final button = tester.widget<FilledButton>(confirmBtnFinder);
      expect(button.onPressed, isNull, reason: 'ปุ่มต้องกดไม่ได้หากยังไม่ติ๊ก');

      // ติ๊ก Checkbox
      final checkboxFinder = find.byKey(const Key('delete-account-confirm-checkbox'));
      await tester.ensureVisible(checkboxFinder);
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      final buttonActive = tester.widget<FilledButton>(confirmBtnFinder);
      expect(buttonActive.onPressed, isNotNull, reason: 'ปุ่มต้องเปิดให้กดได้');

      // กดลบบัญชี
      await tester.ensureVisible(confirmBtnFinder);
      await tester.tap(confirmBtnFinder);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('delete-account-dialog')), findsNothing);
      expect(result, isTrue);
      expect(auth.deleteCalls, 1);
      expect(auth.signOutCalls, 1);
    });

    testWidgets('ขั้นตอนที่ 2: หากเกิด Error ระบบจะแสดงข้อความเตือนและไม่ปิด dialog',
        (tester) async {
      tester.view.physicalSize = const Size(500, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final auth = _FakeAuthService(failOnDelete: true);

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => DeleteAccountDialog.show(ctx, authService: auth),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final continueBtn = find.byKey(const Key('delete-account-continue-btn'));
      await tester.ensureVisible(continueBtn);
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      final checkboxFinder = find.byKey(const Key('delete-account-confirm-checkbox'));
      await tester.ensureVisible(checkboxFinder);
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      final confirmBtnFinder = find.byKey(const Key('delete-account-confirm-btn'));
      await tester.ensureVisible(confirmBtnFinder);
      await tester.tap(confirmBtnFinder);
      await tester.pumpAndSettle();

      // ยังเปิดอยู่และมีข้อความ Error
      expect(find.byKey(const Key('delete-account-dialog')), findsOneWidget);
      expect(find.textContaining('ลบบัญชีไม่สำเร็จ'), findsOneWidget);
      expect(auth.deleteCalls, 1);
    });
  });

  group('SettingsDialog บัญชีผู้ใช้ Tests', () {
    testWidgets('เมื่อส่ง authService จะแสดงส่วนบัญชีร้านค้าพร้อมปุ่มลบบัญชี',
        (tester) async {
      tester.view.physicalSize = const Size(500, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final auth = _FakeAuthService(
        shopNameValue: 'ร้านส้มตำแซ่บ',
        userEmail: 'somtum@test.local',
      );

      await tester.pumpWidget(
        _wrap(SettingsDialog(authService: auth)),
      );

      expect(find.text('บัญชีร้านค้า'), findsOneWidget);
      expect(find.text('ร้านส้มตำแซ่บ'), findsOneWidget);
      expect(find.text('somtum@test.local'), findsOneWidget);
      expect(find.byKey(const Key('settings-delete-account-button')), findsOneWidget);

      // แตะปุ่มลบบัญชี จะเปิด DeleteAccountDialog
      final deleteBtn = find.byKey(const Key('settings-delete-account-button'));
      await tester.ensureVisible(deleteBtn);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('delete-account-dialog')), findsOneWidget);
    });

    testWidgets('หากไม่ได้ส่ง authService จะไม่แสดงส่วนบัญชีร้านค้า',
        (tester) async {
      tester.view.physicalSize = const Size(500, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(const SettingsDialog()),
      );

      expect(find.text('บัญชีร้านค้า'), findsNothing);
      expect(find.byKey(const Key('settings-delete-account-button')), findsNothing);
    });
  });
}
