import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/theme_extensions.dart';
import '../../shared/widgets/dashboard_switcher.dart';
import 'widgets/ie_earning_card.dart';
import 'screens/ie_home_screen.dart';
import 'screens/ie_my_invites_screen.dart';
import 'screens/ie_payouts_screen.dart';
import 'screens/ie_invite_tools_screen.dart';
import 'screens/ie_settings_screen.dart';

// ── Nav items ────────────────────────────────────────────────────────────────
class _IeTab {
  final IconData icon;
  final IconData iconActive;
  final String label;
  const _IeTab({
    required this.icon,
    required this.iconActive,
    required this.label,
  });
}

const _tabs = [
  _IeTab(
      icon: Icons.home_outlined,
      iconActive: Icons.home_rounded,
      label: 'Home'),
  _IeTab(
      icon: Icons.storefront_outlined,
      iconActive: Icons.storefront_rounded,
      label: 'My Invites'),
  _IeTab(
      icon: Icons.payments_outlined,
      iconActive: Icons.payments_rounded,
      label: 'Payouts'),
  _IeTab(
      icon: Icons.share_outlined,
      iconActive: Icons.share_rounded,
      label: 'Tools'),
  _IeTab(
      icon: Icons.settings_outlined,
      iconActive: Icons.settings_rounded,
      label: 'Settings'),
];

// ── Shell ─────────────────────────────────────────────────────────────────────
class InviteEarnShell extends StatefulWidget {
  const InviteEarnShell({super.key});

  @override
  State<InviteEarnShell> createState() => _InviteEarnShellState();
}

class _InviteEarnShellState extends State<InviteEarnShell> {
  int _index = 0;

  void _switchTab(int i) => setState(() => _index = i);

  List<Widget> get _screens => [
        IeHomeScreen(
          onViewPayouts: () => _switchTab(2),
          onInviteNow: () => _switchTab(3),
          onSwitchTab: _switchTab,
        ),
        const IeMyInvitesScreen(),
        const IePayoutsScreen(),
        const IeInviteToolsScreen(),
        const IeSettingsScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 720;
    if (isWide) {
      return _IeDesktopShell(
          index: _index, onTab: _switchTab, screens: _screens);
    } else {
      return _IeMobileShell(
          index: _index, onTab: _switchTab, screens: _screens);
    }
  }
}

// ── Desktop Shell ─────────────────────────────────────────────────────────────
class _IeDesktopShell extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTab;
  final List<Widget> screens;

  const _IeDesktopShell(
      {required this.index, required this.onTab, required this.screens});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final sidebarBg = isDark ? const Color(0xFF051118) : Colors.white;
    final sidebarBorder =
        isDark ? const Color(0x12FFFFFF) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: context.bg,
      body: Row(
        children: [
          // ── Sidebar ─────────────────────────────────────────────────
          Container(
            width: 220,
            decoration: BoxDecoration(
              color: sidebarBg,
              border: Border(right: BorderSide(color: sidebarBorder)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _IeSidebarHeader(onExitToMain: () => context.go('/dashboard')),
                Divider(height: 1, color: sidebarBorder),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: List.generate(
                      _tabs.length,
                      (i) => _IeSidebarItem(
                        tab: _tabs[i],
                        isActive: index == i,
                        onTap: () => onTab(i),
                      ),
                    ),
                  ),
                ),
                Divider(height: 1, color: sidebarBorder),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  child: _IeSidebarItem(
                    tab: const _IeTab(
                      icon: Icons.arrow_back_rounded,
                      iconActive: Icons.arrow_back_rounded,
                      label: 'Back to Darzi Pro',
                    ),
                    isActive: false,
                    isExit: true,
                    onTap: () => context.go('/dashboard'),
                  ),
                ),
              ],
            ),
          ),
          // ── Content ──────────────────────────────────────────────────
          Expanded(
            child: IndexedStack(
              index: index,
              children: screens,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mobile Shell ──────────────────────────────────────────────────────────────
class _IeMobileShell extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTab;
  final List<Widget> screens;

  const _IeMobileShell(
      {required this.index, required this.onTab, required this.screens});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final navBg = isDark ? const Color(0xFF051118) : Colors.white;
    final navBorder =
        isDark ? const Color(0x12FFFFFF) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: context.bg,
      appBar: _IeMobileAppBar(onExitToMain: () => context.go('/dashboard')),
      body: IndexedStack(
        index: index,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBg,
          border: Border(top: BorderSide(color: navBorder)),
          boxShadow: isDark
              ? []
              : [
                  const BoxShadow(
                      color: Color(0x0D000000),
                      blurRadius: 8,
                      offset: Offset(0, -2))
                ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 58,
            child: Row(
              children: List.generate(
                _tabs.length,
                (i) {
                  final tab = _tabs[i];
                  final isActive = i == index;
                  final activeColor = ieAccent;
                  final inactiveColor = isDark
                      ? const Color(0xFF3D5470)
                      : const Color(0xFF94A3B8);

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onTab(i),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? ieAccent.withValues(alpha: 0.14)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              isActive ? tab.iconActive : tab.icon,
                              size: 20,
                              color:
                                  isActive ? activeColor : inactiveColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tab.label,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color:
                                  isActive ? activeColor : inactiveColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Mobile AppBar ─────────────────────────────────────────────────────────────
class _IeMobileAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onExitToMain;
  const _IeMobileAppBar({required this.onExitToMain});

  @override
  Size get preferredSize => const Size.fromHeight(54);

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final navBg = isDark ? const Color(0xFF051118) : Colors.white;
    final navBorder =
        isDark ? const Color(0x12FFFFFF) : const Color(0xFFE2E8F0);

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
                  // Unified Mode switcher
                  const DashboardSwitcherDropdown(
                    currentMode: DashboardMode.earn,
                    compact: true,
                  ),

                  // Right actions
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Live Status Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x1410CBA0) : const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? const Color(0x2E10CBA0) : const Color(0x33059669)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: ieAccent,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: Color(0x8010CBA0), blurRadius: 6),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Live',
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: ieAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Exit button to shop
                      GestureDetector(
                        onTap: onExitToMain,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0x14FFFFFF) : const Color(0xFFF1F5F9),
                            border: Border.all(color: navBorder),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.storefront_rounded,
                              size: 18,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
        ),
      ),
    );
  }
}

// ── Sidebar Header ────────────────────────────────────────────────────────────
class _IeSidebarHeader extends StatelessWidget {
  final VoidCallback onExitToMain;
  const _IeSidebarHeader({required this.onExitToMain});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: DashboardSwitcherDropdown(
        currentMode: DashboardMode.earn,
        compact: false,
      ),
    );
  }
}



// ── Sidebar Item ──────────────────────────────────────────────────────────────
class _IeSidebarItem extends StatefulWidget {
  final _IeTab tab;
  final bool isActive;
  final bool isExit;
  final VoidCallback onTap;

  const _IeSidebarItem({
    required this.tab,
    required this.isActive,
    this.isExit = false,
    required this.onTap,
  });

  @override
  State<_IeSidebarItem> createState() => _IeSidebarItemState();
}

class _IeSidebarItemState extends State<_IeSidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final activeColor = ieAccent;
    final activeBg = ieAccentBg;
    final activeBorder = ieAccentBorder;
    const exitColor = Color(0xFFFF3A58);
    final inactiveColor =
        isDark ? const Color(0xFF5A7090) : const Color(0xFF6B7280);
    final hoverBg =
        isDark ? const Color(0x0AFFFFFF) : const Color(0xFFF8FAFC);

    final mainColor = widget.isExit
        ? exitColor
        : (widget.isActive ? activeColor : inactiveColor);
    final bg = widget.isExit
        ? (_hovered ? const Color(0x0DFF3A58) : Colors.transparent)
        : (widget.isActive
            ? activeBg
            : (_hovered ? hoverBg : Colors.transparent));

    final iconBg = widget.isExit
        ? (isDark ? const Color(0x1AFF3A58) : const Color(0x0DFF3A58))
        : (widget.isActive
            ? (isDark ? const Color(0x2610CBA0) : const Color(0x1A10CBA0))
            : (isDark ? const Color(0x0AFFFFFF) : const Color(0xFFF1F5F9)));

    final iconBorder = widget.isActive && !widget.isExit
        ? Border.all(color: activeBorder, width: 1)
        : null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 3),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(11),
            border: widget.isActive && !widget.isExit
                ? Border.all(color: activeBorder, width: 1)
                : Border.all(color: Colors.transparent, width: 1),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  border: iconBorder,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: Icon(
                    widget.isActive ? widget.tab.iconActive : widget.tab.icon,
                    size: 18,
                    color: mainColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.tab.label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: widget.isActive
                        ? FontWeight.w700
                        : FontWeight.w500,
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

