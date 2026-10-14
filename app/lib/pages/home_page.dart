import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/admin_service.dart';
import '../services/app_settings.dart';
import '../services/auth_service.dart';
import '../services/check_service.dart';
import '../services/merchant_kyc_service.dart';
import '../services/report_service.dart';
import '../theme.dart';
import '../utils/url_helper.dart';
import '../widgets/check_panel.dart';
import '../widgets/delete_account_dialog.dart';
import '../widgets/merchant_kyc_dialog.dart';
import '../widgets/page_body.dart';
import '../widgets/settings_dialog.dart';
import 'admin_dashboard_page.dart';
import 'login_page.dart';
import 'report_customer_page.dart';

/// หน้าแรกของแอป ใช้ตรวจสอบลูกค้าได้โดยไม่ต้อง login
/// การรายงานลูกค้าต้อง login ก่อน และร้านค้าต้องได้รับการยืนยันตัวตน (Verified Merchant)
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.authService,
    required this.checkService,
    required this.reportService,
    this.adminService,
    this.kycService,
    required this.signedIn,
    this.animatePulse = true,
  });

  final AuthService authService;
  final CheckService checkService;
  final ReportService reportService;
  final AdminService? adminService;
  final MerchantKycService? kycService;
  final bool signedIn;
  final bool animatePulse;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _signingOut = false;
  MerchantKycInfo? _kycInfo;

  @override
  void initState() {
    super.initState();
    _loadKycStatus();
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.signedIn != oldWidget.signedIn) {
      _loadKycStatus();
    }
  }

  MerchantKycService? get _effectiveKycService {
    if (widget.kycService != null) return widget.kycService;
    try {
      return MerchantKycService(Supabase.instance.client);
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadKycStatus() async {
    if (!widget.signedIn) {
      if (mounted) setState(() => _kycInfo = null);
      return;
    }
    final kycSvc = _effectiveKycService;
    if (kycSvc != null) {
      try {
        final info = await kycSvc.getKycStatus();
        if (mounted) setState(() => _kycInfo = info);
      } catch (e) {
        debugPrint('Load KYC status error: $e');
      }
    }
    _loadAdminStatus();
  }

  Future<void> _loadAdminStatus() async {
    if (!widget.signedIn) return;
    try {
      final wasAdmin = widget.authService.isAdmin;
      final isNowAdmin = await widget.authService.checkIsAdmin();
      if (mounted && wasAdmin != isNowAdmin) {
        setState(() {});
      }
    } catch (_) {}
  }

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    // สำเร็จแล้ว AuthGate จะส่ง signedIn = false มาเอง
    await widget.authService.signOut();
    if (mounted) setState(() => _signingOut = false);
  }

  Future<void> _openDeleteAccount() async {
    final deleted = await DeleteAccountDialog.show(
      context,
      authService: widget.authService,
    );
    if (deleted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.strings.deleteAccountSuccess),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  Route<T> _modalRoute<T>(WidgetBuilder builder) {
    return PageRouteBuilder<T>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      pageBuilder: (context, anim, secAnim) => builder(context),
      transitionsBuilder: (context, anim, secAnim, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: const Cubic(0.16, 1, 0.3, 1),
        );
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  /// เปิดหน้า Login เมื่อ login สำเร็จจะไปหน้า [next] แทน หรือกลับหน้านี้ถ้าไม่ระบุ
  void _openLogin({WidgetBuilder? next}) {
    Navigator.of(context).push(
      _modalRoute(
        (_) => _LoginThen(authService: widget.authService, next: next),
      ),
    );
  }

  void _openAdmin() {
    final adminSvc =
        widget.adminService ?? AdminService(Supabase.instance.client);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminDashboardPage(
          adminService: adminSvc,
        ),
      ),
    );
  }

  void _openKycDialog() {
    final kycSvc = _effectiveKycService;
    if (kycSvc == null) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => MerchantKycDialog(
        shopName: widget.authService.shopName,
        kycService: kycSvc,
        initialInfo: _kycInfo,
        onSubmitted: () => _loadKycStatus(),
      ),
    );
  }

  Future<void> _openReport() async {
    Widget report(BuildContext _) => ReportCustomerPage(
      reportService: widget.reportService,
      checkService: widget.checkService,
    );

    if (!widget.signedIn) {
      _openLogin(next: report);
      return;
    }

    // P1-3.5: ดึงสถานะ KYC ใหม่ทุกครั้งที่กดรายงานเพื่อป้องกันกรณีเพิ่งได้รับการอนุมัติ
    MerchantKycInfo? info = _kycInfo;
    final kycSvc = _effectiveKycService;
    if (kycSvc != null) {
      try {
        info = await kycSvc.getKycStatus();
        if (mounted) setState(() => _kycInfo = info);
      } catch (e) {
        debugPrint('Fetch KYC on open report error: $e');
        // P1-3.4: แยก error ออกมา ไม่สรุปว่าเป็น unverified
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('โหลดสถานะการยืนยันตัวตนร้านค้าไม่สำเร็จ กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ตแล้วลองใหม่'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        return;
      }
    }

    if (!mounted) return;

    // ตรวจสอบสถานะ KYC ของร้านค้า
    if (info != null) {
      if (info.isApproved) {
        Navigator.of(context).push(_modalRoute(report));
        return;
      }

      if (info.isSuspended) {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(
              Icons.block_rounded,
              color: Color(0xFFEF4444),
              size: 36,
            ),
            title: const Text('บัญชีร้านค้าถูกระงับการใช้งาน'),
            content: Text(
              'ร้านค้าของคุณถูกระงับสิทธิ์การรายงานลูกค้า COD ชั่วคราว '
              'เนื่องจากละเมิดข้อกำหนดการใช้งาน UGC หรือสร้างรายงานเท็จ\n\n'
              'เหตุผล: ${info?.rejectionReason ?? "ละเมิดข้อกำหนดการใช้งาน UGC"}\n\n'
              'หากเห็นว่าเป็นข้อผิดพลาด สามารถติดต่อทีมงานได้ที่ ${AppUrls.supportEmail}',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('รับทราบ'),
              ),
            ],
          ),
        );
        return;
      }

      if (info.isPending) {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(
              Icons.hourglass_top_rounded,
              color: Color(0xFFF59E0B),
              size: 36,
            ),
            title: const Text('อยู่ระหว่างรอการอนุมัติร้านค้า'),
            content: Text(
              'คำขอยืนยันตัวตนของร้าน "${widget.authService.shopName}" อยู่ระหว่างการตรวจสอบโดยผู้ดูแลระบบ (ใช้เวลา 24-48 ชม.)\n\n'
              'เมื่อผ่านการอนุมัติแล้ว คุณจะได้รับสิทธิ์ส่งรายงานลูกค้า COD ทันที',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('รับทราบ'),
              ),
            ],
          ),
        );
        return;
      }

      // unverified หรือ rejected
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(
            Icons.verified_user_outlined,
            color: Color(0xFF3B82F6),
            size: 36,
          ),
          title: const Text('ต้องยืนยันตัวตนร้านค้าก่อนรายงาน'),
          content: const Text(
            'เพื่อป้องกันการสแปมและรักษาความน่าเชื่อถือของฐานข้อมูล '
            'ร้านค้าต้องส่งหลักฐานการเปิดร้านและประวัติการส่งสินค้าจริง (>50 ออเดอร์) '
            'และได้รับการอนุมัติจากผู้ดูแลระบบก่อนส่งรายงานลูกค้า',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('ไว้คราวหลัง'),
            ),
            FilledButton.icon(
              key: const Key('open-kyc-from-prompt'),
              onPressed: () {
                Navigator.of(ctx).pop();
                _openKycDialog();
              },
              icon: const Icon(Icons.badge_outlined, size: 16),
              label: const Text('ยืนยันตัวตนร้านค้า'),
            ),
          ],
        ),
      );
      return;
    }

    // fallback หากยังไม่มีข้อมูล KYC
    Navigator.of(context).push(_modalRoute(report));
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final isDark = context.isDarkMode;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFF),
      body: Stack(
        children: [
          // Background ambient glow
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: AmbientGlowPainter(primary: primary, isDark: isDark),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Sticky Full-width Top Navbar
                _TopNavbar(
                  signedIn: widget.signedIn,
                  isAdmin: widget.signedIn && widget.authService.isAdmin,
                  shopName: widget.signedIn ? widget.authService.shopName : null,
                  kycInfo: _kycInfo,
                  onOpenKyc: _openKycDialog,
                  signingOut: _signingOut,
                  onSignOut: _signingOut ? null : _signOut,
                  onDeleteAccount: _signingOut ? null : _openDeleteAccount,
                  authService: widget.signedIn ? widget.authService : null,
                  onOpenLogin: _openLogin,
                  onOpenAdmin: _openAdmin,
                ),
                // 2. Scrollable Body Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: AppSpacing.maxContentWidth,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 2. Centered Hero Header
                            const SizedBox(height: 8),
                            Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF16233B)
                                        : const Color(0xFFF1F5F9),
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF22304A)
                                          : const Color(0xFFE2E8F0),
                                    ),
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _PulsingDot(animate: widget.animatePulse),
                                      SizedBox(width: 8),
                                      Text(
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
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [
                                  isDark
                                      ? const Color(0xFFF1F5F9)
                                      : const Color(0xFF0F172A),
                                  const Color(0xFF3B82F6),
                                ],
                                stops: const [0.65, 1.0],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds),
                              blendMode: BlendMode.srcIn,
                              child: const Text(
                                'COD Risk Shield',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              strings.appSubtitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 22),

                            // 3. Stats Row
                            const _StatsRow(),
                            const SizedBox(height: 22),

                            // 4. Check Customer Panel Card
                            Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xE6131D31)
                                    : Colors.white.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF22304A)
                                      : const Color(0xFFE2E8F0),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha: isDark ? 0.3 : 0.05,
                                    ),
                                    blurRadius: 18,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          strings.checkCustomer,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? const Color(0xFFF1F5F9)
                                                : const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF16233B)
                                              : const Color(0xFFEFF6FF),
                                          border: Border.all(
                                            color: isDark
                                                ? const Color(0xFF1E3A8A)
                                                : const Color(0xFFBFDBFE),
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(9999),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.shield_outlined,
                                              size: 13,
                                              color: Color(0xFF3B82F6),
                                            ),
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
                                  const SizedBox(height: 18),
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
                                side: const BorderSide(
                                  color: Color(0xFFDC2626),
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                backgroundColor: isDark
                                    ? const Color(0x1FDC2626)
                                    : const Color(0x0CDC2626),
                              ),
                              icon: const Icon(
                                Icons.error_outline_rounded,
                                size: 18,
                                color: Color(0xFFDC2626),
                              ),
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
                            const SizedBox(height: 36),
                            Divider(
                              height: 1,
                              color: isDark
                                  ? const Color(0xFF22304A)
                                  : const Color(0xFFE2E8F0),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              '© 2026 COD Risk Shield — ระบบตรวจสอบและป้องกันพัสดุตีกลับสำหรับร้านค้าออนไลน์',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isDark
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
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

/// Pulsing blue dot in hero badge with smooth pulse animation
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({this.animate = true});

  final bool animate;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.animate) {
      _controller.repeat();
    }

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.95), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.7), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFF3B82F6),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x803B82F6),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Sticky Top Navbar with Glassmorphism
class _TopNavbar extends StatelessWidget {
  const _TopNavbar({
    required this.signedIn,
    this.isAdmin = false,
    this.shopName,
    this.kycInfo,
    this.onOpenKyc,
    required this.signingOut,
    required this.onSignOut,
    this.onDeleteAccount,
    this.authService,
    required this.onOpenLogin,
    this.onOpenAdmin,
  });

  final bool signedIn;
  final bool isAdmin;
  final String? shopName;
  final MerchantKycInfo? kycInfo;
  final VoidCallback? onOpenKyc;
  final bool signingOut;
  final VoidCallback? onSignOut;
  final VoidCallback? onDeleteAccount;
  final AuthService? authService;
  final VoidCallback onOpenLogin;
  final VoidCallback? onOpenAdmin;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final isDark = context.isDarkMode;

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xCC0B1120)
                : Colors.white.withValues(alpha: 0.85),
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? const Color(0xFF22304A)
                    : const Color(0xFFE2E8F0),
              ),
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.maxContentWidth,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const _Logo(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _BrandTitle(
                        isDark: isDark,
                        subtitle: strings.appSubtitle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Quick Theme Toggle
                    IconButton(
                      key: const Key('theme-toggle-button'),
                      tooltip: isDark
                          ? strings.switchToLight
                          : strings.switchToDark,
                      onPressed: () => context.appSettings?.toggleTheme(),
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: const Size(34, 34),
                        maximumSize: const Size(34, 34),
                        padding: EdgeInsets.zero,
                        side: BorderSide(
                          color: isDark
                              ? const Color(0xFF22304A)
                              : const Color(0xFFE2E8F0),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: Icon(
                        isDark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        size: 16,
                        color: isDark
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      key: const Key('settings-button'),
                      tooltip: strings.settings,
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => SettingsDialog(
                          authService: authService,
                        ),
                      ),
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: const Size(34, 34),
                        maximumSize: const Size(34, 34),
                        padding: EdgeInsets.zero,
                        side: BorderSide(
                          color: isDark
                              ? const Color(0xFF22304A)
                              : const Color(0xFFE2E8F0),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: Icon(
                        Icons.settings_outlined,
                        size: 16,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    if (signedIn && isAdmin) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        key: const Key('home-admin-button'),
                        tooltip: 'แผงควบคุมผู้ดูแลระบบ (Admin Console)',
                        onPressed: onOpenAdmin,
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: const Size(34, 34),
                          maximumSize: const Size(34, 34),
                          padding: EdgeInsets.zero,
                          side: BorderSide(
                            color: isDark
                                ? const Color(0xFF3B82F6).withValues(alpha: 0.5)
                                : const Color(0xFF2563EB).withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(
                          Icons.admin_panel_settings_rounded,
                          size: 16,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    if (signedIn)
                      _AccountBar(
                        shopName: shopName ?? '',
                        kycInfo: kycInfo,
                        onOpenKyc: onOpenKyc,
                        onSignOut: signingOut ? null : onSignOut,
                        onOpenSettings: () => showDialog(
                          context: context,
                          builder: (_) => SettingsDialog(
                            authService: authService,
                          ),
                        ),
                      )
                    else
                      TextButton.icon(
                        key: const Key('home-login'),
                        onPressed: onOpenLogin,
                        style: TextButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(0, 34),
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              color: isDark
                                  ? const Color(0xFF22304A)
                                  : const Color(0xFFE2E8F0),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.login, size: 15),
                        label: Text(
                          strings.signIn,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle({required this.isDark, required this.subtitle});

  final bool isDark;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        if (availableWidth < 60) return const SizedBox.shrink();
        final showSubtitle = availableWidth >= 135;
        final height = showSubtitle ? 34.0 : 18.0;
        return CustomPaint(
          size: Size(availableWidth, height),
          painter: _BrandTitlePainter(
            isDark: isDark,
            subtitle: subtitle,
            showSubtitle: showSubtitle,
          ),
        );
      },
    );
  }
}

class _BrandTitlePainter extends CustomPainter {
  const _BrandTitlePainter({
    required this.isDark,
    required this.subtitle,
    required this.showSubtitle,
  });

  final bool isDark;
  final String subtitle;
  final bool showSubtitle;

  @override
  void paint(Canvas canvas, Size size) {
    final titlePainter = TextPainter(
      text: TextSpan(
        text: 'COD Risk Shield',
        style: TextStyle(
          fontFamily: 'Prompt',
          fontSize: 15.5,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
          letterSpacing: -0.2,
        ),
      ),
      maxLines: 1,
      ellipsis: '...',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    titlePainter.paint(canvas, Offset.zero);

    if (showSubtitle) {
      final subtitlePainter = TextPainter(
        text: TextSpan(
          text: subtitle,
          style: TextStyle(
            fontFamily: 'Prompt',
            fontSize: 11,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        maxLines: 1,
        ellipsis: '...',
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      subtitlePainter.paint(canvas, const Offset(0, 18));
    }
  }

  @override
  bool shouldRepaint(covariant _BrandTitlePainter oldDelegate) =>
      oldDelegate.isDark != isDark ||
      oldDelegate.subtitle != subtitle ||
      oldDelegate.showSubtitle != showSubtitle;
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
          colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(11),
        boxShadow: const [
          BoxShadow(
            color: Color(0x402563EB),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(
        Icons.shield_outlined,
        color: Colors.white,
        size: 22,
      ),
    );
  }
}

/// ชื่อร้าน สถานะยืนยันตัวตน และปุ่มออกจากระบบ มุมขวาบน
class _AccountBar extends StatelessWidget {
  const _AccountBar({
    required this.shopName,
    this.kycInfo,
    this.onOpenKyc,
    required this.onSignOut,
    this.onOpenSettings,
  });

  final String shopName;
  final MerchantKycInfo? kycInfo;
  final VoidCallback? onOpenKyc;
  final VoidCallback? onSignOut;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final strings = context.strings;
    return Container(
      height: 34,
      padding: const EdgeInsets.only(left: 8, right: 3),
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
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpenSettings,
              borderRadius: BorderRadius.circular(9999),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    size: 15,
                    color: isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 80),
                    child: Text(
                      shopName,
                      key: const Key('home-shop-name'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (kycInfo != null) ...[
            const SizedBox(width: 4),
            _KycBadge(kycInfo: kycInfo!, onOpenKyc: onOpenKyc),
          ],
          IconButton(
            key: const Key('home-logout'),
            tooltip: strings.signOut,
            onPressed: onSignOut,
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              minimumSize: const Size(26, 26),
              maximumSize: const Size(26, 26),
              padding: EdgeInsets.zero,
            ),
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

class _KycBadge extends StatelessWidget {
  const _KycBadge({required this.kycInfo, this.onOpenKyc});

  final MerchantKycInfo kycInfo;
  final VoidCallback? onOpenKyc;

  @override
  Widget build(BuildContext context) {
    if (kycInfo.isApproved) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 10, color: Color(0xFF10B981)),
            SizedBox(width: 2),
            Text(
              'Verified',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF10B981),
              ),
            ),
          ],
        ),
      );
    }

    if (kycInfo.isPending) {
      return Tooltip(
        message: 'คำขอยืนยันร้านค้าอยู่ระหว่างรอตรวจสอบ',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_top_rounded,
                  size: 10, color: Color(0xFFF59E0B)),
              SizedBox(width: 2),
              Text(
                'รออนุมัติ',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      key: const Key('home-verify-store-badge'),
      onTap: onOpenKyc,
      borderRadius: BorderRadius.circular(6),
      child: Tooltip(
        message: 'คลิกเพื่อส่งหลักฐานยืนยันตัวตนร้านค้า',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, size: 10, color: Color(0xFF3B82F6)),
              SizedBox(width: 2),
              Text(
                'ยืนยันร้าน',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3B82F6),
                ),
              ),
            ],
          ),
        ),
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

class _StatTile extends StatefulWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  State<_StatTile> createState() => _StatTileState();
}

class _StatTileState extends State<_StatTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final borderColor = _hovered
        ? const Color(0xFF3B82F6)
        : (isDark ? const Color(0xFF22304A) : const Color(0xFFE2E8F0));

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: _hovered
            ? Matrix4.translationValues(0.0, -2.0, 0.0)
            : Matrix4.identity(),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xE6131D31)
              : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: borderColor,
            width: _hovered ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: _hovered ? 14 : 10,
              offset: Offset(0, _hovered ? 5 : 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF16233B) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(widget.icon, size: 18, color: const Color(0xFF3B82F6)),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                widget.value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? const Color(0xFFF1F5F9)
                      : const Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
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
      nav.pushReplacement(
        PageRouteBuilder(
          opaque: false,
          barrierDismissible: true,
          barrierColor: Colors.black.withValues(alpha: 0.65),
          pageBuilder: (ctx, anim, secAnim) => next(ctx),
          transitionsBuilder: (ctx, anim, secAnim, child) {
            final curved = CurvedAnimation(
              parent: anim,
              curve: const Cubic(0.16, 1, 0.3, 1),
            );
            return FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
                child: child,
              ),
            );
          },
        ),
      );
    } else {
      nav.replace(
        oldRoute: route,
        newRoute: PageRouteBuilder(
          opaque: false,
          barrierDismissible: true,
          barrierColor: Colors.black.withValues(alpha: 0.65),
          pageBuilder: (ctx, anim, secAnim) => next(ctx),
        ),
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
