import 'package:flutter/material.dart';

/// Centralised colour palette for the Digital Mitro app.
/// Matches the purple/violet brand seen across the web CRM and the
/// provided mobile designs.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF6D28D9); // violet-700
  static const Color primaryDark = Color(0xFF5B21B6); // violet-800
  static const Color primaryLight = Color(0xFF9333EA); // purple-600 (gradient end)
  static const Color primaryTint = Color(0xFFEDE9FE); // violet-100 (chips/icons bg)
  static const Color primarySoft = Color(0xFFF5F3FF); // very light lavender bg

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  // Surfaces
  static const Color background = Color(0xFFF9FAFB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE5E7EB);

  // Text
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textFaint = Color(0xFF9CA3AF);

  // Status
  static const Color success = Color(0xFF16A34A);
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerBg = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF2563EB);
  static const Color infoBg = Color(0xFFDBEAFE);
  static const Color neutralBg = Color(0xFFF3F4F6);

  // Online / presence
  static const Color online = Color(0xFF22C55E);
  static const Color offline = Color(0xFF9CA3AF);

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
