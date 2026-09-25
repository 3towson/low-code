import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../theme.dart';

/// กล่องโต้ตอบการตั้งค่า (Settings Dialog)
/// รองรับการเปลี่ยนภาษา (ไทย / อังกฤษ) และการสลับธีม (สว่าง / มืด)
class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.appSettings;
    final strings = context.strings;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colors = theme.colorScheme;
    final app = AppColors.of(context);

    final isDark = settings?.isDarkMode ?? (theme.brightness == Brightness.dark);
    final currentLang = settings?.language ?? AppLanguage.th;

    return Dialog(
      key: const Key('settings-dialog'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: app.border),
      ),
      backgroundColor: app.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.settings_outlined, color: colors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      strings.settingsTitle,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('settings-close'),
                    tooltip: strings.close,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(height: 1),
              const SizedBox(height: 18),

              // ส่วนที่ 1: ธีมการแสดงผล (Theme)
              Row(
                children: [
                  Icon(Icons.palette_outlined, size: 18, color: colors.primary),
                  const SizedBox(width: 8),
                  Text(
                    strings.themeSection,
                    style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                strings.themeSectionDesc,
                style: textTheme.bodySmall?.copyWith(color: app.muted),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _OptionTile(
                      key: const Key('settings-theme-light'),
                      title: strings.themeLight,
                      icon: Icons.light_mode_outlined,
                      selected: !isDark,
                      onTap: () => settings?.setThemeMode(ThemeMode.light),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _OptionTile(
                      key: const Key('settings-theme-dark'),
                      title: strings.themeDark,
                      icon: Icons.dark_mode_outlined,
                      selected: isDark,
                      onTap: () => settings?.setThemeMode(ThemeMode.dark),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // ส่วนที่ 2: ภาษา (Language)
              Row(
                children: [
                  Icon(Icons.translate_rounded, size: 18, color: colors.primary),
                  const SizedBox(width: 8),
                  Text(
                    strings.languageSection,
                    style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                strings.languageSectionDesc,
                style: textTheme.bodySmall?.copyWith(color: app.muted),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _OptionTile(
                      key: const Key('settings-lang-th'),
                      title: 'ไทย',
                      badge: '🇹🇭',
                      selected: currentLang == AppLanguage.th,
                      onTap: () => settings?.setLanguage(AppLanguage.th),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _OptionTile(
                      key: const Key('settings-lang-en'),
                      title: 'English',
                      badge: '🇺🇸',
                      selected: currentLang == AppLanguage.en,
                      onTap: () => settings?.setLanguage(AppLanguage.en),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              FilledButton(
                key: const Key('settings-done'),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(strings.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    super.key,
    required this.title,
    this.icon,
    this.badge,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData? icon;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final app = AppColors.of(context);

    final borderColor = selected ? colors.primary : app.border;
    final bgColor = selected
        ? colors.primary.withOpacity(theme.brightness == Brightness.dark ? 0.2 : 0.08)
        : app.neutralBackground;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 18,
                  color: selected ? colors.primary : app.muted,
                ),
                const SizedBox(width: 8),
              ],
              if (badge != null) ...[
                Text(badge!, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? colors.primary : colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
