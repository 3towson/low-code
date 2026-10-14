import 'package:url_launcher/url_launcher.dart';

/// URL สาธารณะสำหรับเอกสารนโยบายและบริการ
class AppUrls {
  AppUrls._();

  static const String privacyPolicy =
      'https://3towson.github.io/low-code/privacy-policy.html';

  static const String terms =
      'https://3towson.github.io/low-code/terms.html';

  static const String accountDeletion =
      'https://3towson.github.io/low-code/delete-account.html';

  static const String disputePortal =
      'https://3towson.github.io/low-code/dispute.html';

  static const String supportEmail = 'codriskshield.support@gmail.com';
  static const String disputeEmail = 'codriskshield.support@gmail.com';
  static const String privacyEmail = 'codriskshield.support@gmail.com';

  static const String supportEmailMailto =
      'mailto:codriskshield.support@gmail.com?subject=COD%20Risk%20Shield%20Support';

  static const String supportLineUrl = 'https://line.me/R/ti/p/@codcheck';

  static const String supportLineId = '@codcheck';
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
