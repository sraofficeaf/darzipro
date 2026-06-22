import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── DARK THEME ──
  static const Color bgDark = Color(0xFF060C18);
  static const Color bg2Dark = Color(0xFF091220);
  static const Color surfDark = Color(0x09FFFFFF);   // rgba(255,255,255,0.035) -> 0x09
  static const Color surf2Dark = Color(0x0FFFFFFF);  // rgba(255,255,255,0.06)  -> 0x0F
  static const Color surf3Dark = Color(0x17FFFFFF);  // rgba(255,255,255,0.09)  -> 0x17
  static const Color surfSolidDark = Color(0xFF0E1A2E);
  static const Color sidebarDark = Color(0xFF04080E);

  // ── LIGHT THEME ──
  static const Color bgLight = Color(0xFFF3F5FA);
  static const Color bg2Light = Color(0xFFE8ECF4);
  static const Color surfLight = Color(0xFFFFFFFF);
  static const Color surf2Light = Color(0xFFFAFBFE);
  static const Color surf3Light = Color(0xFFF0F3F9);
  static const Color surfSolidLight = Color(0xFFFFFFFF);
  static const Color sidebarLight = Color(0xFFFFFFFF);

  // ── BRAND ACCENT (Gold) ──
  static const Color accent = Color(0xFFF5A623);
  static const Color accentDark = Color(0xFFD4791A);
  static const Color accentLight = Color(0xFFFFD080);
  
  // Gold Accent for Light Theme
  static const Color accentL = Color(0xFFD97706);
  static const Color accentDarkL = Color(0xFFB45309);
  static const Color accentLightL = Color(0xFFF59E0B);

  // Transparency/glow (Dark Theme values by default, can adapt in UI)
  static const Color accentS = Color(0x24F5A623);    // 14%
  static const Color accentSS = Color(0x12F5A623);   // 7%
  static const Color accentGlow = Color(0x59F5A623); // 35%

  // ── STATUS COLORS ──
  static const Color teal = Color(0xFF10CBA0);
  static const Color tealS = Color(0x2410CBA0);
  static const Color tealLight = Color(0xFF059669);
  static const Color tealSLight = Color(0x1E059669);

  static const Color red = Color(0xFFFF3A58);
  static const Color redS = Color(0x24FF3A58);
  static const Color redLight = Color(0xFFDC2626);
  static const Color redSLight = Color(0x1EDC2626);

  static const Color blue = Color(0xFF5B72F5);
  static const Color blueS = Color(0x245B72F5);
  static const Color blueLight = Color(0xFF4F46E5);
  static const Color blueSLight = Color(0x1E4F46E5);

  static const Color purple = Color(0xFF9B5CF5);
  static const Color purpleS = Color(0x249B5CF5);
  static const Color purpleLight = Color(0xFF7C3AED);
  static const Color purpleSLight = Color(0x1E7C3AED);

  // ── TEXT ──
  static const Color textPrimaryDark = Color(0xFFEDF4FF);
  static const Color textSecondaryDark = Color(0xFF6880A0);
  static const Color textTertiaryDark = Color(0xFF2E4060);

  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textTertiaryLight = Color(0xFF94A3B8);

  // ── BORDERS ──
  static const Color borderDark = Color(0x12FFFFFF);     // rgba(255,255,255,.07) -> 7%
  static const Color border2Dark = Color(0x21FFFFFF);    // rgba(255,255,255,.13) -> 13%
  static const Color borderTopDark = Color(0x2EFFFFFF);  // rgba(255,255,255,.18) -> 18%

  static const Color borderLight = Color(0x0D0F172A);    // 5% Slate
  static const Color border2Light = Color(0x170F172A);   // 9% Slate
  static const Color borderTopLight = Color(0x240F172A); // 14% Slate

  // ── ORDER STATUS (UI Helpers) ──
  static const Color statusPending = accent;
  static const Color statusCutting = purple;
  static const Color statusStitching = blue;
  static const Color statusReady = teal;
  static const Color statusDelivered = Color(0xFF6880A0);
  static const Color statusCancelled = red;

  // ── AVATAR GRADIENTS ──
  static const List<Color> avatarBlue = [Color(0xFF5B72F5), Color(0xFF3B4ED8)];
  static const List<Color> avatarPink = [Color(0xFFEC4899), Color(0xFFBE185D)];
  static const List<Color> avatarGreen = [Color(0xFF10B981), Color(0xFF065F46)];
  static const List<Color> avatarAmber = [Color(0xFFD97706), Color(0xFFF5A623)];
  static const List<Color> avatarPurple = [Color(0xFFA855F7), Color(0xFF7C3AED)];
  static const List<Color> avatarBrand = [Color(0xFFC8841A), Color(0xFFF5A623)];
}
