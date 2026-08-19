import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../shared/providers/admin_providers.dart';
import '../../shared/widgets/dashboard_switcher.dart';

// ── Nav items definition ───────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final IconData iconActive;
  final String label;
  final String route;
  const _NavItem({
    required this.icon,
    required this.iconActive,
    required this.label,
    required this.route,
  });
}

const _navItems = [
  _NavItem(icon: Icons.dashboard_outlined, iconActive: Icons.dashboard_rounded, label: 'Dashboard', route: '/admin/dashboard'),
  _NavItem(icon: Icons.verified_outlined, iconActive: Icons.verified_rounded, label: 'Approvals', route: '/admin/approvals'),
  _NavItem(icon: Icons.storefront_outlined, iconActive: Icons.storefront_rounded, label: 'Shops', route: '/admin/shops'),
  _NavItem(icon: Icons.monetization_on_outlined, iconActive: Icons.monetization_on_rounded, label: 'Revenue', route: '/admin/revenue'),
  _NavItem(icon: Icons.handshake_outlined, iconActive: Icons.handshake_rounded, label: 'Invites & Payouts', route: '/admin/invites'),
  _NavItem(icon: Icons.notifications_outlined, iconActive: Icons.notifications_rounded, label: 'Notifications', route: '/admin/notifications'),
  _NavItem(icon: Icons.system_update_outlined, iconActive: Icons.system_update_rounded, label: 'App Versions', route: '/admin/versions'),
  _NavItem(icon: Icons.assessment_outlined, iconActive: Icons.assessment_rounded, label: 'Reports', route: '/admin/reports'),
  _NavItem(icon: Icons.menu_book_outlined, iconActive: Icons.menu_book_rounded, label: 'Help & Reference', route: '/admin/support'),
  _NavItem(icon: Icons.settings_outlined, iconActive: Icons.settings_rounded, label: 'Settings', route: '/admin/settings'),
];


// ── Admin Shell ────────────────────────────────────────────────────────────
class AdminShell extends ConsumerWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isUserAdminProvider);

    if (!isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          showAppSnackBar(
            context: context,
            message: 'Access Denied: Admin privileges required.',
            isError: true,
          );
          context.go('/dashboard');
        }
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFF5A623)),
        ),
      );
    }

    final location = GoRouterState.of(context).matchedLocation;
    final isWide = MediaQuery.of(context).size.width >= 720;

    if (isWide) {
      return _DesktopAdminShell(location: location, ref: ref, child: child);
    } else {
      return _MobileAdminShell(location: location, ref: ref, child: child);
    }
  }
}

// ── Desktop Layout (sidebar) ───────────────────────────────────────────────
class _DesktopAdminShell extends StatelessWidget {
  final String location;
  final WidgetRef ref;
  final Widget child;
  const _DesktopAdminShell({required this.location, required this.ref, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sidebarBg = isDark ? const Color(0xFF0B1525) : Colors.white;
    final sidebarBorder = isDark ? const Color(0x12FFFFFF) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: context.bg,
      body: Row(
        children: [
          // ── Sidebar ──────────────────────────────────────────────────
          Container(
            width: 220,
            decoration: BoxDecoration(
              color: sidebarBg,
              border: Border(right: BorderSide(color: sidebarBorder)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SidebarHeader(),
                Divider(height: 1, color: sidebarBorder),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: _navItems.map((item) => _SidebarItem(
                      icon: item.icon,
                      iconActive: item.iconActive,
                      label: item.label,
                      isActive: location == item.route,
                      onTap: () => context.go(item.route),
                    )).toList(),
                  ),
                ),
                Divider(height: 1, color: sidebarBorder),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: _SidebarItem(
                    icon: Icons.store_outlined,
                    iconActive: Icons.store_rounded,
                    label: 'Exit to Shop',
                    isActive: false,
                    isExit: true,
                    onTap: () {
                      context.go('/dashboard');
                    },
                  ),
                ),
              ],
            ),
          ),
          // ── Main Content ─────────────────────────────────────────────
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ── Mobile Layout ──────────────────────────────────────────────────────────
class _MobileAdminShell extends StatelessWidget {
  final String location;
  final WidgetRef ref;
  final Widget child;
  const _MobileAdminShell({required this.location, required this.ref, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? const Color(0xFF0B1525) : Colors.white;
    final navBorder = isDark ? const Color(0x12FFFFFF) : const Color(0xFFE2E8F0);

    // Primary 4 tabs for bottom bar
    final primaryTabs = [
      _navItems[0], // Dashboard
      _navItems[1], // Approvals
      _navItems[2], // Shops
      _navItems[4], // Invites & Payouts
    ];

    final activeIndex = primaryTabs.indexWhere((item) => item.route == location);

    return Scaffold(
      backgroundColor: context.bg,
      appBar: _MobileAdminAppBar(ref: ref),
      drawer: _AdminDrawer(location: location, ref: ref),
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBg,
          border: Border(top: BorderSide(color: navBorder)),
          boxShadow: isDark
              ? []
              : [const BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, -2))],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 58,
            child: Row(
              children: [
                ...primaryTabs.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  final isActive = idx == activeIndex;
                  final activeColor = isDark ? const Color(0xFFF5A623) : const Color(0xFFD97706);
                  final inactiveColor = isDark ? const Color(0xFF4A6080) : const Color(0xFF94A3B8);

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => context.go(item.route),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? (isDark ? const Color(0x1FF5A623) : const Color(0xFFFFF8EE))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              isActive ? item.iconActive : item.icon,
                              size: 20,
                              color: isActive ? activeColor : inactiveColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.label,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                              color: isActive ? activeColor : inactiveColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                // More item to open drawer
                Expanded(
                  child: Builder(
                    builder: (ctx) => GestureDetector(
                      onTap: () => Scaffold.of(ctx).openDrawer(),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.menu_rounded,
                            size: 20,
                            color: isDark ? const Color(0xFF4A6080) : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'More',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w400,
                              color: isDark ? const Color(0xFF4A6080) : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Admin Drawer for Mobile ─────────────────────────────────────────────────
class _AdminDrawer extends StatelessWidget {
  final String location;
  final WidgetRef ref;
  const _AdminDrawer({required this.location, required this.ref});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0B1525) : Colors.white;
    final border = isDark ? const Color(0x12FFFFFF) : const Color(0xFFE2E8F0);

    return Drawer(
      backgroundColor: bg,
      child: SafeArea(
        child: Column(
          children: [
            _SidebarHeader(),
            Divider(height: 1, color: border),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: _navItems.map((item) => _SidebarItem(
                  icon: item.icon,
                  iconActive: item.iconActive,
                  label: item.label,
                  isActive: location == item.route,
                  onTap: () {
                    Navigator.pop(context);
                    context.go(item.route);
                  },
                )).toList(),
              ),
            ),
            Divider(height: 1, color: border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: _SidebarItem(
                icon: Icons.store_outlined,
                iconActive: Icons.store_rounded,
                label: 'Exit to Shop',
                isActive: false,
                isExit: true,
                onTap: () {
                  Navigator.pop(context);
                  context.go('/dashboard');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mobile AppBar with Switcher ─────────────────────────────────────────────
class _MobileAdminAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final WidgetRef ref;
  const _MobileAdminAppBar({required this.ref});

  @override
  Size get preferredSize => const Size.fromHeight(54);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? const Color(0xFF0B1525) : Colors.white;
    final navBorder = isDark ? const Color(0x12FFFFFF) : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: navBg.withValues(alpha: 0.94),
        border: Border(bottom: BorderSide(color: navBorder, width: 1.0)),
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Builder(
                        builder: (ctx) => GestureDetector(
                          onTap: () => Scaffold.of(ctx).openDrawer(),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0x14FFFFFF) : const Color(0xFFF1F5F9),
                              border: Border.all(color: navBorder),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.menu_rounded,
                              size: 20,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const DashboardSwitcherDropdown(
                        currentMode: DashboardMode.admin,
                        compact: true,
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      context.go('/dashboard');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0x0DFF3A58),
                        border: Border.all(color: const Color(0x29FF3A58)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.storefront_rounded, size: 14, color: Color(0xFFFF3A58)),
                          const SizedBox(width: 5),
                          Text(
                            'Exit',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFFF3A58),
                            ),
                          ),
                        ],
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
}

// ── Sidebar Header ─────────────────────────────────────────────────────────
class _SidebarHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: DashboardSwitcherDropdown(
        currentMode: DashboardMode.admin,
        compact: false,
      ),
    );
  }
}

// ── Sidebar Item Widget ─────────────────────────────────────────────────────
class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final IconData iconActive;
  final String label;
  final bool isActive;
  final bool isExit;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.iconActive,
    required this.label,
    required this.isActive,
    this.isExit = false,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? const Color(0xFFF5A623) : const Color(0xFFD97706);
    final activeBg = isDark ? const Color(0x1EF5A623) : const Color(0xFFFFF8EE);
    const exitColor = Color(0xFFFF3A58);
    final inactiveColor = isDark ? const Color(0xFF64748B) : const Color(0xFF64748B);
    final hoverBg = isDark ? const Color(0x10FFFFFF) : const Color(0xFFF1F5F9);

    final mainColor = widget.isExit
        ? exitColor
        : (widget.isActive ? activeColor : inactiveColor);
    final bg = widget.isExit
        ? (_hovered ? const Color(0x12FF3A58) : Colors.transparent)
        : (widget.isActive
            ? activeBg
            : (_hovered ? hoverBg : Colors.transparent));

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 3),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(11),
            border: widget.isActive
                ? Border.all(color: activeColor.withValues(alpha: 0.3), width: 1)
                : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 3.5,
                height: 18,
                decoration: BoxDecoration(
                  color: widget.isActive ? activeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: widget.isActive
                      ? [BoxShadow(color: activeColor.withValues(alpha: 0.6), blurRadius: 6)]
                      : [],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                widget.isActive ? widget.iconActive : widget.icon,
                size: 19,
                color: mainColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: widget.isActive ? FontWeight.w800 : FontWeight.w500,
                    color: mainColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
