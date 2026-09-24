import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/check_service.dart';
import '../services/report_service.dart';
import '../theme.dart';
import '../widgets/page_body.dart';
import 'check_customer_page.dart';
import 'report_customer_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.authService,
    required this.checkService,
    required this.reportService,
  });

  final AuthService authService;
  final CheckService checkService;
  final ReportService reportService;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    // สำเร็จแล้ว AuthGate จะสลับกลับไปหน้า Login เอง
    await widget.authService.signOut();
  }

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final app = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('COD Check',
            style: textTheme.titleLarge?.copyWith(color: colors.primary)),
        actions: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.storefront_outlined, size: 18, color: app.muted),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    widget.authService.shopName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelLarge?.copyWith(color: app.muted),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'ออกจากระบบ',
            onPressed: _signingOut ? null : _signOut,
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: PageBody(
        centerVertically: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ActionCard(
              icon: Icons.search,
              color: colors.primary,
              title: 'ตรวจสอบลูกค้า',
              subtitle: 'วางข้อความออเดอร์เพื่อตรวจสอบ',
              onTap: () =>
                  _open(CheckCustomerPage(checkService: widget.checkService)),
            ),
            const SizedBox(height: 16),
            _ActionCard(
              icon: Icons.report_outlined,
              color: app.danger,
              title: 'รายงานลูกค้า',
              subtitle: 'บันทึกลูกค้าที่มีประวัติปฏิเสธรับสินค้า',
              onTap: () => _open(
                  ReportCustomerPage(reportService: widget.reportService)),
            ),
          ],
        ),
      ),
    );
  }
}

/// การ์ดเมนูขนาดใหญ่ แตะได้ทั้งใบ
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final app = AppColors.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: textTheme.bodyMedium?.copyWith(color: app.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: app.muted),
            ],
          ),
        ),
      ),
    );
  }
}
