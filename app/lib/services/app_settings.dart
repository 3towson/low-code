import 'package:flutter/material.dart';

import '../localization/app_strings.dart';

export '../localization/app_strings.dart';

/// คอนโทรลเลอร์สำหรับจัดการ Theme (Light / Dark) และ Language (TH / EN)
class AppSettingsController extends ChangeNotifier {
  AppSettingsController({
    ThemeMode themeMode = ThemeMode.dark,
    AppLanguage language = AppLanguage.th,
    // ignore: prefer_initializing_formals
  }) : _themeMode = themeMode,
       // ignore: prefer_initializing_formals
       _language = language;

  ThemeMode _themeMode;
  AppLanguage _language;

  ThemeMode get themeMode => _themeMode;
  AppLanguage get language => _language;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  AppStrings get strings => AppStrings.of(_language);

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    notifyListeners();
  }

  void setLanguage(AppLanguage lang) {
    if (_language == lang) return;
    _language = lang;
    notifyListeners();
  }

  void toggleLanguage() {
    _language = _language == AppLanguage.th ? AppLanguage.en : AppLanguage.th;
    notifyListeners();
  }
}

/// ขยาย InheritedWidget เพื่อส่งผ่าน AppSettingsController ลงใน Widget Tree
class AppSettingsScope extends InheritedWidget {
  const AppSettingsScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final AppSettingsController controller;

  static AppSettingsController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppSettingsScope>()
        ?.controller;
  }

  static AppSettingsController of(BuildContext context) {
    final c = maybeOf(context);
    assert(c != null, 'No AppSettingsScope found in context');
    return c!;
  }

  /// ดึง AppStrings ตามภาษาปัจจุบัน ถ้าอยู่นอก scope (เช่น unit test) ใช้ภาษาไทยเป็น fallback
  static AppStrings stringsOf(BuildContext context) {
    return maybeOf(context)?.strings ?? AppStrings.th;
  }

  @override
  bool updateShouldNotify(AppSettingsScope oldWidget) =>
      controller != oldWidget.controller;
}

/// Extension บน BuildContext เพื่อเรียกใช้ settings และ strings ได้สะดวก
extension AppSettingsContextX on BuildContext {
  AppSettingsController? get appSettings => AppSettingsScope.maybeOf(this);
  AppStrings get strings => AppSettingsScope.stringsOf(this);
  bool get isDarkMode =>
      appSettings?.isDarkMode ?? (Theme.of(this).brightness == Brightness.dark);
}
