import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'check_customer_page.dart';
import 'report_customer_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.authService});

  final AuthService authService;

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
    return Scaffold(
      appBar: AppBar(title: const Text('หน้าหลัก')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('ร้านของคุณ', style: textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(widget.authService.shopName,
                      style: textTheme.headlineSmall),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: () => _open(const CheckCustomerPage()),
                    icon: const Icon(Icons.search),
                    label: const Text('ตรวจสอบลูกค้า'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: () => _open(const ReportCustomerPage()),
                    icon: const Icon(Icons.report_outlined),
                    label: const Text('รายงานลูกค้า'),
                  ),
                  const SizedBox(height: 32),
                  OutlinedButton.icon(
                    onPressed: _signingOut ? null : _signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('ออกจากระบบ'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
