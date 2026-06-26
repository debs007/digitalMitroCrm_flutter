import 'package:flutter/material.dart';

/// Centralised colour palette for the Digital Mitro app.
///
/// Every colour below is a GETTER, not a const — it checks [isDark] and
/// returns the right light/dark variant. This means every existing call
/// site across the app (`AppColors.primary`, `AppColors.background`, etc.)
/// keeps working completely unchanged; only the values resolve
/// dynamically. [ThemeProvider] flips [isDark] and calls notifyListeners,
/// and main.dart wraps the app in a Consumer<ThemeProvider> so the entire
/// tree rebuilds and re-evaluates every getter fresh when the mode flips.
class AppColors {
  AppColors._();

  static bool isDark = false;

  // Brand
  static Color get primary => isDark ? const Color(0xFF9061F0) : const Color(0xFF6D28D9);

  /// Dedicated colour for every loading spinner/pull-to-refresh indicator
  /// in the app — kept separate from [primary] so it can be themed
  /// independently of the purple brand colour.
  static const Color loader = Color(0xFFF97316); // orange-500 — same in both modes
  static Color get primaryDark => isDark ? const Color(0xFF7C3AED) : const Color(0xFF5B21B6);
  static Color get primaryLight => isDark ? const Color(0xFFC084FC) : const Color(0xFF9333EA);
  static Color get primaryTint => isDark ? const Color(0xFF2E1F5E) : const Color(0xFFEDE9FE);
  static Color get primarySoft => isDark ? const Color(0xFF1F1B33) : const Color(0xFFF5F3FF);

  static LinearGradient get primaryGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primary, primaryLight],
      );

  // Surfaces
  static Color get background => isDark ? const Color(0xFF121214) : const Color(0xFFF9FAFB);
  static Color get surface => isDark ? const Color(0xFF1C1C1F) : const Color(0xFFFFFFFF);
  static Color get divider => isDark ? const Color(0xFF2D2D31) : const Color(0xFFE5E7EB);

  // Text
  static Color get textPrimary => isDark ? const Color(0xFFF3F4F6) : const Color(0xFF111827);
  static Color get textSecondary => isDark ? const Color(0xFFA1A1AA) : const Color(0xFF6B7280);
  static Color get textFaint => isDark ? const Color(0xFF71717A) : const Color(0xFF9CA3AF);

  // Status
  static Color get success => isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
  static Color get successBg => isDark ? const Color(0xFF14291B) : const Color(0xFFDCFCE7);
  static Color get warning => isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B);
  static Color get warningBg => isDark ? const Color(0xFF332A12) : const Color(0xFFFEF3C7);
  static Color get danger => isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
  static Color get dangerBg => isDark ? const Color(0xFF351717) : const Color(0xFFFEE2E2);
  static Color get info => isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
  static Color get infoBg => isDark ? const Color(0xFF132238) : const Color(0xFFDBEAFE);
  static Color get neutralBg => isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6);

  // Online / presence
  static const Color online = Color(0xFF22C55E);

  //static Color loaderTint;
  static Color get offline => isDark ? const Color(0xFF71717A) : const Color(0xFF9CA3AF);

  // Priority colours (Tasks)
  static Color priorityColor(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'urgent':
        return danger;
      case 'high':
        return danger;
      case 'medium':
        return warning;
      case 'low':
        return info;
      default:
        return textFaint;
    }
  }

  static Color priorityBg(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'urgent':
        return dangerBg;
      case 'high':
        return dangerBg;
      case 'medium':
        return warningBg;
      case 'low':
        return infoBg;
      default:
        return neutralBg;
    }
  }

  // Attendance status colours
  static Color attendanceColor(String? status) {
    switch (status) {
      case 'On Time':
      case 'Full Day':
        return success;
      case 'Late':
      case 'Half Day':
        return warning;
      case 'Absent':
        return danger;
      case 'Leave':
        return info;
      case 'Week-Off':
      case 'Weekend':
      case 'Holiday':
        return textFaint;
      default:
        return textSecondary;
    }
  }

  static Color attendanceBg(String? status) {
    switch (status) {
      case 'On Time':
      case 'Full Day':
        return successBg;
      case 'Late':
      case 'Half Day':
        return warningBg;
      case 'Absent':
        return dangerBg;
      case 'Leave':
        return infoBg;
      case 'Week-Off':
      case 'Weekend':
      case 'Holiday':
        return neutralBg;
      default:
        return neutralBg;
    }
  }
}
