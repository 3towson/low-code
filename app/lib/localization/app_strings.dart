import 'package:flutter/foundation.dart';

/// ภาษาที่รองรับในระบบ (ไทย และ อังกฤษ)
enum AppLanguage {
  th,
  en;

  String get code => this == AppLanguage.th ? 'th' : 'en';
  String get displayName => this == AppLanguage.th ? 'ไทย' : 'English';
  String get flag => this == AppLanguage.th ? '🇹🇭' : '🇺🇸';
}

/// รวมข้อความทั้งหมดในแอปเพื่อรองรับ 2 ภาษา
@immutable
class AppStrings {
  const AppStrings._({
    required this.language,
    required this.appTitle,
    required this.appHeadline,
    required this.appSubtitle,
    required this.signIn,
    required this.signOut,
    required this.shopsCount,
    required this.shopsLabel,
    required this.protectedCount,
    required this.protectedLabel,
    required this.savedCount,
    required this.savedLabel,
    required this.checkCustomer,
    required this.reportCustomer,
    required this.checkRiskButton,
    required this.orderHint,
    required this.orderEmptyError,
    required this.noPhoneFound,
    required this.customerPhoneLabel,
    required this.customerPhoneHint,
    required this.checkWithPhoneButton,
    required this.retry,
    required this.riskLow,
    required this.riskMedium,
    required this.riskHigh,
    required this.recGreen,
    required this.recYellow,
    required this.recRed,
    required this.reportCountLabel,
    required this.latestReportLabel,
    required this.phoneLabel,
    required this.customerNameLabel,
    required this.settings,
    required this.settingsTitle,
    required this.themeSection,
    required this.themeSectionDesc,
    required this.themeLight,
    required this.themeDark,
    required this.languageSection,
    required this.languageSectionDesc,
    required this.switchToLight,
    required this.switchToDark,
    required this.close,
  });

  final AppLanguage language;
  final String appTitle;
  final String appHeadline;
  final String appSubtitle;
  final String signIn;
  final String signOut;
  final String shopsCount;
  final String shopsLabel;
  final String protectedCount;
  final String protectedLabel;
  final String savedCount;
  final String savedLabel;
  final String checkCustomer;
  final String reportCustomer;
  final String checkRiskButton;
  final String orderHint;
  final String orderEmptyError;
  final String noPhoneFound;
  final String customerPhoneLabel;
  final String customerPhoneHint;
  final String checkWithPhoneButton;
  final String retry;
  final String riskLow;
  final String riskMedium;
  final String riskHigh;
  final String recGreen;
  final String recYellow;
  final String recRed;
  final String reportCountLabel;
  final String latestReportLabel;
  final String phoneLabel;
  final String customerNameLabel;
  final String settings;
  final String settingsTitle;
  final String themeSection;
  final String themeSectionDesc;
  final String themeLight;
  final String themeDark;
  final String languageSection;
  final String languageSectionDesc;
  final String switchToLight;
  final String switchToDark;
  final String close;

  bool get isThai => language == AppLanguage.th;

  /// แปลงคำแนะนำจาก Edge Function (ภาษาไทย) ให้ตรงกับภาษาปัจจุบัน
  String localizeRecommendation(String rec) {
    if (isThai) return rec;
    if (rec.contains('ส่งได้ตามปกติ')) return recGreen;
    if (rec.contains('ควรโทรหรือทักยืนยันออเดอร์')) return recYellow;
    if (rec.contains('ไม่แนะนำให้ส่งแบบเก็บเงินปลายทาง')) return recRed;
    return rec;
  }

  /// แปลงข้อความระดับความเสี่ยง
  String localizeRiskLevel(String level) {
    switch (level.toLowerCase()) {
      case 'green':
      case 'low':
        return riskLow;
      case 'yellow':
      case 'medium':
      case 'moderate':
        return riskMedium;
      case 'red':
      case 'high':
        return riskHigh;
      default:
        return level;
    }
  }

  static const AppStrings th = AppStrings._(
    language: AppLanguage.th,
    appTitle: 'ตรวจสอบลูกค้า COD',
    appHeadline: 'COD Risk Shield',
    appSubtitle: 'ตรวจก่อนส่ง ป้องกันพัสดุตีกลับ',
    signIn: 'เข้าสู่ระบบ',
    signOut: 'ออกจากระบบ',
    shopsCount: '2,480+',
    shopsLabel: 'ร้านค้า',
    protectedCount: '18,340 ชิ้น',
    protectedLabel: 'ป้องกันแล้ว',
    savedCount: '฿917,000',
    savedLabel: 'ประหยัดได้',
    checkCustomer: 'ตรวจสอบลูกค้า',
    reportCustomer: 'รายงานลูกค้า',
    checkRiskButton: 'ตรวจสอบความเสี่ยง',
    orderHint: 'วางข้อความออเดอร์ แชตลูกค้า หรือที่อยู่จัดส่งที่นี่...',
    orderEmptyError: 'กรุณาวางข้อความออเดอร์',
    noPhoneFound: 'ไม่พบเบอร์โทรในข้อความ กรุณากรอกเบอร์เพื่อตรวจสอบ',
    customerPhoneLabel: 'เบอร์โทรลูกค้า',
    customerPhoneHint: 'เช่น 081-234-5678',
    checkWithPhoneButton: 'ตรวจสอบด้วยเบอร์',
    retry: 'ลองใหม่',
    riskLow: 'ความเสี่ยงต่ำ',
    riskMedium: 'ความเสี่ยงปานกลาง',
    riskHigh: 'ความเสี่ยงสูง',
    recGreen: 'ส่งได้ตามปกติ',
    recYellow: 'ควรโทรหรือทักยืนยันออเดอร์กับลูกค้าก่อนแพ็กสินค้า',
    recRed: 'ไม่แนะนำให้ส่งแบบเก็บเงินปลายทาง ควรให้ลูกค้าโอนชำระก่อน',
    reportCountLabel: 'จำนวนรายงาน',
    latestReportLabel: 'รายงานล่าสุด',
    phoneLabel: 'เบอร์โทร',
    customerNameLabel: 'ชื่อลูกค้า',
    settings: 'ตั้งค่า',
    settingsTitle: 'การตั้งค่าระบบ',
    themeSection: 'ธีมการแสดงผล',
    themeSectionDesc: 'เลือกรูปแบบธีมที่สบายตาสำหรับคุณ',
    themeLight: 'สว่าง',
    themeDark: 'มืด',
    languageSection: 'ภาษา (Language)',
    languageSectionDesc: 'เลือกภาษาสำหรับการแสดงผล',
    switchToLight: 'เปลี่ยนเป็นธีมสว่าง',
    switchToDark: 'เปลี่ยนเป็นธีมมืด',
    close: 'ปิด',
  );

  static const AppStrings en = AppStrings._(
    language: AppLanguage.en,
    appTitle: 'COD Customer Check',
    appHeadline: 'COD Risk Shield',
    appSubtitle: 'Check before shipping, prevent returned parcels',
    signIn: 'Sign In',
    signOut: 'Sign Out',
    shopsCount: '2,480+',
    shopsLabel: 'Shops',
    protectedCount: '18,340 pcs',
    protectedLabel: 'Protected',
    savedCount: '฿917,000',
    savedLabel: 'Saved',
    checkCustomer: 'Check Customer',
    reportCustomer: 'Report Customer',
    checkRiskButton: 'Check Risk',
    orderHint: 'Paste order text, customer chat, or shipping address here...',
    orderEmptyError: 'Please paste order text',
    noPhoneFound: 'No phone number found in text. Please enter manually.',
    customerPhoneLabel: 'Customer Phone',
    customerPhoneHint: 'e.g. 081-234-5678',
    checkWithPhoneButton: 'Check with Phone',
    retry: 'Retry',
    riskLow: 'Low Risk',
    riskMedium: 'Moderate Risk',
    riskHigh: 'High Risk',
    recGreen: 'Safe to ship normally',
    recYellow: 'Confirm order with customer via call/chat before packing',
    recRed: 'COD not recommended; ask customer to prepay',
    reportCountLabel: 'Report count',
    latestReportLabel: 'Latest report',
    phoneLabel: 'Phone',
    customerNameLabel: 'Customer name',
    settings: 'Settings',
    settingsTitle: 'System Settings',
    themeSection: 'Appearance Theme',
    themeSectionDesc: 'Choose your preferred visual theme',
    themeLight: 'Light',
    themeDark: 'Dark',
    languageSection: 'Language',
    languageSectionDesc: 'Select application display language',
    switchToLight: 'Switch to light mode',
    switchToDark: 'Switch to dark mode',
    close: 'Close',
  );

  static AppStrings of(AppLanguage lang) {
    switch (lang) {
      case AppLanguage.th:
        return th;
      case AppLanguage.en:
        return en;
    }
  }
}
