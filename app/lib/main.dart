import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'services/auth_service.dart';
import 'services/report_service.dart';

// รับค่าผ่าน --dart-define ตอน build/run ห้ามเขียนค่าจริงลงในโค้ด
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    runApp(const _MissingConfigApp());
    return;
  }

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
    debug: false, // ไม่ให้ log ของ Supabase พิมพ์ token ออกมา
  );
  final client = Supabase.instance.client;
  runApp(CodCheckApp(
    authService: AuthService(client.auth),
    reportService: ReportService(client.functions),
  ));
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'ไม่พบค่า SUPABASE_URL หรือ SUPABASE_ANON_KEY\n'
              'กรุณารันแอปด้วย --dart-define ตามที่ระบุในเอกสาร',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
