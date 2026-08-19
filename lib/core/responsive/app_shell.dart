import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../constants/app_enums.dart';
import '../constants/app_translations.dart';
import 'responsive.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/providers/license_provider.dart';
import '../../shared/providers/supabase_providers.dart';
import '../../shared/providers/reminders_provider.dart';
import '../../core/services/license/license_model.dart';
import '../config/supabase_config.dart';
import '../widgets/shared_widgets.dart';
import '../theme/theme_extensions.dart';
import '../../shared/widgets/dashboard_switcher.dart';

class AppShell extends ConsumerWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = Responsive.isDesktop(context);
    final currentSection = ref.watch(navSectionProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDesktop) {
      return _DesktopShell(
        currentSection: currentSection,
        isDark: isDark,
        child: child,
      );
    } else {
      return _MobileShell(
        currentSection: currentSection,
        isDark: isDark,
        child: child,
      );
    }
  }
}

// ── DESKTOP SHELL ──────────────────────────────────────────────────────
class _DesktopShell extends ConsumerWidget {
  final NavSection currentSection;
  final bool isDark;
  final Widget child;

  const _DesktopShell({
    required this.currentSection,
    required this.isDark,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(currentSection: currentSection),
          Expanded(
            child: Column(
              children: [
                _TopBar(currentSection: currentSection),
                Consumer(builder: (context, ref, _) {
                  final license = ref.watch(licenseProvider);
                  if (license.isExpiringSoon) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: AppColors.accentS,
                      child: Row(children: [
                        const Text('⚠️'),
                        const SizedBox(width: 8),
                        Text(
                          'Pro plan expires in ${license.daysRemaining} days.',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.accent),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => context.push('/upgrade'),
                          child: Text('Renew →', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.accent)),
                        ),
                      ]),
                    );
                  }
                  return const SizedBox.shrink();
                }),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── MOBILE SHELL ───────────────────────────────────────────────────────
class _MobileShell extends ConsumerWidget {
  final NavSection currentSection;
  final bool isDark;
  final Widget child;

  const _MobileShell({
    required this.currentSection,
    required this.isDark,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    return Scaffold(
      body: Column(
        children: [
          _MobileTopBar(currentSection: currentSection),
          Consumer(builder: (context, ref, _) {
            final license = ref.watch(licenseProvider);
            if (license.isExpiringSoon) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: AppColors.accentS,
                child: Row(children: [
                  const Text('⚠️'),
                  const SizedBox(width: 8),
                  Text(
                    'Pro plan expires in ${license.daysRemaining} days.',
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.accent),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.push('/upgrade'),
                    child: Text('Renew →', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.accent)),
                  ),
                ]),
              );
            }
            return const SizedBox.shrink();
          }),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.surface,
          border: Border(
            top: BorderSide(
              color: context.border, 
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Consumer(
              builder: (context, ref, _) {
                final orders = ref.watch(ordersProvider).valueOrNull ?? [];
                final activeOrdersCount = orders.where((o) => o.status != OrderStatus.delivered && o.status != OrderStatus.cancelled).length;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _BottomNavItem(
                      icon: Icons.home_rounded,
                      label: 'Home',
                      isActive: currentSection == NavSection.dashboard,
                      onTap: () => _navigate(context, ref, NavSection.dashboard),
                    ),
                    _BottomNavItem(
                      icon: Icons.people_rounded,
                      label: 'Clients',
                      isActive: currentSection == NavSection.clients,
                      onTap: () => _navigate(context, ref, NavSection.clients),
                    ),
                    _BottomNavItem(
                      icon: Icons.receipt_long_rounded,
                      label: 'Orders',
                      isActive: currentSection == NavSection.orders,
                      onTap: () => _navigate(context, ref, NavSection.orders),
                      badgeCount: activeOrdersCount,
                    ),
                    _BottomNavItem(
                      icon: Icons.straighten_rounded,
                      label: 'Naap',
                      isActive: currentSection == NavSection.measurements,
                      onTap: () => _navigate(context, ref, NavSection.measurements),
                    ),
                    _BottomNavItem(
                      icon: Icons.person_rounded,
                      label: 'Profile',
                      isActive: currentSection == NavSection.profile,
                      onTap: () => _navigate(context, ref, NavSection.profile),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final int badgeCount;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = context.accent;
    final inactiveColor = context.text3;
    final activeBgColor = context.accentBg;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
            decoration: BoxDecoration(
              color: isActive ? activeBgColor : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isActive ? activeColor : inactiveColor,
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3A58),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Center(
                        child: Text(
                          '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              color: isActive ? activeColor : inactiveColor,
            ),
          ),
        ],
      ),
    );
  }
}
// ── SIDEBAR ────────────────────────────────────────────────────────────
class _Sidebar extends ConsumerWidget {
  final NavSection currentSection;

  const _Sidebar({required this.currentSection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeState = GoRouterState.of(context);
    final isTokenCardActive = routeState.uri.path.startsWith('/token-card');

    final customers = ref.watch(customersProvider).valueOrNull ?? [];
    final orders = ref.watch(ordersProvider).valueOrNull ?? [];
    final activeOrdersCount = orders.where((o) => o.status != OrderStatus.delivered && o.status != OrderStatus.cancelled).length;

    final reminders = ref.watch(remindersProvider);
    final unreadRemindersCount = reminders.where((r) => !r.isRead).length;

    final license = ref.watch(licenseProvider);

    final shopAsync = ref.watch(currentShopProvider);
    final shopName = shopAsync.value?['name'] as String? ?? 'SaifurRahman Tailors';
    final logoUrl = shopAsync.value?['logo_url'] as String?;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 240,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0A1428), Color(0xFF08101E)],
              )
            : null,
        color: isDark ? null : AppColors.lightSurface,
        border: Border(
          right: BorderSide(
            color: context.border,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: context.border,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: logoUrl != null && logoUrl.isNotEmpty
                        ? Image.network(
                            logoUrl.startsWith('http') || logoUrl.startsWith('assets')
                                ? logoUrl
                                : '${SupabaseConfig.shopLogosUrl}/$logoUrl',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Image.asset(
                              'assets/logo/app_logo.png',
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.high,
                            ),
                          )
                        : Image.asset(
                            'assets/logo/app_logo.png',
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
                          ),
                  ),
                ),
                const SizedBox(width: 11),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Darzi Pro',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: context.text1,
                      ),
                    ),
                    Text(
                      'TAILOR SUITE',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: context.text3,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Scrollable nav items
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel(context, 'SHOP PROFILE'),
                  _NavItem(
                    icon: Icons.dashboard_rounded,
                    label: context.translate('dashboard'),
                    isActive: currentSection == NavSection.dashboard && !isTokenCardActive,
                    onTap: () => _navigate(context, ref, NavSection.dashboard),
                  ),
                  _NavItem(
                    icon: Icons.people_rounded,
                    label: context.translate('clients'),
                    isActive: currentSection == NavSection.clients && !isTokenCardActive,
                    badgeText: customers.length.toString(),
                    badgeType: 'gold',
                    onTap: () => _navigate(context, ref, NavSection.clients),
                  ),
                  _NavItem(
                    icon: Icons.receipt_long_rounded,
                    label: context.translate('orders'),
                    isActive: currentSection == NavSection.orders && !isTokenCardActive,
                    badgeText: activeOrdersCount.toString(),
                    badgeType: 'red',
                    onTap: () => _navigate(context, ref, NavSection.orders),
                  ),
                  _NavItem(
                    icon: Icons.straighten_rounded,
                    label: context.translate('measurements'),
                    isActive: currentSection == NavSection.measurements && !isTokenCardActive,
                    onTap: () => _navigate(context, ref, NavSection.measurements),
                  ),
                  _NavItem(
                    icon: Icons.badge_rounded,
                    label: 'Token Card',
                    isActive: isTokenCardActive,
                    onTap: () {
                      context.go('/token-card');
                    },
                  ),
                  _NavItem(
                    icon: Icons.bar_chart_rounded,
                    label: context.translate('reports'),
                    isActive: currentSection == NavSection.reports && !isTokenCardActive,
                    onTap: () => _navigate(context, ref, NavSection.reports),
                  ),

                  _buildSectionLabel(context, 'APPEARANCE'),
                  _NavItem(
                    icon: Icons.person_rounded,
                    label: context.translate('profile'),
                    isActive: currentSection == NavSection.profile,
                    onTap: () => _navigate(context, ref, NavSection.profile),
                  ),
                  _NavItem(
                    icon: Icons.notifications_rounded,
                    label: 'Reminders',
                    isActive: currentSection == NavSection.reminders,
                    badgeText: unreadRemindersCount.toString(),
                    badgeType: 'red',
                    onTap: () => _navigate(context, ref, NavSection.reminders),
                  ),
                ],
              ),
            ),
          ),

          // Bottom section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0x0DFFFFFF) : const Color(0x1A000000),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPlanCard(context, license),
                const SizedBox(height: 8),
                _buildShopUserRow(context, shopName),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(top: 14, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFF2A3E58) : const Color(0xFF94A3B8),
          letterSpacing: 1.8,
        ),
      ),
    );
  }

  Widget _buildPlanCard(BuildContext context, LicenseModel license) {
    final isPro = license.isPro || license.isBusiness;
    final daysRemaining = license.daysRemaining;
    final expiryDate = license.expiresAt;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x0FF5A623) : AppColors.lightAccentBg,
        border: Border.all(
          color: isDark ? const Color(0x26F5A623) : AppColors.lightAccentBorder, 
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPro) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x1A10CBA0) : const Color(0xFFECFDF5),
                    border: Border.all(color: isDark ? const Color(0x3310CBA0) : const Color(0xFF059669).withValues(alpha: 0.3), width: 1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    '✓ PRO PLAN',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF10CBA0) : const Color(0xFF059669),
                    ),
                  ),
                ),
                Text(
                  '$daysRemaining Days Left',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: isDark ? const Color(0xFF5A7090) : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Progress bar
            Container(
              height: 3,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0x0FFFFFFF) : const Color(0x1A000000),
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (daysRemaining / 30).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF5A623), Color(0xFFD97706)],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (expiryDate != null)
              RichText(
                text: TextSpan(
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: isDark ? const Color(0xFF3D5470) : const Color(0xFF94A3B8),
                  ),
                  children: [
                    const TextSpan(text: 'Renew before '),
                    TextSpan(
                      text: '${expiryDate.day}/${expiryDate.month}/${expiryDate.year}',
                      style: TextStyle(
                        color: isDark ? const Color(0xFFF5A623) : const Color(0xFFD97706),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x1AF5A623) : const Color(0xFFFFF8EE),
                    border: Border.all(color: isDark ? const Color(0x33F5A623) : const Color(0xFFD97706).withValues(alpha: 0.3), width: 1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    'FREE PLAN',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFF5A623) : const Color(0xFFD97706),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push('/upgrade'),
                  child: Text(
                    'Upgrade →',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFF5A623) : const Color(0xFFD97706),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShopUserRow(BuildContext context, String shopName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? const [Color(0xFFD97706), Color(0xFFF5A623)]
                  : const [Color(0xFFD97706), Color(0xFFD97706)],
            ),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Center(
            child: Text(
              getInitials(shopName),
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF1A0A00) : const Color(0xFFFFFFFF),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                shopName,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF8AA0B8) : context.text2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Owner · Peshawar',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  color: isDark ? const Color(0xFF3D5470) : context.text3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: Color(0xFF10CBA0),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x8010CBA0),
                blurRadius: 6,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String getInitials(String name) {
  final parts = name.trim().split(' ');
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return name.isNotEmpty ? name[0].toUpperCase() : '?';
}

void _navigate(BuildContext context, WidgetRef ref, NavSection section) {
  ref.read(navSectionProvider.notifier).state = section;
  switch (section) {
    case NavSection.dashboard:
      context.go('/dashboard');
      break;
    case NavSection.clients:
      context.go('/customers');
      break;
    case NavSection.orders:
      context.go('/orders');
      break;
    case NavSection.measurements:
      context.go('/measurements');
      break;
    case NavSection.reports:
      context.go('/reports');
      break;
    case NavSection.profile:
      context.go('/profile');
      break;
    case NavSection.reminders:
      context.go('/reminders');
      break;
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final String? badgeText;
  final String? badgeType;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    this.badgeText,
    this.badgeType,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeBg = isDark ? const Color(0x1AF5A623) : AppColors.lightAccentBg;
    final activeBorder = isDark ? const Color(0x26F5A623) : AppColors.lightAccentBorder;
    final activeIconColor = isDark ? const Color(0xFFF5A623) : AppColors.lightAccent;
    final activeLabelColor = isDark ? const Color(0xFFF5A623) : AppColors.lightAccent;

    final inactiveBg = _isHovered 
        ? (isDark ? const Color(0x08FFFFFF) : AppColors.lightSurfaceHover) 
        : Colors.transparent;
    final inactiveBorder = Colors.transparent;
    final inactiveIconColor = isDark ? const Color(0xFF5A7090) : context.text2;
    final inactiveLabelColor = isDark
        ? (_isHovered ? const Color(0xFF8AA0B8) : const Color(0xFF5A7090))
        : context.text2;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: widget.isActive ? activeBg : inactiveBg,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: widget.isActive ? activeBorder : inactiveBorder,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: widget.isActive 
                            ? (isDark ? const Color(0x26F5A623) : AppColors.lightAccentBg) 
                            : (isDark ? const Color(0x0AFFFFFF) : AppColors.lightSurface2),
                        border: widget.isActive 
                            ? Border.all(color: isDark ? const Color(0x33F5A623) : AppColors.lightAccentBorder, width: 1)
                            : null,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Center(
                        child: Icon(
                          widget.icon,
                          size: 18,
                          color: widget.isActive ? activeIconColor : inactiveIconColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: widget.isActive ? activeLabelColor : inactiveLabelColor,
                        ),
                      ),
                    ),
                    if (widget.badgeText != null && widget.badgeText!.isNotEmpty && widget.badgeText != '0')
                      _buildBadge(widget.badgeText!, widget.badgeType),
                  ],
                ),
              ),
              if (widget.isActive)
                Positioned(
                  left: 0,
                  top: 6,
                  bottom: 6,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? const [Color(0xFFF5A623), Color(0xFFD97706)]
                            : const [Color(0xFFD97706), Color(0xFFD97706)],
                      ),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(2),
                        bottomRight: Radius.circular(2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, String? type) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color bg;
    Color color;
    Color border;

    if (type == 'gold') {
      bg = isDark ? const Color(0x1AF5A623) : const Color(0xFFFFF8EE);
      color = isDark ? const Color(0xFFF5A623) : const Color(0xFFD97706);
      border = isDark ? const Color(0x33F5A623) : const Color(0xFFD97706).withValues(alpha: 0.3);
    } else if (type == 'red') {
      bg = isDark ? const Color(0x1AFF3A58) : const Color(0xFFFEF2F2);
      color = isDark ? const Color(0xFFFF3A58) : const Color(0xFFDC2626);
      border = isDark ? const Color(0x33FF3A58) : const Color(0xFFDC2626).withValues(alpha: 0.3);
    } else {
      bg = isDark ? const Color(0x1A10CBA0) : const Color(0xFFECFDF5);
      color = isDark ? const Color(0xFF10CBA0) : const Color(0xFF059669);
      border = isDark ? const Color(0x3310CBA0) : const Color(0xFF059669).withValues(alpha: 0.3);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ── NOTIFICATIONS DIALOG ────────────────────────────────────────────────
void _showNotificationsDialog(BuildContext context, WidgetRef ref) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final surf = isDark ? AppColors.surfDark : AppColors.surfLight;
  final border = isDark ? AppColors.borderDark : AppColors.borderLight;
  final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
  final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Notifications',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, anim1, anim2) {
      return Align(
        alignment: Alignment.topRight,
        child: Container(
          margin: const EdgeInsets.only(top: 65, right: 24),
          width: 320,
          constraints: const BoxConstraints(maxHeight: 450),
          decoration: BoxDecoration(
            color: surf.withValues(alpha: 0.95),
            border: Border.all(color: border, width: 1.5),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 15,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Consumer(
              builder: (context, ref, child) {
                final reminders = ref.watch(remindersProvider);
                final unreadReminders = reminders.where((r) => !r.isRead).toList();

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Reminders / Alerts 🔔',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accent,
                            ),
                          ),
                          if (unreadReminders.isNotEmpty)
                            GestureDetector(
                              onTap: () => ref.read(remindersProvider.notifier).clearAll(),
                              child: Text(
                                'Clear All',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.red,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: border),
                    if (unreadReminders.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('✨', style: TextStyle(fontSize: 24)),
                              const SizedBox(height: 8),
                              Text(
                                'No new reminders!',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: t2,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: unreadReminders.length,
                          itemBuilder: (context, idx) {
                            final rem = unreadReminders[idx];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.03) : context.surface2,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: border),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                title: Row(
                                  children: [
                                    Text(
                                      rem.tokenNumber,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        rem.customerName,
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: t1,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    rem.message,
                                    style: GoogleFonts.inter(fontSize: 11, color: t2, height: 1.3),
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Text('✕', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  onPressed: () {
                                    ref.read(remindersProvider.notifier).markAsRead(rem.id);
                                  },
                                ),
                                onTap: () {
                                  ref.read(remindersProvider.notifier).markAsRead(rem.id);
                                  Navigator.pop(context);
                                  context.push('/orders/${rem.orderId}');
                                },
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, anim1, anim2, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.05, -0.05),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
        child: FadeTransition(
          opacity: anim1,
          child: child,
        ),
      );
    },
  );
}

// ── DESKTOP TOP BAR ────────────────────────────────────────────────────
class SearchResultItem {
  final String title;
  final String subtitle;
  final String type; // 'Client' or 'Order'
  final String route;
  final String emoji;

  SearchResultItem({
    required this.title,
    required this.subtitle,
    required this.type,
    required this.route,
    required this.emoji,
  });
}

// ── DESKTOP TOP BAR ────────────────────────────────────────────────────
class _TopBar extends ConsumerStatefulWidget {
  final NavSection currentSection;

  const _TopBar({required this.currentSection});

  @override
  ConsumerState<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends ConsumerState<_TopBar> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
    if (_focusNode.hasFocus) {
      if (_controller.text.isNotEmpty) {
        _showOverlay();
      }
    } else {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _hideOverlay();
      });
    }
  }

  void _showOverlay() {
    _hideOverlay();
    if (!mounted) return;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          width: 280,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 42),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.surfDark
                  : AppColors.surfLight,
              child: _buildSearchResultsList(),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hideOverlay();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Widget _buildSearchResultsList() {
    final query = _controller.text.trim().toLowerCase();
    if (query.isEmpty) {
      return const SizedBox.shrink();
    }

    final customers = ref.watch(customersProvider).valueOrNull ?? [];
    final orders = ref.watch(ordersProvider).valueOrNull ?? [];

    final matchingCustomers = customers.where((c) {
      return c.name.toLowerCase().contains(query) || c.phone.contains(query);
    }).toList();

    final matchingOrders = orders.where((o) {
      return o.tokenNumber.toLowerCase().contains(query) ||
          o.customerName.toLowerCase().contains(query);
    }).toList();

    final results = [
      ...matchingCustomers.map((c) => SearchResultItem(
            title: c.name,
            subtitle: c.phone,
            type: 'Client',
            route: '/customers/${c.id}',
            emoji: '👤',
          )),
      ...matchingOrders.map((o) => SearchResultItem(
            title: o.tokenNumber,
            subtitle: '${o.customerName} · ${o.itemsSummary}',
            type: 'Order',
            route: '/orders/${o.id}',
            emoji: '📋',
          )),
    ];

    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Text(
          'No results found',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        border: Border.all(color: border, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: results.length,
        itemBuilder: (context, index) {
          final item = results[index];
          return ListTile(
            dense: true,
            leading: Text(item.emoji, style: const TextStyle(fontSize: 16)),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: t1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: item.type == 'Client'
                        ? AppColors.tealS
                        : AppColors.accentS,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.type.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: item.type == 'Client'
                          ? AppColors.teal
                          : AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              item.subtitle,
              style: GoogleFonts.inter(fontSize: 11, color: t2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              _controller.clear();
              _hideOverlay();
              _focusNode.unfocus();
              context.push(item.route);
            },
          );
        },
      ),
    );
  }

  Widget _buildTopBarIconButton({
    required IconData icon,
    required VoidCallback onTap,
    bool hasBadge = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: context.surface2,
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              icon,
              color: context.text2,
              size: 18,
            ),
            if (hasBadge)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF3A58),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reminders = ref.watch(remindersProvider);
    final hasUnread = reminders.any((r) => !r.isRead);
    final shopAsync = ref.watch(currentShopProvider);
    final shopName = shopAsync.value?['name'] as String? ?? 'SaifurRahman Tailors';

    String titleText = '';
    switch (widget.currentSection) {
      case NavSection.dashboard:
        titleText = context.translate('dashboard');
        break;
      case NavSection.clients:
        titleText = context.translate('clients');
        break;
      case NavSection.orders:
        titleText = context.translate('orders');
        break;
      case NavSection.measurements:
        titleText = context.translate('measurements');
        break;
      case NavSection.reports:
        titleText = context.translate('reports');
        break;
      case NavSection.profile:
        titleText = context.translate('profile');
        break;
      case NavSection.reminders:
        titleText = 'Reminders';
        break;
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: context.surface.withValues(alpha: 0.8),
            border: Border(
              bottom: BorderSide(
                color: context.border,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                titleText,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.text1,
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: CompositedTransformTarget(
                  link: _layerLink,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 280),
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isFocused 
                          ? context.accentBg
                          : context.surface2,
                      border: Border.all(
                        color: _isFocused 
                            ? context.accent 
                            : context.border,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: context.text3,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            onChanged: (val) {
                              if (val.isNotEmpty) {
                                _showOverlay();
                              } else {
                                _hideOverlay();
                              }
                            },
                            style: GoogleFonts.inter(
                              fontSize: 12, 
                              color: context.text1,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search...',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 12, 
                                color: context.text3,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Row(

                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Green Dollar Earn Button ──
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.go('/invite-earn');
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0x1A10CBA0) : const Color(0xFFECFDF5),
                        border: Border.all(
                          color: isDark ? const Color(0x3310CBA0) : const Color(0x4010CBA0),
                          width: 1.1,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.monetization_on_rounded,
                          size: 19,
                          color: Color(0xFF10CBA0),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _buildTopBarIconButton(
                    icon: Icons.print_rounded,
                    onTap: () {
                      final selectedOrderId = ref.read(selectedOrderIdProvider);
                      if (selectedOrderId != null) {
                        context.push('/print/$selectedOrderId');
                      } else {
                        showAppSnackBar(
                          context: context,
                          message: 'Pehle ek order select karein! / Please select an order first!',
                          isError: true,
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  _buildTopBarIconButton(
                    icon: Icons.notifications_rounded,
                    hasBadge: hasUnread,
                    onTap: () => _showNotificationsDialog(context, ref),
                  ),
                  const SizedBox(width: 4),
                  _buildTopBarIconButton(
                    icon: Icons.settings_rounded,
                    onTap: () => context.push('/profile'),
                  ),
                  const SizedBox(width: 10),
                  // ── Unified Dashboard Switcher ────────────────
                  const DashboardSwitcherDropdown(
                    currentMode: DashboardMode.shop,
                    compact: false,
                  ),

                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => context.push('/profile'),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFD97706), Color(0xFFF5A623)],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          getInitials(shopName),
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A0A00),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── MOBILE TOP BAR ─────────────────────────────────────────────────────
class _MobileTopBar extends ConsumerStatefulWidget {
  final NavSection currentSection;

  const _MobileTopBar({required this.currentSection});

  @override
  ConsumerState<_MobileTopBar> createState() => _MobileTopBarState();
}

class _MobileTopBarState extends ConsumerState<_MobileTopBar> {
  bool _isSearching = false;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      if (_controller.text.isNotEmpty) {
        _showOverlay();
      }
    } else {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _hideOverlay();
      });
    }
  }

  void _showOverlay() {
    _hideOverlay();
    if (!mounted) return;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final screenWidth = MediaQuery.sizeOf(context).width;
        return Positioned(
          width: screenWidth - 40, // Match search container padding
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 42),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.surfDark
                  : AppColors.surfLight,
              child: _buildSearchResultsList(),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hideOverlay();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Widget _buildSearchResultsList() {
    final query = _controller.text.trim().toLowerCase();
    if (query.isEmpty) {
      return const SizedBox.shrink();
    }

    final customers = ref.watch(customersProvider).valueOrNull ?? [];
    final orders = ref.watch(ordersProvider).valueOrNull ?? [];

    final matchingCustomers = customers.where((c) {
      return c.name.toLowerCase().contains(query) || c.phone.contains(query);
    }).toList();

    final matchingOrders = orders.where((o) {
      return o.tokenNumber.toLowerCase().contains(query) ||
          o.customerName.toLowerCase().contains(query);
    }).toList();

    final results = [
      ...matchingCustomers.map((c) => SearchResultItem(
            title: c.name,
            subtitle: c.phone,
            type: 'Client',
            route: '/customers/${c.id}',
            emoji: '👤',
          )),
      ...matchingOrders.map((o) => SearchResultItem(
            title: o.tokenNumber,
            subtitle: '${o.customerName} · ${o.itemsSummary}',
            type: 'Order',
            route: '/orders/${o.id}',
            emoji: '📋',
          )),
    ];

    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Text(
          'No results found',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      constraints: const BoxConstraints(maxHeight: 250),
      decoration: BoxDecoration(
        border: Border.all(color: border, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: results.length,
        itemBuilder: (context, index) {
          final item = results[index];
          return ListTile(
            dense: true,
            leading: Text(item.emoji, style: const TextStyle(fontSize: 16)),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: t1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: item.type == 'Client'
                        ? AppColors.tealS
                        : AppColors.accentS,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.type.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: item.type == 'Client'
                          ? AppColors.teal
                          : AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              item.subtitle,
              style: GoogleFonts.inter(fontSize: 11, color: t2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              _controller.clear();
              _hideOverlay();
              _focusNode.unfocus();
              setState(() {
                _isSearching = false;
              });
              context.push(item.route);
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final t3 = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    final reminders = ref.watch(remindersProvider);
    final hasUnread = reminders.any((r) => !r.isRead);

    if (_isSearching) {
      return Container(
        decoration: BoxDecoration(
          color: context.surface.withValues(alpha: 0.94),
          border: Border(
            bottom: BorderSide(color: border, width: 1.0),
          ),
        ),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: CompositedTransformTarget(
                        link: _layerLink,
                        child: Container(
                          height: 38,
                          decoration: BoxDecoration(
                            color: context.surface2,
                            border: Border.all(color: border),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 10),
                              Icon(Icons.search_rounded, size: 17, color: context.text2),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  autofocus: true,
                                  onChanged: (val) {
                                    if (val.isNotEmpty) {
                                      _showOverlay();
                                    } else {
                                      _hideOverlay();
                                    }
                                  },
                                  style: GoogleFonts.inter(fontSize: 13.5, color: t1),
                                  decoration: InputDecoration(
                                    hintText: 'Search client or order...',
                                    hintStyle: GoogleFonts.inter(fontSize: 13.5, color: t3),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        _controller.clear();
                        _hideOverlay();
                        _focusNode.unfocus();
                        setState(() {
                          _isSearching = false;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: context.accent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }


    final profile = ref.watch(profileProvider);
    final shop = ref.watch(currentShopProvider).value;
    final ownerName = (shop?['owner_name'] as String?)?.trim().isNotEmpty == true
        ? shop!['owner_name'] as String
        : (profile.value?['full_name'] as String? ?? 'Saifur Rahman');

    return Container(
      decoration: BoxDecoration(
        color: context.surface.withValues(alpha: 0.94),
        border: Border(
          bottom: BorderSide(color: border, width: 1.0),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ── Left: Official Logo + Title + Owner Name Subtitle ──
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            'assets/logo/app_logo.png',
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Darzi Pro',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: t1,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            ownerName,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: context.accent,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),

                  // ── Right: Action Buttons Row ──
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Green Dollar Earn Dashboard Button ──
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.go('/invite-earn');
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0x1A10CBA0) : const Color(0xFFECFDF5),
                            border: Border.all(
                              color: isDark ? const Color(0x3310CBA0) : const Color(0x4010CBA0),
                              width: 1.1,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10CBA0).withValues(alpha: isDark ? 0.15 : 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.monetization_on_rounded,
                              size: 19,
                              color: Color(0xFF10CBA0),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),

                      // Search Button (Professional Squircle)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isSearching = true;
                          });
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: context.surface2,
                            border: Border.all(color: border),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.search_rounded,
                              size: 18,
                              color: context.text2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),

                      // Notifications Button with Pulsing Badge
                      GestureDetector(
                        onTap: () => _showNotificationsDialog(context, ref),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: context.surface2,
                                border: Border.all(color: border),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Icon(
                                  hasUnread
                                      ? Icons.notifications_active_rounded
                                      : Icons.notifications_outlined,
                                  size: 18,
                                  color: hasUnread
                                      ? const Color(0xFFF5A623)
                                      : context.text2,
                                ),
                              ),
                            ),
                            if (hasUnread)
                              Positioned(
                                top: -2,
                                right: -2,
                                child: Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF3A58),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: context.surface,
                                      width: 1.5,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x66FF3A58),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
