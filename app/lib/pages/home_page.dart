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
    final textTheme = Theme.of(context).textTheme;
    final app = AppColors.of(context);
    final strings = context.strings;
    final isDark = context.isDarkMode;

    return Scaffold(
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const _Logo(),
                const Spacer(),
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
                    color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF64748B),
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
                  icon: const Icon(Icons.settings_outlined, size: 18),
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
            const SizedBox(height: 16),
            Text('COD Risk Shield', style: textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              strings.appSubtitle,
              style: textTheme.bodyLarge?.copyWith(color: app.muted),
            ),
            const SizedBox(height: AppSpacing.section),
            const _StatsRow(),
            const SizedBox(height: AppSpacing.section),
            Text(strings.checkCustomer, style: textTheme.titleMedium),
            const SizedBox(height: 8),
            CheckPanel(checkService: widget.checkService),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              key: const Key('home-report'),
              onPressed: _openReport,
              icon: const Icon(Icons.report_outlined),
              label: Text(strings.reportCustomer),
            ),
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
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary,
            const Color(0xFF3B82F6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withOpacity(0.4),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(Icons.verified_user_rounded, color: colors.onPrimary, size: 26),
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
    final app = AppColors.of(context);
    final strings = context.strings;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.storefront_outlined, size: 18, color: app.muted),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 80),
          child: Text(
            shopName,
            key: const Key('home-shop-name'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: app.muted),
          ),
        ),
        IconButton(
          key: const Key('home-logout'),
          tooltip: strings.signOut,
          onPressed: onSignOut,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          icon: const Icon(Icons.logout, size: 18),
        ),
      ],
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
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            value: strings.protectedCount,
            label: strings.protectedLabel,
            icon: Icons.shield_outlined,
          ),
        ),
        const SizedBox(width: 8),
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
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final app = AppColors.of(context);
    return Card(
      elevation: 0,
      color: app.card.withOpacity(0.85),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: app.border.withOpacity(0.8)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: colors.primary),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: app.muted,
                fontSize: 11,
              ),
            ),
          ],
        ),
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
