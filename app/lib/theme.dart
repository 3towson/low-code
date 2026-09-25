import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ระยะและขนาดที่ใช้ร่วมกันทุกหน้า
abstract final class AppSpacing {
  static const double maxContentWidth = 680;
  static const double pageHorizontal = 20;
  static const double section = 24;
  static const EdgeInsets page = EdgeInsets.symmetric(
    horizontal: pageHorizontal,
    vertical: section,
  );
  static const double controlHeight = 52;
  static const double cardRadius = 16;
  static const double controlRadius = 12;
}

/// สีสถานะที่ ColorScheme ไม่มี เช่น สีของระดับความเสี่ยง
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.border,
    required this.muted,
    required this.card,
    required this.success,
    required this.successBackground,
    required this.warning,
    required this.warningBackground,
    required this.danger,
    required this.dangerBackground,
    required this.neutralBackground,
  });

  final Color border;
  final Color muted;
  final Color card;
  final Color success;
  final Color successBackground;
  final Color warning;
  final Color warningBackground;
  final Color danger;
  final Color dangerBackground;
  final Color neutralBackground;

  static const light = AppColors(
    border: Color(0xFFE2E8F0),
    muted: Color(0xFF6B7280),
    card: Color(0xFFFFFFFF),
    success: Color(0xFF16A34A),
    successBackground: Color(0xFFF0FDF4),
    warning: Color(0xFFD97706),
    warningBackground: Color(0xFFFFFBEB),
    danger: Color(0xFFDC2626),
    dangerBackground: Color(0xFFFEF2F2),
    neutralBackground: Color(0xFFF3F4F6),
  );

  static const dark = AppColors(
    border: Color(0xFF22304A),
    muted: Color(0xFF94A3B8),
    card: Color(0xFF131D31),
    success: Color(0xFF10B981),
    successBackground: Color(0xFF042B1F),
    warning: Color(0xFFF59E0B),
    warningBackground: Color(0xFF281802),
    danger: Color(0xFFEF4444),
    dangerBackground: Color(0xFF2E090F),
    neutralBackground: Color(0xFF16233B),
  );

  /// ถ้า theme ไม่มี extension นี้ (เช่นในเทสต์) ใช้ค่า light
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? light;

  @override
  AppColors copyWith({
    Color? border,
    Color? muted,
    Color? card,
    Color? success,
    Color? successBackground,
    Color? warning,
    Color? warningBackground,
    Color? danger,
    Color? dangerBackground,
    Color? neutralBackground,
  }) {
    return AppColors(
      border: border ?? this.border,
      muted: muted ?? this.muted,
      card: card ?? this.card,
      success: success ?? this.success,
      successBackground: successBackground ?? this.successBackground,
      warning: warning ?? this.warning,
      warningBackground: warningBackground ?? this.warningBackground,
      danger: danger ?? this.danger,
      dangerBackground: dangerBackground ?? this.dangerBackground,
      neutralBackground: neutralBackground ?? this.neutralBackground,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      border: Color.lerp(border, other.border, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      card: Color.lerp(card, other.card, t)!,
      success: Color.lerp(success, other.success, t)!,
      successBackground: Color.lerp(
        successBackground,
        other.successBackground,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningBackground: Color.lerp(
        warningBackground,
        other.warningBackground,
        t,
      )!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerBackground: Color.lerp(
        dangerBackground,
        other.dangerBackground,
        t,
      )!,
      neutralBackground: Color.lerp(
        neutralBackground,
        other.neutralBackground,
        t,
      )!,
    );
  }
}

abstract final class AppTheme {
  static const _onPrimary = Color(0xFFFFFFFF);

  static ThemeData light() => _build(
    brightness: Brightness.light,
    app: AppColors.light,
    primary: const Color(0xFF1A56DB),
    surface: const Color(0xFFF8FAFF),
    onSurface: const Color(0xFF1C1F26),
  );

  /// primary สว่างขึ้นเพื่อให้มองเห็นบนพื้นเข้ม
  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    app: AppColors.dark,
    primary: const Color(0xFF3B82F6),
    surface: const Color(0xFF0F172A),
    onSurface: const Color(0xFFF1F5F9),
  );

  static ThemeData _build({
    required Brightness brightness,
    required AppColors app,
    required Color primary,
    required Color surface,
    required Color onSurface,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: brightness,
        ).copyWith(
          primary: primary,
          onPrimary: _onPrimary,
          surface: surface,
          onSurface: onSurface,
          onSurfaceVariant: app.muted,
          surfaceContainerLowest: app.card,
          surfaceTint: Colors.transparent,
          outline: app.border,
          outlineVariant: app.border,
          error: app.danger,
          onError: _onPrimary,
          // SnackBar ใช้ inverseSurface: บนพื้นเข้มให้เป็นพื้นสว่าง ตัวอักษรเข้ม
          inverseSurface: isDark ? onSurface : null,
          onInverseSurface: isDark ? surface : _onPrimary,
        );

    final base = ThemeData(useMaterial3: true, colorScheme: colorScheme);
    final textTheme = _textTheme(base.textTheme, onSurface);

    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.controlRadius),
    );
    const controlSize = Size.fromHeight(AppSpacing.controlHeight);
    final buttonText = textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );

    OutlineInputBorder inputBorder(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.controlRadius),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return base.copyWith(
      scaffoldBackgroundColor: surface,
      textTheme: textTheme,
      extensions: [app],
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: onSurface),
      ),
      cardTheme: CardThemeData(
        color: app.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: BorderSide(color: app.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: _onPrimary,
          minimumSize: controlSize,
          shape: controlShape,
          textStyle: buttonText,
          elevation: isDark ? 2 : 0,
          shadowColor: isDark ? primary.withOpacity(0.35) : Colors.transparent,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: controlSize,
          shape: controlShape,
          textStyle: buttonText,
          side: BorderSide(
            color: isDark ? primary.withOpacity(0.7) : primary,
            width: 1.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: buttonText,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: app.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(color: app.muted),
        helperStyle: textTheme.bodySmall?.copyWith(color: app.muted),
        border: inputBorder(app.border),
        enabledBorder: inputBorder(app.border),
        disabledBorder: inputBorder(app.border),
        focusedBorder: inputBorder(primary, 2),
        errorBorder: inputBorder(app.danger),
        focusedErrorBorder: inputBorder(app.danger, 2),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        contentTextStyle: textTheme.bodyLarge?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
        shape: controlShape,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: app.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: app.neutralBackground,
        side: BorderSide(color: app.border),
        labelStyle: textTheme.labelMedium?.copyWith(color: app.muted),
        shape: const StadiumBorder(),
      ),
      dividerTheme: DividerThemeData(color: app.border, thickness: 1),
    );
  }

  /// Sarabun: 400 เนื้อหา, 600 label, 700 หัวข้อ
  static TextTheme _textTheme(TextTheme base, Color onSurface) {
    final t = GoogleFonts.sarabunTextTheme(base);
    TextStyle? w(TextStyle? s, FontWeight weight) =>
        s?.copyWith(fontWeight: weight);
    return t
        .copyWith(
          displayLarge: w(t.displayLarge, FontWeight.w700),
          displayMedium: w(t.displayMedium, FontWeight.w700),
          displaySmall: w(t.displaySmall, FontWeight.w700),
          headlineLarge: w(t.headlineLarge, FontWeight.w700),
          headlineMedium: w(t.headlineMedium, FontWeight.w700),
          headlineSmall: w(t.headlineSmall, FontWeight.w700),
          titleLarge: w(t.titleLarge, FontWeight.w700),
          titleMedium: w(t.titleMedium, FontWeight.w600),
          titleSmall: w(t.titleSmall, FontWeight.w600),
          labelLarge: w(t.labelLarge, FontWeight.w600),
          labelMedium: w(t.labelMedium, FontWeight.w600),
          labelSmall: w(t.labelSmall, FontWeight.w600),
          bodyLarge: w(t.bodyLarge, FontWeight.w400),
          bodyMedium: w(t.bodyMedium, FontWeight.w400),
          bodySmall: w(t.bodySmall, FontWeight.w400),
        )
        .apply(bodyColor: onSurface, displayColor: onSurface);
  }
}
