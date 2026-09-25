import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/home_page.dart';
import 'services/auth_service.dart';
import 'services/check_service.dart';
import 'services/report_service.dart';
import 'theme.dart';

import 'services/app_settings.dart';

class CodCheckApp extends StatefulWidget {
  const CodCheckApp({
    super.key,
    required this.authService,
    required this.checkService,
    required this.reportService,
    this.themeMode = ThemeMode.dark,
    this.settingsController,
  });

  final AuthService authService;
  final CheckService checkService;
  final ReportService reportService;
  final ThemeMode themeMode;
  final AppSettingsController? settingsController;

  @override
  State<CodCheckApp> createState() => _CodCheckAppState();
}

class _CodCheckAppState extends State<CodCheckApp> {
  late final AppSettingsController _settings;
  late final bool _ownsSettings;
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _ownsSettings = widget.settingsController == null;
    _settings = widget.settingsController ??
        AppSettingsController(
          themeMode: widget.themeMode,
          language: AppLanguage.th,
        );
  }

  @override
  void didUpdateWidget(CodCheckApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.themeMode != oldWidget.themeMode) {
      _settings.setThemeMode(widget.themeMode);
    }
  }

  @override
  void dispose() {
    if (_ownsSettings) {
      _settings.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) {
        return AppSettingsScope(
          controller: _settings,
          child: MaterialApp(
            title: _settings.strings.appTitle,
            navigatorKey: _navigatorKey,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: _settings.themeMode,
            home: AuthGate(
              authService: widget.authService,
              checkService: widget.checkService,
              reportService: widget.reportService,
              navigatorKey: _navigatorKey,
            ),
          ),
        );
      },
    );
  }
}

/// ติดตามสถานะ login จาก onAuthStateChange แล้วส่งให้หน้า Home
/// (หน้า Home ใช้งานได้โดยไม่ต้อง login)
/// session ถูกเก็บในเครื่องโดย supabase_flutter จึงยังอยู่ในระบบหลังปิดเปิดแอป
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.authService,
    required this.checkService,
    required this.reportService,
    required this.navigatorKey,
  });

  final AuthService authService;
  final CheckService checkService;
  final ReportService reportService;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Session? _session = widget.authService.currentSession;
  late final StreamSubscription<AuthState> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.authService.onAuthStateChange.listen(
      (state) {
        final wasSignedIn = _session != null;
        setState(() => _session = state.session);
        // ออกจากระบบ (เช่น session หมดอายุตอนอยู่หน้ารายงาน) ให้ปิดหน้าที่ซ้อนอยู่ทั้งหมด
        // ตอน login ไม่ต้องปิด หน้า Login ที่เปิดจากหน้า Home จะพาไปหน้าถัดไปเอง
        if (wasSignedIn && state.session == null) {
          widget.navigatorKey.currentState?.popUntil((route) => route.isFirst);
        }
      },
      // เช่น refresh token ใช้ไม่ได้แล้ว: ปล่อยให้ event signedOut ที่ตามมาจัดการ
      onError: (Object _) {},
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HomePage(
      authService: widget.authService,
      checkService: widget.checkService,
      reportService: widget.reportService,
      signedIn: _session != null,
    );
  }
}
