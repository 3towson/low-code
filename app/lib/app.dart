import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/home_page.dart';
import 'services/auth_service.dart';
import 'services/check_service.dart';
import 'services/report_service.dart';
import 'theme.dart';

class CodCheckApp extends StatelessWidget {
  CodCheckApp({
    super.key,
    required this.authService,
    required this.checkService,
    required this.reportService,
    this.themeMode = ThemeMode.dark,
  });

  final AuthService authService;
  final CheckService checkService;
  final ReportService reportService;
  final ThemeMode themeMode;
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ตรวจสอบลูกค้า COD',
      navigatorKey: _navigatorKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: AuthGate(
        authService: authService,
        checkService: checkService,
        reportService: reportService,
        navigatorKey: _navigatorKey,
      ),
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
