import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/theme_extensions.dart';
import '../providers/admin_providers.dart';

enum DashboardMode {
  shop,
  earn,
  admin,
}

class DashboardSwitcherDropdown extends ConsumerWidget {
  final DashboardMode currentMode;
  final bool compact;
  final VoidCallback? onCustomSwitch;

  const DashboardSwitcherDropdown({
    super.key,
    required this.currentMode,
    this.compact = false,
    this.onCustomSwitch,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAdmin = ref.watch(isUserAdminProvider);
    final text1 = context.text1;
    final text2 = context.text2;

    // Config based on current mode
    Color accentColor;
    Color bgGradient1;
    Color bgGradient2;
    Color chipBg;
    Color chipBorder;
    String modeLabel;
    String modeTag;
    IconData modeIcon;
    String? modeImage;

    switch (currentMode) {
      case DashboardMode.shop:
        accentColor = isDark ? const Color(0xFFF5A623) : const Color(0xFFD97706);
        bgGradient1 = const Color(0xFFD97706);
        bgGradient2 = const Color(0xFFF5A623);
        chipBg = isDark ? const Color(0x14F5A623) : const Color(0xFFFFF8EE);
        chipBorder = isDark ? const Color(0x2EF5A623) : const Color(0x33D97706);
        modeLabel = 'Darzi Pro';
        modeTag = 'SHOP PANEL';
        modeIcon = Icons.content_cut_rounded;
        modeImage = 'assets/logo/app_logo.png';
        break;

      case DashboardMode.earn:
        accentColor = const Color(0xFF10CBA0);
        bgGradient1 = const Color(0xFF10CBA0);
        bgGradient2 = const Color(0xFF059669);
        chipBg = isDark ? const Color(0x1410CBA0) : const Color(0xFFECFDF5);
        chipBorder = isDark ? const Color(0x2E10CBA0) : const Color(0x33059669);
        modeLabel = 'Invite & Earn';
        modeTag = 'AFFILIATE';
        modeIcon = Icons.monetization_on_rounded;
        modeImage = null;
        break;

      case DashboardMode.admin:
        accentColor = const Color(0xFF8B5CF6);
        bgGradient1 = const Color(0xFF8B5CF6);
        bgGradient2 = const Color(0xFF6366F1);
        chipBg = isDark ? const Color(0x148B5CF6) : const Color(0xFFF5F3FF);
        chipBorder = isDark ? const Color(0x2E8B5CF6) : const Color(0x336366F1);
        modeLabel = 'Admin Portal';
        modeTag = 'SUPER ADMIN';
        modeIcon = Icons.admin_panel_settings_rounded;
        modeImage = null;
        break;
    }

    final iconBoxSize = compact ? 24.0 : 28.0;

    return PopupMenuButton<String>(
      tooltip: 'Switch Workspace',
      onSelected: (val) {
        HapticFeedback.lightImpact();
        if (val == 'shop') {
          if (currentMode != DashboardMode.shop) context.go('/dashboard');
        } else if (val == 'earn') {
          if (currentMode != DashboardMode.earn) context.go('/invite-earn');
        } else if (val == 'admin') {
          if (isAdmin && currentMode != DashboardMode.admin) context.go('/admin/dashboard');
        }
      },
      color: isDark ? const Color(0xFF0B1728) : Colors.white,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0x24FFFFFF) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      offset: const Offset(0, 46),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: compact ? 5 : 7,
        ),
        decoration: BoxDecoration(
          color: chipBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: chipBorder, width: 1.1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: iconBoxSize,
              height: iconBoxSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(compact ? 6 : 7),
                gradient: modeImage == null
                    ? LinearGradient(
                        colors: [bgGradient1, bgGradient2],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(compact ? 6 : 7),
                child: modeImage != null
                    ? Image.asset(modeImage, fit: BoxFit.cover, filterQuality: FilterQuality.high)
                    : Center(
                        child: Icon(modeIcon, color: Colors.white, size: compact ? 13 : 15),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  modeLabel,
                  style: GoogleFonts.outfit(
                    fontSize: compact ? 13 : 13.5,
                    fontWeight: FontWeight.w800,
                    color: text1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!compact)
                  Text(
                    modeTag,
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                      letterSpacing: 1.1,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: compact ? 15 : 17,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
      itemBuilder: (ctx) => [
        // Header title inside popup
        PopupMenuItem<String>(
          enabled: false,
          height: 28,
          child: Text(
            'WORKSPACE SWITCHER',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              letterSpacing: 1.2,
            ),
          ),
        ),

        // 1. Darzi Pro (Shop Panel)
        PopupMenuItem<String>(
          value: 'shop',
          child: _buildMenuItem(
            context: ctx,
            title: 'Darzi Pro',
            subtitle: 'Shop orders & measurements',
            icon: Icons.content_cut_rounded,
            imageAsset: 'assets/logo/app_logo.png',
            iconColors: const [Color(0xFFD97706), Color(0xFFF5A623)],
            isActive: currentMode == DashboardMode.shop,
            activeColor: isDark ? const Color(0xFFF5A623) : const Color(0xFFD97706),
            text1: text1,
            text2: text2,
            isDark: isDark,
          ),
        ),

        // 2. Invite & Earn (Affiliate Panel)
        PopupMenuItem<String>(
          value: 'earn',
          child: _buildMenuItem(
            context: ctx,
            title: 'Invite & Earn',
            subtitle: 'Commission & referral network',
            icon: Icons.monetization_on_rounded,
            iconColors: const [Color(0xFF10CBA0), Color(0xFF059669)],
            isActive: currentMode == DashboardMode.earn,
            activeColor: const Color(0xFF10CBA0),
            text1: text1,
            text2: text2,
            isDark: isDark,
          ),
        ),

        // 3. Admin Portal (Super Admins Only)
        if (isAdmin)
          PopupMenuItem<String>(
            value: 'admin',
            child: _buildMenuItem(
              context: ctx,
              title: 'Admin Portal',
              subtitle: 'System management & metrics',
              icon: Icons.admin_panel_settings_rounded,
              iconColors: const [Color(0xFF8B5CF6), Color(0xFF6366F1)],
              isActive: currentMode == DashboardMode.admin,
              activeColor: const Color(0xFF8B5CF6),
              text1: text1,
              text2: text2,
              isDark: isDark,
            ),
          ),
      ],
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    String? imageAsset,
    required List<Color> iconColors,
    required bool isActive,
    required Color activeColor,
    required Color text1,
    required Color text2,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isActive
            ? activeColor.withValues(alpha: isDark ? 0.12 : 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? Border.all(color: activeColor.withValues(alpha: 0.35), width: 1.1)
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: imageAsset == null
                  ? LinearGradient(
                      colors: iconColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageAsset != null
                  ? Image.asset(imageAsset, fit: BoxFit.cover, filterQuality: FilterQuality.high)
                  : Center(
                      child: Icon(icon, color: Colors.white, size: 16),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isActive ? activeColor : text1,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: text2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isActive) ...[
            const SizedBox(width: 6),
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: activeColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
