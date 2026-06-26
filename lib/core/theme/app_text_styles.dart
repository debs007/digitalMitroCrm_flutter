import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Centralised text styles. Uses the platform default font family
/// (no external font download) for offline reliability.
class AppText {
  AppText._();

  static const String _family = 'Roboto';

  static TextStyle get h1 => TextStyle(
    fontFamily: _family,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static TextStyle get h2 => TextStyle(
    fontFamily: _family,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle get h3 => TextStyle(
    fontFamily: _family,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodyLarge => TextStyle(
    fontFamily: _family,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static TextStyle get body => TextStyle(
    fontFamily: _family,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodyMuted => TextStyle(
    fontFamily: _family,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static TextStyle get caption => TextStyle(
    fontFamily: _family,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static TextStyle get captionBold => TextStyle(
    fontFamily: _family,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
  );

  static TextStyle get button => TextStyle(
    fontFamily: _family,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  static TextStyle get label => TextStyle(
    fontFamily: _family,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
}
