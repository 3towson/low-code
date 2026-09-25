import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/app_settings.dart';
import '../services/auth_service.dart';
import '../services/check_service.dart';
import '../services/report_service.dart';
import '../theme.dart';
import '../widgets/check_panel.dart';
import '../widgets/page_body.dart';
import '../widgets/settings_dialog.dart';
import 'login_page.dart';
import 'report_customer_page.dart';

/// หน้าแรกของแอป ใช้ตรวจสอบลูกค้าได้โดยไม่ต้อง login
/// การรายงานลูกค้าต้อง login ก่อน
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.authService,
    required this.checkService,
    required this.reportService,
    required this.signedIn,
  });

  final AuthService authService;
  final CheckService checkService;
  final ReportService reportService;
  final bool signedIn;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    // สำเร็จแล้ว AuthGate จะส่ง signedIn = false มาเอง
    await widget.authService.signOut();
    if (mounted) setState(() => _signingOut = false);
  }

  /// เปิดหน้า Login เมื่อ login สำเร็จจะไปหน้า [next] แทน หรือกลับหน้านี้ถ้าไม่ระบุ
  void _openLogin({WidgetBuilder? next}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _LoginThen(authService: widget.authService, next: next),
      ),
    );
  }

  void _openReport() {
    Widget report(BuildContext _) => ReportCustomerPage(
      reportService: widget.reportService,
      checkService: widget.checkService,
    );
    if (widget.signedIn) {
      Navigator.of(context).push(MaterialPageRoute(builder: report));
    } else {
      _openLogin(next: report);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFF),
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Floating Top Navbar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xE6131D31) : Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF22304A) : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const _Logo(),
                  const Spacer(),
                  // Quick Theme Toggle
                  IconButton(
                    key: const Key('theme-toggle-button'),
                    tooltip: isDark ? strings.switchToLight : strings.switchToDark,
                    onPressed: () => context.appSettings?.toggleTheme(),
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: const Size(28, 28),
                      padding: const EdgeInsets.all(4),
                    ),
                    icon: Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      size: 18,
                      color: isDark ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
                    ),
                  ),
                  IconButton(
                    key: const Key('settings-button'),
                    tooltip: strings.settings,
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const SettingsDialog(),
                    ),
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: const Size(28, 28),
                      padding: const EdgeInsets.all(4),
                    ),
                    icon: Icon(
                      Icons.settings_outlined,
                      size: 18,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  if (widget.signedIn)
                    _AccountBar(
                      shopName: widget.authService.shopName,
                      onSignOut: _signingOut ? null : _signOut,
                    )
                  else
                    TextButton.icon(
                      key: const Key('home-login'),
                      onPressed: _openLogin,
                      style: TextButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: const Size(0, 32),
                      ),
                      icon: const Icon(Icons.login, size: 16),
                      label: Text(strings.signIn),
                    ),
                ],
              ),
            ),

            // 2. Centered Hero Header
            const SizedBox(height: 20),
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF16233B) : const Color(0xFFF1F5F9),
                    border: Border.all(
                      color: isDark ? const Color(0xFF22304A) : const Color(0xFFE2E8F0),
                    ),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF3B82F6),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'AI Risk Protection for Online Merchants',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'COD Risk Shield',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              strings.appSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 22),

            // 3. Stats Row
            const _StatsRow(),
            const SizedBox(height: 20),

            // 4. Check Customer Panel Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xE6131D31) : Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? const Color(0xFF22304A) : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          strings.checkCustomer,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF16233B) : const Color(0xFFEFF6FF),
                          border: Border.all(
                            color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFBFDBFE),
                          ),
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_outlined, size: 13, color: Color(0xFF3B82F6)),
                            SizedBox(width: 4),
                            Text(
                              'AI Powered',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF3B82F6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CheckPanel(checkService: widget.checkService),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 5. Report Customer CTA Button
            OutlinedButton.icon(
              key: const Key('home-report'),
              onPressed: _openReport,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: const BorderSide(color: Color(0xFFDC2626), width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: isDark
                    ? const Color(0x20DC2626)
                    : const Color(0x0CDC2626),
              ),
              icon: const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFDC2626)),
              label: Text(
                strings.reportCustomer,
                style: const TextStyle(
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),

            // 6. Footer
            const SizedBox(height: 32),
            Text(
              '© 2026 COD Risk Shield — ระบบตรวจสอบและป้องกันพัสดุตีกลับสำหรับร้านค้าออนไลน์',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2563EB),
            Color(0xFF3B82F6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x402563EB),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 22),
    );
  }
}

/// ชื่อร้านและปุ่มออกจากระบบ มุมขวาบน
class _AccountBar extends StatelessWidget {
  const _AccountBar({required this.shopName, required this.onSignOut});

  final String shopName;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final strings = context.strings;
    return Container(
      height: 36,
      padding: const EdgeInsets.only(left: 10, right: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16233B) : const Color(0xFFF1F5F9),
        border: Border.all(
          color: isDark ? const Color(0xFF22304A) : const Color(0xFFE2E8F0),
        ),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.storefront_outlined,
            size: 15,
            color: isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB),
          ),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 80),
            child: Text(
              shopName,
              key: const Key('home-shop-name'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          IconButton(
            key: const Key('home-logout'),
            tooltip: strings.signOut,
            onPressed: onSignOut,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: Icon(
              Icons.logout_rounded,
              size: 15,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

/// ตัวเลขสรุปของเครือข่าย
class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            value: strings.shopsCount,
            label: strings.shopsLabel,
            icon: Icons.storefront_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            value: strings.protectedCount,
            label: strings.protectedLabel,
            icon: Icons.shield_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            value: strings.savedCount,
            label: strings.savedLabel,
            icon: Icons.trending_up_rounded,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xE6131D31) : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF22304A) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF16233B) : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF3B82F6)),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ห่อหน้า Login (ซึ่งไม่ปิดตัวเองเมื่อ login สำเร็จ) รอฟังสถานะ login
/// แล้วแทนที่ตัวเองด้วยหน้า [next] หรือปิดตัวเองกลับหน้าก่อนหน้า
class _LoginThen extends StatefulWidget {
  const _LoginThen({required this.authService, this.next});

  final AuthService authService;
  final WidgetBuilder? next;

  @override
  State<_LoginThen> createState() => _LoginThenState();
}

class _LoginThenState extends State<_LoginThen> {
  late final StreamSubscription<AuthState> _subscription;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _subscription = widget.authService.onAuthStateChange.listen((state) {
      if (state.session != null) _leave();
    }, onError: (Object _) {});
  }

  void _leave() {
    if (_done || !mounted) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    _done = true;
    final nav = Navigator.of(context);
    final next = widget.next;
    if (next == null) {
      route.isCurrent ? nav.pop() : nav.removeRoute(route);
    } else if (route.isCurrent) {
      nav.pushReplacement(MaterialPageRoute(builder: next));
    } else {
      nav.replace(
        oldRoute: route,
        newRoute: MaterialPageRoute(builder: next),
      );
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // หน้า Login ไม่มี AppBar จึงเพิ่มปุ่มย้อนกลับไว้มุมซ้ายบน
    return Stack(
      children: [
        LoginPage(authService: widget.authService),
        const SafeArea(
          child: Material(
            type: MaterialType.transparency,
            child: Padding(padding: EdgeInsets.all(4), child: BackButton()),
          ),
        ),
      ],
    );
  }
}
