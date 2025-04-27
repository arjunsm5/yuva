import 'package:flutter/material.dart';

// 🎨 AppTheme class to manage light and dark theme colors
class AppTheme {
  // 📋 Light theme colors
  static const Color primaryLight = Color(0xFF6750A4); // Violet
  static const Color secondaryLight = Color(0xFF03DAC6); // Mint
  static const Color backgroundLight = Color(0xFFFFFFFF); // White
  static const Color surfaceLight = Color(0xFFF6F6F6); // Light Gray
  static const Color textPrimaryLight = Color(0xFF1A1A1A); // Almost Black
  static const Color textSecondaryLight = Color(0xFF4A4A4A); // Dark Gray
  static const Color successLight = Color(0xFF00C853); // Emerald
  static const Color errorLight = Color(0xFFFF5252); // Coral Red
  static const Color accentLight = Color(0xFFFF8A80); // Peach Pink

  // 📋 Dark theme colors
  static const Color primaryDark = Color(0xFFD0BCFF); // Lilac
  static const Color secondaryDark = Color(0xFF66FFF9); // Bright Mint
  static const Color backgroundDark = Color(0xFF121212); // Charcoal
  static const Color surfaceDark = Color(0xFF1E1E1E); // Dark Gray
  static const Color textPrimaryDark = Color(0xFFEAEAEA); // Soft White
  static const Color textSecondaryDark = Color(0xFFB3B3B3); // Gray
  static const Color successDark = Color(0xFF00E676); // Neon Green
  static const Color errorDark = Color(0xFFFF6E6E); // Rosy Red
  static const Color accentDark = Color(0xFFFF80AB); // Pink Lavender

  // 📅 Check if the current theme is dark
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  // 🎨 Getters for colors based on the current theme
  static Color getPrimary(BuildContext context) =>
      isDark(context) ? primaryDark : primaryLight;

  static Color getSecondary(BuildContext context) =>
      isDark(context) ? secondaryDark : secondaryLight;

  static Color getBackground(BuildContext context) =>
      isDark(context) ? backgroundDark : backgroundLight;

  static Color getSurface(BuildContext context) =>
      isDark(context) ? surfaceDark : surfaceLight;

  static Color getTextPrimary(BuildContext context) =>
      isDark(context) ? textPrimaryDark : textPrimaryLight;

  static Color getTextSecondary(BuildContext context) =>
      isDark(context) ? textSecondaryDark : textSecondaryLight;

  static Color getSuccess(BuildContext context) =>
      isDark(context) ? successDark : successLight;

  static Color getError(BuildContext context) =>
      isDark(context) ? errorDark : errorLight;

  static Color getAccent(BuildContext context) =>
      isDark(context) ? accentDark : accentLight;
}