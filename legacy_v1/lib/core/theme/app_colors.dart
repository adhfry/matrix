import 'package:flutter/material.dart';

class AppColors {
  // Primary Gradient Colors (Sesuai PDF)
  static const Color emeraldGreen = Color(0xFF059669);
  static const Color roseRed = Color(0xFFE11D48);

  // Primary Colors
  static const Color primary = emeraldGreen;
  static const Color primaryDark = Color(0xFF047857);
  static const Color accent = roseRed;

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [emeraldGreen, roseRed],
  );

  // Top to Bottom Gradient
  static const LinearGradient topToBottomGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [emeraldGreen, roseRed],
  );

  // Bottom to Top Gradient
  static const LinearGradient bottomToTopGradient = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [roseRed, emeraldGreen],
  );

  // Top Left to Bottom Right Gradient
  static const LinearGradient topLeftToBottomRightGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [emeraldGreen, roseRed],
  );

  // Bottom Right to Top Left Gradient
  static const LinearGradient bottomRightToTopLeftGradient = LinearGradient(
    begin: Alignment.bottomRight,
    end: Alignment.topLeft,
    colors: [roseRed, emeraldGreen],
  );

  // Background Colors
  static const Color background = Color(0xFFF3F4F6);
  static const Color cardBackground = Colors.white;
  static const Color darkBackground = Color(0xFF1F2937);
  static const Color surfaceVariant = Color(0xFFF9FAFB);

  // Text Colors
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textLight = Color(0xFF9CA3AF);
  static const Color textWhite = Colors.white;
  static const Color textHint = Color(0xFF9CA3AF);

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Attendance Status Colors
  static const Color onTime = Color(0xFF10B981);
  static const Color late = Color(0xFFF59E0B);
  static const Color absent = Color(0xFFEF4444);
  static const Color holiday = Color(0xFF8B5CF6);

  // Performance Colors
  static const Color performanceExcellent = Color(0xFF10B981);
  static const Color performanceGood = Color(0xFF3B82F6);
  static const Color performanceAverage = Color(0xFFF59E0B);
  static const Color performancePoor = Color(0xFFEF4444);

  // Shift Colors
  static const Color shiftMorning = Color(0xFFF59E0B);
  static const Color shiftAfternoon = Color(0xFF3B82F6);
  static const Color shiftNight = Color(0xFF8B5CF6);
  static const Color shiftOff = Color(0xFF6B7280);

  // Border Colors
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF3F4F6);
  static const Color divider = Color(0xFFE5E7EB);

  // Shadow Colors
  static Color shadow = Colors.black.withValues(alpha: 0.05);
  static Color shadowMedium = Colors.black.withValues(alpha: 0.1);
  static Color shadowDark = Colors.black.withValues(alpha: 0.2);

  // Glassmorphism
  static Color glassMorphism = Colors.white.withValues(alpha: 0.8);
  static Color glassMorphismDark = Colors.black.withValues(alpha: 0.2);
}
