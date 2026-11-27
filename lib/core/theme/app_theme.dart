import 'package:flutter/material.dart';

/// تم یکپارچه (روشن/تاریک) با فونت وزیرمتن. رنگ‌های معنایی برای مبالغ و وضعیت‌ها.
class AppTheme {
  AppTheme._();
  static const String font = 'Vazirmatn';
  static const Color seed = Color(0xFF2F5FD0);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final cs = ColorScheme.fromSeed(seedColor: seed, brightness: b);
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      fontFamily: font,
      scaffoldBackgroundColor: b == Brightness.light
          ? const Color(0xFFF5F7FB)
          : const Color(0xFF0F1219),
      visualDensity: VisualDensity.standard,
    );
  }
}

/// رنگ‌های معنایی مستقل از تم
class AppColors {
  AppColors._();
  static Color positive(BuildContext c) =>
      Theme.of(c).brightness == Brightness.light
      ? const Color(0xFF1B8F5A)
      : const Color(0xFF4CD48F);
  static Color negative(BuildContext c) =>
      Theme.of(c).brightness == Brightness.light
      ? const Color(0xFFD1305E)
      : const Color(0xFFFF7A9D);
  static Color warning(BuildContext c) =>
      Theme.of(c).brightness == Brightness.light
      ? const Color(0xFFC77700)
      : const Color(0xFFFFB347);
  static Color card(BuildContext c) =>
      Theme.of(c).brightness == Brightness.light
      ? Colors.white
      : const Color(0xFF181C27);
  static Color line(BuildContext c) =>
      Theme.of(c).brightness == Brightness.light
      ? const Color(0xFFE4E7EF)
      : const Color(0xFF272D3D);
  static Color muted(BuildContext c) =>
      Theme.of(c).colorScheme.onSurface.withAlpha(150);
}
