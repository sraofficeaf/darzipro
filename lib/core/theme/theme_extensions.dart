import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

extension ThemeColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get bg => isDark ? AppColors.bgDark : AppColors.lightBg;
  Color get surface => isDark ? AppColors.surfSolidDark : AppColors.lightSurface;
  Color get surface2 => isDark ? AppColors.bg2Dark : AppColors.lightSurface2;
  Color get border => isDark ? AppColors.borderDark : AppColors.lightBorder;
  Color get text1 => isDark ? AppColors.textPrimaryDark : AppColors.lightText1;
  Color get text2 => isDark ? AppColors.textSecondaryDark : AppColors.lightText2;
  Color get text3 => isDark ? AppColors.textTertiaryDark : AppColors.lightText3;
  Color get accent => isDark ? AppColors.accent : AppColors.lightAccent;
  Color get accentBg => isDark ? AppColors.accentS : AppColors.lightAccentBg;
  Color get surfaceHover => isDark ? const Color(0x0FFFFFFF) : AppColors.lightSurfaceHover;
  Color get shadowColor => isDark
      ? Colors.black.withValues(alpha: 0.4)
      : AppColors.lightShadow;

  List<BoxShadow> get cardShadow => isDark
      ? const []
      : const [
          BoxShadow(
            color: Color(0x06000000), // 2.5% soft shadow
            blurRadius: 12,
            offset: Offset(0, 3),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Color(0x04000000), // 1.5% micro shadow
            blurRadius: 4,
            offset: Offset(0, 1),
            spreadRadius: 0,
          ),
        ];
}
