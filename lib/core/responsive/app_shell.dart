import 'dart:ui';
import 'package:flutter/material.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

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
          color: isDark ? const Color(0xE0091220) : const Color(0xEBFFFFFF),
          border: Border(top: BorderSide(color: border, width: 1)),
        ),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _BottomNavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home,
                      label: context.translate('dashboard'),
                      isActive: currentSection == NavSection.dashboard,
                      onTap: () => _navigate(context, ref, NavSection.dashboard),
                    ),
                    _BottomNavItem(
                      icon: Icons.people_outline,
                      activeIcon: Icons.people,
                      label: context.translate('clients'),
                      isActive: currentSection == NavSection.clients,
                      onTap: () => _navigate(context, ref, NavSection.clients),
                    ),
                    _BottomNavItem(
                      icon: Icons.assignment_outlined,
                      activeIcon: Icons.assignment,
                      label: context.translate('orders'),
                      isActive: currentSection == NavSection.orders,
                      onTap: () => _navigate(context, ref, NavSection.orders),
                    ),
                    _BottomNavItem(
                      icon: Icons.analytics_outlined,
                      activeIcon: Icons.analytics,
                      label: context.translate('reports'),
                      isActive: currentSection == NavSection.reports,
                      onTap: () => _navigate(context, ref, NavSection.reports),
                    ),
                    _BottomNavItem(
                      icon: Icons.person_outline,
                      activeIcon: Icons.person,
                      label: context.translate('profile'),
                      isActive: currentSection == NavSection.profile,
                      onTap: () => _navigate(context, ref, NavSection.profile),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
    }
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentCol = isDark ? AppColors.accent : AppColors.accentL;
    final color = isActive ? accentCol : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 66,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            decoration: BoxDecoration(
              color: isActive
                  ? (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.65))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isActive
                  ? Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.06),
                      width: 1,
                    )
                  : Border.all(color: Colors.transparent, width: 1),
              boxShadow: isActive ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ] : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isActive ? activeIcon : icon,
                  size: isActive ? 24 : 21,
                  color: color,
                ),
                const SizedBox(height: 4),
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 8.5,
                    fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                    color: color,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isActive)
            Positioned(
              bottom: 2,
              child: Container(
                width: 16,
                height: 2.5,
                decoration: BoxDecoration(
                  color: accentCol,
                  borderRadius: BorderRadius.circular(1),
                  boxShadow: [
                    BoxShadow(
                      color: accentCol,
                      blurRadius: 4,
                    )
                  ],
                ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentCol = isDark ? AppColors.accent : AppColors.accentL;
    final routeState = GoRouterState.of(context);
    final isTokenCardActive = routeState.uri.path.startsWith('/token-card');

    return Container(
      width: 256,
      decoration: BoxDecoration(
        color: isDark ? AppColors.sidebarDark : AppColors.sidebarLight,
        border: Border(
          right: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [const Color(0xFFC8841A), accentCol],
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Center(
                    child: Text('✂️', style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 11),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Darzi Pro',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      'TAILOR SUITE',
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        color: isDark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF64748B),
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SidebarSection(context.translate('shop_profile')),
                  _SidebarNavItem(
                    emoji: '🏠',
                    label: context.translate('dashboard'),
                    isActive: currentSection == NavSection.dashboard && !isTokenCardActive,
                    onTap: () => _navigate(context, ref, NavSection.dashboard),
                  ),
                  _SidebarNavItem(
                    emoji: '👥',
                    label: context.translate('clients'),
                    isActive: currentSection == NavSection.clients && !isTokenCardActive,
                    badge: '48',
                    badgeGold: true,
                    onTap: () => _navigate(context, ref, NavSection.clients),
                  ),
                  _SidebarNavItem(
                    emoji: '📋',
                    label: context.translate('orders'),
                    isActive: currentSection == NavSection.orders && !isTokenCardActive,
                    badge: '5',
                    onTap: () => _navigate(context, ref, NavSection.orders),
                  ),
                  _SidebarNavItem(
                    emoji: '📏',
                    label: context.translate('measurements'),
                    isActive: currentSection == NavSection.measurements && !isTokenCardActive,
                    onTap: () => _navigate(context, ref, NavSection.measurements),
                  ),
                  _SidebarNavItem(
                    emoji: '🎫',
                    label: 'Token Card',
                    isActive: isTokenCardActive,
                    onTap: () {
                      context.go('/token-card');
                    },
                  ),
                  _SidebarNavItem(
                    emoji: '📈',
                    label: context.translate('reports'),
                    isActive: currentSection == NavSection.reports && !isTokenCardActive,
                    onTap: () => _navigate(context, ref, NavSection.reports),
                  ),

                  // System nav
                  _SidebarSection(context.translate('appearance')),
                  _SidebarNavItem(
                    emoji: '👤',
                    label: context.translate('profile'),
                    isActive: currentSection == NavSection.profile,
                    onTap: () => _navigate(context, ref, NavSection.profile),
                  ),
                  _SidebarNavItem(
                    emoji: '🔔',
                    label: 'Reminders',
                    isActive: false,
                    badge: '3',
                    onTap: () {},
                  ),
                  _SidebarNavItem(
                    emoji: '⚙️',
                    label: context.translate('settings'),
                    isActive: false,
                    onTap: () => context.push('/settings'),
                  ),
                ],
              ),
            ),
          ),

          // User info footer
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
                ),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.accentDark, accentCol],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        'S',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A0F00),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SaifurRahman Tailors',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Owner · Peshawar',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: isDark ? Colors.white.withValues(alpha: 0.35) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
    }
  }
}

class _SidebarSection extends StatelessWidget {
  final String label;
  const _SidebarSection(this.label);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: isDark ? Colors.white.withValues(alpha: 0.25) : const Color(0xFF94A3B8),
        ),
      ),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  final String emoji;
  final String label;
  final bool isActive;
  final String? badge;
  final bool badgeGold;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.emoji,
    required this.label,
    required this.isActive,
    this.badge,
    this.badgeGold = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentCol = isDark ? AppColors.accent : AppColors.accentL;
    final activeBg = isDark ? AppColors.accentS : const Color(0xFFFFF8EE);
    final activeText = isDark ? accentCol : const Color(0xFFD97706);
    final inactiveText = isDark ? Colors.white.withValues(alpha: 0.45) : const Color(0xFF4A5568);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: isActive
                    ? activeBg
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                        color: isActive
                            ? activeText
                            : inactiveText,
                      ),
                    ),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: badgeGold ? accentCol : AppColors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badge!,
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: badgeGold ? const Color(0xFF1A0F00) : Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (isActive)
              Positioned(
                left: 0,
                top: 10,
                bottom: 10,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: accentCol,
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(3)),
                    boxShadow: [
                      BoxShadow(
                        color: accentCol,
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
          ],
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
                    const Divider(height: 1, color: Colors.white12),
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
                                color: Colors.white.withValues(alpha: 0.03),
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
        return Positioned(
          width: 260,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 40),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? AppColors.surfDark : AppColors.surfLight;
    final bg2 = isDark ? AppColors.bg2Dark : AppColors.bg2Light;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final t3 = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

    final reminders = ref.watch(remindersProvider);
    final hasUnread = reminders.any((r) => !r.isRead);

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: surf,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          Text(
            widget.currentSection == NavSection.dashboard
                ? context.translate('dashboard')
                : widget.currentSection == NavSection.clients
                    ? context.translate('clients')
                    : widget.currentSection == NavSection.orders
                        ? context.translate('orders')
                        : widget.currentSection == NavSection.measurements
                            ? context.translate('measurements')
                            : widget.currentSection == NavSection.profile
                                ? context.translate('profile')
                                : context.translate('reports'),
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: t1,
            ),
          ),
          const Spacer(),
          // Search bar
          CompositedTransformTarget(
            link: _layerLink,
            child: Container(
              width: 260,
              height: 36,
              decoration: BoxDecoration(
                color: bg2,
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Text('🔍', style: TextStyle(fontSize: 14, color: t3)),
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
                      style: GoogleFonts.inter(fontSize: 12.5, color: t1),
                      decoration: InputDecoration(
                        hintText: 'Search customer, order, token…',
                        hintStyle: GoogleFonts.inter(fontSize: 12.5, color: t3),
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
          const SizedBox(width: 10),
          // Print button
          _TopBarIconButton(
            emoji: '🖨️',
            onTap: () {
              final selectedOrderId = ref.read(selectedOrderIdProvider);
              if (selectedOrderId != null) {
                context.push('/print/$selectedOrderId');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Pehle ek order select karein! / Please select an order first!',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                    backgroundColor: AppColors.accent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          const SizedBox(width: 8),
          // Notification button
          _TopBarIconButton(
            emoji: '🔔',
            hasNotif: hasUnread,
            onTap: () => _showNotificationsDialog(context, ref),
          ),
          const SizedBox(width: 8),
          // Theme toggle
          _TopBarIconButton(
            emoji: isDark ? '☀️' : '🌙',
            onTap: () {
              ref.read(themeModeProvider.notifier).state =
                  isDark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
          const SizedBox(width: 12),
          // User Avatar showing shop name on hover
          Consumer(
            builder: (context, ref, _) {
              final shopAsync = ref.watch(currentShopProvider);
              final shopName = shopAsync.value?['name'] as String? ?? 'SaifurRahman Tailors';
              final logoUrl = shopAsync.value?['logo_url'] as String?;
              
              return Tooltip(
                message: shopName,
                child: GestureDetector(
                  onTap: () => context.push('/profile'),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.accent,
                    backgroundImage: logoUrl != null && logoUrl.isNotEmpty
                        ? NetworkImage(logoUrl.startsWith('http') || logoUrl.startsWith('assets')
                            ? logoUrl
                            : 'https://ztxrkijwfnegvquoblne.supabase.co/storage/v1/object/public/shop-logos/$logoUrl')
                        : null,
                    child: logoUrl == null || logoUrl.isEmpty
                        ? Text(
                            shopName.isNotEmpty ? shopName[0].toUpperCase() : 'S',
                            style: const TextStyle(
                              color: Color(0xFF1A0F00),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          )
                        : null,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TopBarIconButton extends StatelessWidget {
  final String emoji;
  final bool hasNotif;
  final VoidCallback onTap;

  const _TopBarIconButton({
    required this.emoji,
    this.hasNotif = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg2 = isDark ? AppColors.bg2Dark : AppColors.bg2Light;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bg2,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            Center(child: Text(emoji, style: const TextStyle(fontSize: 15))),
            if (hasNotif)
              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? AppColors.surfDark : AppColors.surfLight,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
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
          color: isDark ? const Color(0xE0060C18) : const Color(0xEBFFFFFF),
          border: Border(
            bottom: BorderSide(color: border, width: 1.2),
          ),
        ),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: CompositedTransformTarget(
                        link: _layerLink,
                        child: Container(
                          height: 38,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfDark : AppColors.surfLight,
                            border: Border.all(color: border),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 12),
                              const Text('🔍', style: TextStyle(fontSize: 14)),
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
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        _controller.clear();
                        _hideOverlay();
                        _focusNode.unfocus();
                        setState(() {
                          _isSearching = false;
                        });
                      },
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.accent : AppColors.accentL,
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

    String subtitle;
    switch (widget.currentSection) {
      case NavSection.dashboard:
        subtitle = 'SaifurRahman Tailors';
        break;
      case NavSection.clients:
        subtitle = 'All Clients';
        break;
      case NavSection.orders:
        subtitle = 'Pipeline';
        break;
      case NavSection.measurements:
        subtitle = 'Size Charts';
        break;
      case NavSection.reports:
        subtitle = 'Analytics';
        break;
      case NavSection.profile:
        subtitle = 'Settings & Profile';
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xE0060C18) : const Color(0xEBFFFFFF),
        border: Border(
          bottom: BorderSide(color: border, width: 1.2),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title and Subtitle
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Darzi Pro',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: t1,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: t3,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),

                  // Action Buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Search Button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isSearching = true;
                          });
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfDark : AppColors.surfLight,
                            border: Border.all(color: border),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text('🔍', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Notifications Button
                      GestureDetector(
                        onTap: () => _showNotificationsDialog(context, ref),
                        child: Stack(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.surfDark : AppColors.surfLight,
                                border: Border.all(color: border),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Text('🔔', style: TextStyle(fontSize: 16)),
                              ),
                            ),
                            if (hasUnread)
                              Positioned(
                                top: 2,
                                right: 2,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: AppColors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark ? AppColors.bgDark : AppColors.bgLight,
                                      width: 1.5,
                                    ),
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
