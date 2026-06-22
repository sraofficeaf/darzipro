import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark => _buildTheme(isDark: true);
  static ThemeData get light => _buildTheme(isDark: false);

  static ThemeData _buildTheme({required bool isDark}) {
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final surf = isDark ? AppColors.surfDark : AppColors.surfLight;
    final surf2 = isDark ? AppColors.surf2Dark : AppColors.surf2Light;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final t2 =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    final textTheme = GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.outfit(
        color: t1,
        fontSize: 34,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.outfit(
        color: t1,
        fontSize: 28,
        fontWeight: FontWeight.w900,
      ),
      displaySmall: GoogleFonts.outfit(
        color: t1,
        fontSize: 22,
        fontWeight: FontWeight.w900,
      ),
      headlineLarge: GoogleFonts.outfit(
        color: t1,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
      headlineMedium: GoogleFonts.outfit(
        color: t1,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
      headlineSmall: GoogleFonts.outfit(
        color: t1,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: GoogleFonts.outfit(
        color: t1,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: GoogleFonts.inter(
        color: t1,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: GoogleFonts.inter(
        color: t2,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: GoogleFonts.inter(color: t1, fontSize: 14),
      bodyMedium: GoogleFonts.inter(color: t2, fontSize: 13),
      bodySmall: GoogleFonts.inter(color: t2, fontSize: 12),
      labelLarge: GoogleFonts.inter(
        color: t1,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: GoogleFonts.inter(
        color: t2,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
      labelSmall: GoogleFonts.inter(
        color: t2,
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: isDark ? AppColors.accent : AppColors.accentL,
        onPrimary: const Color(0xFF1A0F00),
        secondary: isDark ? AppColors.teal : AppColors.tealLight,
        onSecondary: Colors.white,
        error: isDark ? AppColors.red : AppColors.redLight,
        onError: Colors.white,
        surface: surf,
        onSurface: t1,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: surf,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.outfit(
          color: t1,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: IconThemeData(color: t2),
      ),
      cardTheme: CardThemeData(
        color: surf,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border, width: 1),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surf2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? AppColors.accent : AppColors.accentL, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: GoogleFonts.inter(color: t2, fontSize: 13.5),
        labelStyle: GoogleFonts.inter(
          color: t2,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? AppColors.accent : AppColors.accentL,
          foregroundColor: const Color(0xFF1A0F00),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t2,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isDark ? AppColors.sidebarDark : AppColors.sidebarLight,
        selectedIconTheme:
            IconThemeData(color: isDark ? AppColors.accent : AppColors.accentL, size: 20),
        unselectedIconTheme: IconThemeData(
          color: isDark
              ? Colors.white.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.6),
          size: 20,
        ),
        selectedLabelTextStyle: GoogleFonts.inter(
          color: isDark ? AppColors.accent : AppColors.accentL,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: GoogleFonts.inter(
          color: isDark
              ? Colors.white.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.6),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        indicatorColor: AppColors.accentS,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surf,
        selectedItemColor: isDark ? AppColors.accent : AppColors.accentL,
        unselectedItemColor: t2,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.inter(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surf,
        selectedColor: AppColors.accentS,
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
        side: BorderSide(color: border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

// Mono text style for numbers, tokens, phone numbers
TextStyle monoStyle({
  Color? color,
  double fontSize = 13,
  FontWeight fontWeight = FontWeight.w700,
}) {
  return GoogleFonts.jetBrainsMono(
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
  );
}
