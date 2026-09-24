import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'services/auth_service.dart';

class CodCheckApp extends StatelessWidget {
  CodCheckApp({super.key, required this.authService});

  final AuthService authService;
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ตรวจสอบลูกค้า COD',
      navigatorKey: _navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: AuthGate(authService: authService, navigatorKey: _navigatorKey),
    );
  }
}

/// ตัดสินว่าจะแสดง Login หรือ Home จาก onAuthStateChange
/// session ถูกเก็บในเครื่องโดย supabase_flutter จึงยังอยู่ในระบบหลังปิดเปิดแอป
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.authService,
    required this.navigatorKey,
  });

  final AuthService authService;
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
        // สถานะเปลี่ยน (เช่น session หมดอายุตอนอยู่หน้าย่อย) ให้ปิดหน้าที่ซ้อนอยู่ทั้งหมด
        if (wasSignedIn != (state.session != null)) {
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
    final session = _session;
    if (session == null) {
      return LoginPage(authService: widget.authService);
    }
    return HomePage(
      key: ValueKey(session.user.id),
      authService: widget.authService,
    );
  }
}
