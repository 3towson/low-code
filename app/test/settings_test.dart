import 'package:cod_customer_check/app.dart';
import 'package:cod_customer_check/services/app_settings.dart';
import 'package:cod_customer_check/services/auth_service.dart';
import 'package:cod_customer_check/services/check_service.dart';
import 'package:cod_customer_check/services/report_service.dart';
import 'package:cod_customer_check/widgets/settings_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuthService implements AuthService {
  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();

  @override
  Session? get currentSession => null;

  @override
  String get shopName => 'ร้านค้า';

  @override
  Future<void> signIn({required String email, required String password}) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String shopName,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeCheckService implements CheckService {
  @override
  Future<CheckResult> checkText(String text) async {
    return const CheckOk(
      level: RiskLevel.green,
      countedReports: 0,
      recommendation: 'ส่งได้ตามปกติ',
      phoneMasked: '080-XXX-0001',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeReportService implements ReportService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Widget _buildTestApp({
  AppSettingsController? controller,
}) {
  return CodCheckApp(
    authService: _FakeAuthService(),
    checkService: _FakeCheckService(),
    reportService: _FakeReportService(),
    settingsController: controller,
  );
}

void main() {
  group('AppSettingsController Unit Tests', () {
    test('ค่าเริ่มต้น: ธีมมืด (dark) และภาษาไทย (th)', () {
      final settings = AppSettingsController();
      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.isDarkMode, isTrue);
      expect(settings.language, AppLanguage.th);
      expect(settings.strings.appSubtitle, 'ตรวจก่อนส่ง ป้องกันพัสดุตีกลับ');
    });

    test('toggleTheme สลับมืด <-> สว่าง ถูกต้อง', () {
      final settings = AppSettingsController();
      expect(settings.themeMode, ThemeMode.dark);

      settings.toggleTheme();
      expect(settings.themeMode, ThemeMode.light);
      expect(settings.isDarkMode, isFalse);

      settings.toggleTheme();
      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.isDarkMode, isTrue);
    });

    test('toggleLanguage สลับไทย <-> อังกฤษ ถูกต้อง', () {
      final settings = AppSettingsController();
      expect(settings.language, AppLanguage.th);
      expect(settings.strings.languageSection, 'ภาษา (Language)');

      settings.toggleLanguage();
      expect(settings.language, AppLanguage.en);
      expect(settings.strings.appSubtitle,
          'Check before shipping, prevent returned parcels');
      expect(settings.strings.checkRiskButton, 'Check Risk');

      settings.toggleLanguage();
      expect(settings.language, AppLanguage.th);
      expect(settings.strings.checkRiskButton, 'ตรวจสอบความเสี่ยง');
    });

    test('setThemeMode และ setLanguage กำหนดค่าได้ถูกต้องและแจ้งเตือน listeners', () {
      final settings = AppSettingsController();
      int notifyCount = 0;
      settings.addListener(() => notifyCount++);

      settings.setThemeMode(ThemeMode.light);
      expect(notifyCount, 1);
      expect(settings.themeMode, ThemeMode.light);

      // กำหนดค่าเดิมต้องไม่แจ้งซ้ำ
      settings.setThemeMode(ThemeMode.light);
      expect(notifyCount, 1);

      settings.setLanguage(AppLanguage.en);
      expect(notifyCount, 2);
      expect(settings.language, AppLanguage.en);

      settings.setLanguage(AppLanguage.en);
      expect(notifyCount, 2);
    });

    test('การแปลคำแนะนำความเสี่ยง (localizeRecommendation) เป็นภาษาอังกฤษ', () {
      final enStrings = AppStrings.en;
      expect(
        enStrings.localizeRecommendation('ส่งได้ตามปกติ'),
        'Safe to ship normally',
      );
      expect(
        enStrings.localizeRecommendation(
            'ควรโทรหรือทักยืนยันออเดอร์กับลูกค้าก่อนแพ็กสินค้า'),
        'Confirm order with customer via call/chat before packing',
      );
      expect(
        enStrings.localizeRecommendation(
            'ไม่แนะนำให้ส่งแบบเก็บเงินปลายทาง ควรให้ลูกค้าโอนชำระก่อน'),
        'COD not recommended; ask customer to prepay',
      );
    });
  });

  group('UI & Widget Tests', () {
    testWidgets('ปุ่ม Quick Theme Toggle บน AppBar สลับธีมมืดและสว่างได้ทันที',
        (tester) async {
      final controller = AppSettingsController(themeMode: ThemeMode.dark);
      await tester.pumpWidget(_buildTestApp(controller: controller));
      await tester.pumpAndSettle();

      final textElement = tester.element(find.text('COD Risk Shield'));
      expect(Theme.of(textElement).brightness, Brightness.dark);

      // กดปุ่มสลับธีม
      final themeBtn = find.byKey(const Key('theme-toggle-button'));
      expect(themeBtn, findsOneWidget);
      await tester.tap(themeBtn);
      await tester.pumpAndSettle();

      final lightElement = tester.element(find.text('COD Risk Shield'));
      expect(Theme.of(lightElement).brightness, Brightness.light);
      expect(controller.themeMode, ThemeMode.light);

      // กดอีกครั้งสลับกลับเป็นมืด
      await tester.tap(themeBtn);
      await tester.pumpAndSettle();

      final darkElement = tester.element(find.text('COD Risk Shield'));
      expect(Theme.of(darkElement).brightness, Brightness.dark);
      expect(controller.themeMode, ThemeMode.dark);
    });

    testWidgets('กดปุ่มตั้งค่าเปิด SettingsDialog และเปลี่ยนภาษาได้แบบ Realtime',
        (tester) async {
      final controller = AppSettingsController(
        themeMode: ThemeMode.dark,
        language: AppLanguage.th,
      );
      await tester.pumpWidget(_buildTestApp(controller: controller));
      await tester.pumpAndSettle();

      // ตรวจสอบข้อความเริ่มต้นเป็นภาษาไทย
      expect(find.text('ตรวจก่อนส่ง ป้องกันพัสดุตีกลับ'), findsOneWidget);
      expect(find.text('ตรวจสอบความเสี่ยง'), findsOneWidget);
      expect(find.text('รายงานลูกค้า'), findsOneWidget);

      // กดปุ่มฟันเฟืองเปิด Settings
      final settingsBtn = find.byKey(const Key('settings-button'));
      expect(settingsBtn, findsOneWidget);
      await tester.tap(settingsBtn);
      await tester.pumpAndSettle();

      // ตรวจสอบว่าเปิด Dialog สำเร็จ
      expect(find.byType(SettingsDialog), findsOneWidget);
      expect(find.byKey(const Key('settings-lang-en')), findsOneWidget);
      expect(find.byKey(const Key('settings-lang-th')), findsOneWidget);

      // เปลี่ยนภาษาเป็น English
      await tester.tap(find.byKey(const Key('settings-lang-en')));
      await tester.pumpAndSettle();

      // ปิด Dialog
      await tester.tap(find.byKey(const Key('settings-done')));
      await tester.pumpAndSettle();

      // ตรวจสอบว่า UI กลายเป็นภาษาอังกฤษทันที
      expect(find.text('Check before shipping, prevent returned parcels'),
          findsOneWidget);
      expect(find.text('Check Risk'), findsOneWidget);
      expect(find.text('Report Customer'), findsOneWidget);
      expect(controller.language, AppLanguage.en);

      // เปิด Settings เปลี่ยนกลับเป็นภาษาไทย
      await tester.tap(settingsBtn);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('settings-lang-th')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('settings-close')));
      await tester.pumpAndSettle();

      // ตรวจสอบว่ากลับเป็นภาษาไทยแล้ว
      expect(find.text('ตรวจก่อนส่ง ป้องกันพัสดุตีกลับ'), findsOneWidget);
      expect(find.text('ตรวจสอบความเสี่ยง'), findsOneWidget);
      expect(find.text('รายงานลูกค้า'), findsOneWidget);
      expect(controller.language, AppLanguage.th);
    });

    testWidgets('สลับธีมผ่าน SettingsDialog ได้ถูกต้อง', (tester) async {
      final controller = AppSettingsController(themeMode: ThemeMode.dark);
      await tester.pumpWidget(_buildTestApp(controller: controller));
      await tester.pumpAndSettle();

      // เปิด Settings
      await tester.tap(find.byKey(const Key('settings-button')));
      await tester.pumpAndSettle();

      // เลือกธีมสว่าง
      await tester.tap(find.byKey(const Key('settings-theme-light')));
      await tester.pumpAndSettle();

      expect(controller.themeMode, ThemeMode.light);

      // เลือกธีมมืด
      await tester.tap(find.byKey(const Key('settings-theme-dark')));
      await tester.pumpAndSettle();

      expect(controller.themeMode, ThemeMode.dark);
    });
  });
}
