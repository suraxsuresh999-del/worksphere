import 'package:flutter/material.dart';

/// WorkSphere Color Palette
/// Derived from the WorkSphere mark: vivid blue, cyan, collaboration green,
/// and a small warm-orange highlight on an airy sky-white canvas.
class AppColors {
  AppColors._();

  // ─── Brand Colors ──────────────────────────────────────────────
  static const Color primary = Color(0xFF087FF5);
  static const Color primaryLight = Color(0xFF55C8F5);
  static const Color primaryDark = Color(0xFF0754C8);
  static const Color secondary = Color(0xFF16C7E9);
  static const Color secondaryLight = Color(0xFF9DEBFA);
  static const Color secondaryDark = Color(0xFF008DB5);
  static const Color accent = Color(0xFF66CC35);
  static const Color warmAccent = Color(0xFFFFA21A);

  // ─── Gradient Colors ──────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF0754C8), primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFEAF6FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFFF8FDFF), Color(0xFFE7F7FF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ─── Background Colors ────────────────────────────────────────
  static const Color background = Color(0xFFF9FDFF);
  static const Color backgroundSecondary = Color(0xFFE5F6FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1FAFF);
  static const Color surfaceContainerHighest = Color(0xFFF1FAFF);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color cardBackgroundLight = Color(0xFFE7F7FF);

  // ─── Dark Mode Colors ─────────────────────────────────────────
  static const Color darkBackground = Color(0xFF0B1220);
  static const Color darkSurface = Color(0xFF111C2E);
  static const Color darkSurfaceVariant = Color(0xFF1D2A3D);
  static const Color darkCard = Color(0xFF15243A);
  static const Color darkCardLight = Color(0xFF22334A);

  // ─── Text Colors ──────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0A315B);
  static const Color textSecondary = Color(0xFF51708E);
  static const Color textTertiary = Color(0xFF8AA5BD);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnDark = Color(0xFFE2E8F0);
  static const Color textOnDarkSecondary = Color(0xFF94A3B8);

  // ─── Status Colors ────────────────────────────────────────────
  static const Color success = Color(0xFF63C934);
  static const Color successLight = Color(0xFFE7F9DC);
  static const Color warning = warmAccent;
  static const Color warningLight = Color(0xFFFFF2D9);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // ─── Neutral Colors ───────────────────────────────────────────
  static const Color border = Color(0xFFCBE9F8);
  static const Color borderDark = Color(0xFFCBE9F8);
  static const Color divider = Color(0xFFE4F4FC);
  static const Color disabled = Color(0xFFCBD5E1);
  static const Color shimmerBase = Color(0xFFE2E8F0);
  static const Color shimmerHighlight = Color(0xFFF8FAFC);

  // ─── Verification Badge ───────────────────────────────────────
  static const Color verified = primary;
  static const Color verifiedGold = warmAccent;

  // ─── Rating Colors ────────────────────────────────────────────
  static const Color starFilled = warmAccent;
  static const Color starEmpty = Color(0xFFE2E8F0);

  // ─── Category Colors ──────────────────────────────────────────
  static const List<Color> categoryColors = [
    primary,
    secondary,
    accent,
    warmAccent,
    Color(0xFF2F9BEA),
    Color(0xFF79D544),
    Color(0xFF65D7F0),
    Color(0xFFFFBF4A),
  ];

  // ─── Glass Morphism ───────────────────────────────────────────
  static Color glassWhite = Colors.white.withAlpha(38);
  static Color glassBorder = Colors.white.withAlpha(51);
  static Color glassBackground = Colors.white.withAlpha(20);
  static Color glassDarkBackground = Colors.white.withAlpha(224);
}
