import 'package:cod_customer_check/pages/login_page.dart';
import 'package:cod_customer_check/pages/signup_page.dart';
import 'package:cod_customer_check/services/app_settings.dart';
import 'package:cod_customer_check/services/auth_service.dart';
import 'package:cod_customer_check/utils/url_helper.dart';
import 'package:cod_customer_check/widgets/settings_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuthService implements AuthService {
  int signInCalls = 0;
  int signUpCalls = 0;
  String? lastSignedUpEmail;
  String? lastSignedUpShop;

  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();

  @override
  Session? get currentSession => null;

  @override
  User? get currentUser => null;

  @override
  String get shopName => 'ร้านตัวอย่าง';

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls++;
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String shopName,
  }) async {
    signUpCalls++;
    lastSignedUpEmail = email;
    lastSignedUpShop = shopName;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Widget _wrap(Widget child, [AppSettingsController? controller]) {
  final settings = controller ?? AppSettingsController();
  return ListenableBuilder(
    listenable: settings,
    builder: (context, _) => AppSettingsScope(
      controller: settings,
      child: MaterialApp(
        home: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  group('P0-2 Privacy Policy Tests', () {
    test('AppUrls constants are valid HTTPS URLs', () {
      expect(AppUrls.privacyPolicy, startsWith('https://'));
      expect(AppUrls.privacyPolicy, contains('privacy-policy.html'));
      expect(AppUrls.accountDeletion, startsWith('https://'));
      expect(AppUrls.accountDeletion, contains('delete-account.html'));
    });

    testWidgets('LoginPage - Signin tab does not show privacy checkbox',
        (tester) async {
      final auth = _FakeAuthService();
      await tester.pumpWidget(_wrap(LoginPage(authService: auth)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login-privacy-checkbox')), findsNothing);
      expect(find.byKey(const Key('login-privacy-link')), findsNothing);
    });

    testWidgets('LoginPage - Signup tab requires privacy checkbox acceptance',
        (tester) async {
      final auth = _FakeAuthService();
      await tester.pumpWidget(_wrap(LoginPage(authService: auth)));
      await tester.pumpAndSettle();

      // Switch to signup tab
      await tester.tap(find.byKey(const Key('auth-tab-signup')));
      await tester.pumpAndSettle();

      // Checkbox and link should now be visible
      expect(find.byKey(const Key('login-privacy-checkbox')), findsOneWidget);
      expect(find.byKey(const Key('login-privacy-link')), findsOneWidget);

      // Fill in signup fields: shop name, email, password
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'ร้านนายดี');
      await tester.enterText(fields.at(1), 'test@shop.com');
      await tester.enterText(fields.at(2), 'password123');

      // Try submitting without checking the checkbox
      await tester.tap(find.byKey(const Key('auth-submit-button')));
      await tester.pumpAndSettle();

      // Should show warning banner and NOT call signUp
      expect(find.text('กรุณายอมรับนโยบายความเป็นส่วนตัวก่อนสมัครสมาชิก'),
          findsOneWidget);
      expect(auth.signUpCalls, 0);

      // Check the checkbox
      await tester.tap(find.byKey(const Key('login-privacy-checkbox')));
      await tester.pumpAndSettle();

      // Submit again
      await tester.tap(find.byKey(const Key('auth-submit-button')));
      await tester.pumpAndSettle();

      // Should call signUp
      expect(auth.signUpCalls, 1);
      expect(auth.lastSignedUpShop, 'ร้านนายดี');
      expect(auth.lastSignedUpEmail, 'test@shop.com');
    });

    testWidgets('SignupPage - requires privacy policy acceptance to submit',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final auth = _FakeAuthService();
      await tester.pumpWidget(_wrap(SignupPage(authService: auth)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('signup-privacy-checkbox')), findsOneWidget);
      expect(find.byKey(const Key('signup-privacy-link')), findsOneWidget);

      // Fill valid credentials: shop name, email, password, confirm password
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'ร้านของฉัน');
      await tester.enterText(textFields.at(1), 'newshop@example.com');
      await tester.enterText(textFields.at(2), 'secret123');
      await tester.enterText(textFields.at(3), 'secret123');

      // Attempt submit without checking checkbox
      await tester.tap(find.widgetWithText(FilledButton, 'สมัครสมาชิก'));
      await tester.pumpAndSettle();

      expect(find.text('กรุณายอมรับนโยบายความเป็นส่วนตัวก่อนสมัครสมาชิก'),
          findsOneWidget);
      expect(auth.signUpCalls, 0);

      // Check the privacy checkbox
      await tester.tap(find.byKey(const Key('signup-privacy-checkbox')));
      await tester.pumpAndSettle();

      // Submit again
      await tester.tap(find.widgetWithText(FilledButton, 'สมัครสมาชิก'));
      await tester.pumpAndSettle();

      expect(auth.signUpCalls, 1);
      expect(auth.lastSignedUpShop, 'ร้านของฉัน');
      expect(auth.lastSignedUpEmail, 'newshop@example.com');

      // Dismiss dialog
      expect(find.text('สมัครสมาชิกสำเร็จ'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'ตกลง'));
      await tester.pumpAndSettle();
    });

    testWidgets(
        'SettingsDialog - displays About & Legal section and Privacy Policy button',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final settings = AppSettingsController();
      final auth = _FakeAuthService();

      await tester.pumpWidget(
        _wrap(
          SettingsDialog(
            authService: auth,
          ),
          settings,
        ),
      );
      await tester.pumpAndSettle();

      // Verify About & Legal section and Privacy Policy button in Thai
      expect(find.byKey(const Key('settings-privacy-policy-button')),
          findsOneWidget);
      expect(find.text('เกี่ยวกับและนโยบาย'), findsOneWidget);
      expect(find.text('นโยบายความเป็นส่วนตัว'), findsOneWidget);

      // Switch language to English using the dialog's language switch button
      await tester.tap(find.byKey(const Key('settings-lang-en')));
      await tester.pumpAndSettle();

      expect(find.text('About & Legal'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);

      // Tap Privacy Policy button without crash
      await tester.tap(find.byKey(const Key('settings-privacy-policy-button')));
      await tester.pumpAndSettle();
    });
  });
}
