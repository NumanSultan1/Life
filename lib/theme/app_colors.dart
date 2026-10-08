import 'package:flutter/material.dart';

class AppColors {
  // Liquid palette (sampled from the reference design)
  static const Color royal = Color(0xFF0B4DBF);
  static const Color navy = Color(0xFF051F82);
  static const Color sky = Color(0xFF4FA6E6);
  static const Color pink = Color(0xFFEFA3D7);
  static const Color lavender = Color(0xFFB9A4E6);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color ink = Color(0xFF0B1B4D);

  // Brand / Theme roles
  static const Color primary = royal;
  static const Color secondary = violet;
  static const Color accent = Color(0xFFE07BC0);
  static const Color success = Color(0xFF2BB8A3);
  static const Color warning = Color(0xFFF5A35C);
  static const Color danger = Color(0xFFE5577A);

  // Light Theme Backgrounds & Neutral Colors
  static const Color background = Color(0xFFF4F5FC);
  static const Color cardBg = Colors.white;
  static const Color fieldBg = Color(0xFFF1F3FB);
  static const Color textPrimary = ink;
  static const Color textSecondary = Color(0xFF6B7398);
  static const Color border = Color(0xFFE3E6F5);

  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF070B24);
  static const Color darkCardBg = Color(0xFF121A3F);
  static const Color darkTextPrimary = Color(0xFFEEF1FF);
  static const Color darkTextSecondary = Color(0xFF9AA3CC);
  static const Color darkBorder = Color(0xFF232C5C);

  /// Royal blue reads poorly on the dark navy background; use sky there.
  static Color accentOn(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? sky : royal;

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFE6A8DA), Color(0xFF4F7FE0), royal],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient navGradient = LinearGradient(
    colors: [Color(0xFF1252C8), navy],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient ringCenterGradient = LinearGradient(
    colors: [Color(0xFFF7D9EE), Color(0xFFCFE3FA), Color(0xFFB9C8F2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
