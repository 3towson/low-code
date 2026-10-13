import 'package:url_launcher/url_launcher.dart';

/// URL สาธารณะสำหรับเอกสารนโยบายและบริการ
class AppUrls {
  AppUrls._();

  static const String privacyPolicy =
      'https://3towson.github.io/low-code/privacy-policy.html';

  static const String accountDeletion =
      'https://3towson.github.io/low-code/delete-account.html';

  static const String disputePortal =
      'https://3towson.github.io/low-code/dispute.html';
}

/// Helper function สำหรับเปิด URL ภายนอกอย่างปลอดภัย
Future<bool> launchExternalUrl(String urlStr) async {
  try {
    final uri = Uri.parse(urlStr);
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    return false;
  }
}
