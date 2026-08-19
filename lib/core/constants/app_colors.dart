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

  // LIGHT MODE — Modern SaaS / YT Studio Studio Palette
  static const Color lightBg           = Color(0xFFF8FAFC);  // main app background — crisp studio light-gray (Slate 50)
  static const Color lightSurface      = Color(0xFFFFFFFF);  // cards, modals, sidebar — pure white
  static const Color lightSurface2     = Color(0xFFF1F5F9);  // secondary/nested surfaces, inputs (Slate 100)
  static const Color lightSurfaceHover = Color(0xFFE2E8F0);  // hover/pressed states (Slate 200)

  // Borders — Crisp slate borders (YT Studio style)
  static const Color lightBorder       = Color(0xFFE2E8F0);  // crisp card border stroke (Slate 200)
  static const Color lightBorderSoft   = Color(0xFFF1F5F9);  // subtle divider (Slate 100)
  static const Color lightBorderStrong = Color(0xFFCBD5E1);  // stronger border (Slate 300)

  // Text
  static const Color lightText1        = Color(0xFF0F172A);  // primary text (Slate 900)
  static const Color lightText2        = Color(0xFF475569);  // secondary text (Slate 600)
  static const Color lightText3        = Color(0xFF94A3B8);  // muted text (Slate 400)
  static const Color lightTextOnGold   = Color(0xFF1A0A00);  // text on gold buttons

  // Accents (slightly deeper than dark mode for contrast on white)
  static const Color lightAccent       = Color(0xFFD97706);  // gold/orange primary
  static const Color lightAccentBg     = Color(0xFFFFF7ED);  // gold tint background
  static const Color lightAccentBorder = Color(0xFFFED7AA);  // gold tint border

  static const Color lightTeal         = Color(0xFF0D9488);
  static const Color lightTealBg       = Color(0xFFF0FDFA);
  static const Color lightTealBorder   = Color(0xFF99F6E4);

  static const Color lightRed          = Color(0xFFDC2626);
  static const Color lightRedBg        = Color(0xFFFEF2F2);
  static const Color lightRedBorder    = Color(0xFFFECACA);

  static const Color lightBlue         = Color(0xFF2563EB);
  static const Color lightBlueBg       = Color(0xFFEFF6FF);
  static const Color lightBlueBorder   = Color(0xFFBFDBFE);

  static const Color lightPurple       = Color(0xFF7C3AED);
  static const Color lightPurpleBg     = Color(0xFFF5F3FF);
  static const Color lightPurpleBorder = Color(0xFFDDD6FE);

  // Shadows (light mode needs visible but soft elevation shadows)
  static const Color lightShadow       = Color(0x0A000000);  // 4% soft shadow for elevation

  // Legacy/Compatibility Light Theme Aliases
  static const Color bgLight = lightBg;
  static const Color bg2Light = lightSurface2;
  static const Color surfLight = lightSurface;
  static const Color surf2Light = lightSurface2;
  static const Color surf3Light = lightSurface2;
  static const Color surfSolidLight = lightSurface;
  static const Color sidebarLight = lightSurface;

  // ── BRAND ACCENT (Gold) ──
  static const Color accent = Color(0xFFF5A623);
  static const Color accentDark = Color(0xFFD4791A);
  static const Color accentLight = Color(0xFFFFD080);
  
  // Gold Accent for Light Theme
  static const Color accentL = lightAccent;
  static const Color accentDarkL = lightAccent;
  static const Color accentLightL = lightAccent;

  // Transparency/glow (Dark Theme values by default, can adapt in UI)
  static const Color accentS = Color(0x24F5A623);    // 14%
  static const Color accentSS = Color(0x12F5A623);   // 7%
  static const Color accentGlow = Color(0x59F5A623); // 35%

  // ── STATUS COLORS ──
  static const Color teal = Color(0xFF10CBA0);
  static const Color tealS = Color(0x2410CBA0);
  static const Color tealLight = lightTeal;
  static const Color tealSLight = Color(0x1E059669);

  static const Color red = Color(0xFFFF3A58);
  static const Color redS = Color(0x24FF3A58);
  static const Color redLight = lightRed;
  static const Color redSLight = Color(0x1EDC2626);

  static const Color blue = Color(0xFF5B72F5);
  static const Color blueS = Color(0x245B72F5);
  static const Color blueLight = lightBlue;
  static const Color blueSLight = Color(0x1E4F46E5);

  static const Color purple = Color(0xFF9B5CF5);
  static const Color purpleS = Color(0x249B5CF5);
  static const Color purpleLight = lightPurple;
  static const Color purpleSLight = Color(0x1E7C3AED);

  // ── TEXT ──
  static const Color textPrimaryDark = Color(0xFFEDF4FF);
  static const Color textSecondaryDark = Color(0xFF6880A0);
  static const Color textTertiaryDark = Color(0xFF2E4060);

  static const Color textPrimaryLight = lightText1;
  static const Color textSecondaryLight = lightText2;
  static const Color textTertiaryLight = lightText3;

  // ── BORDERS ──
  static const Color borderDark = Color(0x12FFFFFF);     // rgba(255,255,255,.07) -> 7%
  static const Color border2Dark = Color(0x21FFFFFF);    // rgba(255,255,255,.13) -> 13%
  static const Color borderTopDark = Color(0x2EFFFFFF);  // rgba(255,255,255,.18) -> 18%

  static const Color borderLight = lightBorder;
  static const Color border2Light = lightBorderStrong;
  static const Color borderTopLight = lightBorder;

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
