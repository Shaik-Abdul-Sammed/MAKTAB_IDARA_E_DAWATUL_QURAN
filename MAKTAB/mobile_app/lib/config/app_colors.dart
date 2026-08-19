import 'package:flutter/material.dart';

class AppColors {
  // Core Brand Colors
  static const Color primaryTeal = Color(0xFF004D40);
  static const Color primaryDarkTeal = Color(0xFF00251A);
  static const Color primaryLightTeal = Color(0xFF39796B);
  
  static const Color goldAccent = Color(0xFFFFD700);
  static const Color goldGradientStart = Color(0xFFFFE57F);
  static const Color goldGradientEnd = Color(0xFFFFC107);
  
  static const Color creamBackground = Color(0xFFF9FBE7);
  
  // Non-white rich surfaces
  static const Color cardSurface = Color(0xFFE8F5E9); // Soft emerald mint surface
  static const Color statSurface = Color(0xFFFFF8E1); // Soft amber gold surface
  static const Color cardBorderTeal = Color(0xFFA5D6A7); // Soft teal border

  // Semantic Colors
  static const Color success = Color(0xFF2E7D32);
  static const Color error = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFED6C02);
  static const Color info = Color(0xFF0288D1);
  static const Color whatsappGreen = Color(0xFF25D366);

  // Text Colors
  static const Color textPrimary = Color(0xFF004D40);
  static const Color textDark = Color(0xFF121212);
  static const Color textSecondary = Color(0xFF39796B);
  static const Color textMuted = Color(0xFF5D4037);

  // Dark Mode Variant Palette
  static const Color darkBackground = Color(0xFF121E1B);
  static const Color darkCardSurface = Color(0xFF00382E);
  static const Color darkTextPrimary = Color(0xFFE0E0E0);
  static const Color darkTextSecondary = Color(0xFFB0BEC5);

  // Gradient Presets
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryTeal, primaryDarkTeal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [goldGradientStart, goldGradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
