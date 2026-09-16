import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ──────────────────────────────────────────────────────────────────────────
// PALETTE & DESIGN TOKENS (Matching HTML Reference)
// ──────────────────────────────────────────────────────────────────────────
class AdminColors {
  static const bg = Color(0xFFF5F6F8);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF8FAFC);
  static const border = Color(0xFFE8EBF0);
  static const borderStrong = Color(0xFFD8DDE5);
  static const text1 = Color(0xFF0A0F1C);
  static const text2 = Color(0xFF475569);
  static const text3 = Color(0xFF94A3B8);

  static const indigo = Color(0xFF6366F1);
  static const violet = Color(0xFF8B5CF6);
  static const blue = Color(0xFF3B82F6);
  static const amber = Color(0xFFF59E0B);
  static const emerald = Color(0xFF10B981);
  static const rose = Color(0xFFEF4444);
  static const pink = Color(0xFFEC4899);
  static const teal = Color(0xFF14B8A6);
  static const orange = Color(0xFFD97706);
}

// ──────────────────────────────────────────────────────────────────────────
// 1. ADMIN PAGE HEADER
// ──────────────────────────────────────────────────────────────────────────
class AdminPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;
  final List<Widget>? actions;
  final VoidCallback? onRefresh;

  const AdminPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
    this.actions,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF131B2E) : AdminColors.surface;
    final border = isDark ? const Color(0xFF1E293B) : AdminColors.border;
    final text1 = isDark ? Colors.white : AdminColors.text1;
    final text2 = isDark ? const Color(0xFF94A3B8) : AdminColors.text2;

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: surface,
          border: Border(bottom: BorderSide(color: border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: text1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: text2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: 12),
              action!,
            ],
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(width: 12),
              ...actions!,
            ],
            if (onRefresh != null) ...[
              const SizedBox(width: 8),
              AdminIconBtn(
                icon: Icons.refresh_rounded,
                onTap: onRefresh!,
                tooltip: 'Refresh',
              ),
            ],
          ],
        ),
      ),
    );
  }
}


// ──────────────────────────────────────────────────────────────────────────
// 2. ICON BUTTON (38x38 with 10px radius)
// ──────────────────────────────────────────────────────────────────────────
class AdminIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final Color? color;
  final Color? backgroundColor;
  final double? size;

  AdminIconBtn({
    super.key,
    required this.icon,
    VoidCallback? onTap,
    VoidCallback? onPressed,
    this.tooltip,
    this.color,
    this.backgroundColor,
    this.size,
  }) : onTap = onTap ?? onPressed ?? (() {});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = backgroundColor ??
        (isDark ? const Color(0xFF1E293B) : AdminColors.surface2);
    final border = isDark ? const Color(0xFF334155) : AdminColors.border;
    final iconColor = color ??
        (isDark ? const Color(0xFFCBD5E1) : AdminColors.text2);
    final btnSize = size ?? 38.0;

    Widget btn = Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: btnSize,
          height: btnSize,
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: btnSize * 0.48),
        ),
      ),
    );

    if (tooltip != null) {
      btn = Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}


// ──────────────────────────────────────────────────────────────────────────
// 3. TAB WITH COUNT BADGE (Approvals, Invites, etc.)
// ──────────────────────────────────────────────────────────────────────────
class AdminTabItem {
  final String label;
  final int? count;
  final Color? countColor;

  const AdminTabItem({
    required this.label,
    this.count,
    this.countColor,
  });
}

class AdminTabBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController? controller;
  final List<Widget>? tabs;
  final List<AdminTabItem>? items;
  final int? selectedIndex;
  final ValueChanged<int>? onTabSelected;

  const AdminTabBar({
    super.key,
    this.controller,
    this.tabs,
    List<AdminTabItem>? items,
    List<AdminTabItem>? tabsList,
    this.selectedIndex,
    this.onTabSelected,
  }) : items = items ?? tabsList;

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF131B2E) : AdminColors.surface;
    final border = isDark ? const Color(0xFF1E293B) : AdminColors.border;
    final text2 = isDark ? const Color(0xFF94A3B8) : AdminColors.text2;

    if (controller != null && tabs != null) {
      return RepaintBoundary(
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: surface,
            border: Border(bottom: BorderSide(color: border)),
          ),
          child: TabBar(
            controller: controller,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AdminColors.indigo,
            indicatorWeight: 2.5,
            labelColor: AdminColors.indigo,
            unselectedLabelColor: text2,
            labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
            unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
            tabs: tabs!,
          ),
        ),
      );
    }

    final tabItems = items ?? [];
    return RepaintBoundary(
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: surface,
          border: Border(bottom: BorderSide(color: border)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (int i = 0; i < tabItems.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                _AdminTabItemView(
                  item: tabItems[i],
                  isSelected: i == (selectedIndex ?? 0),
                  onTap: () => onTabSelected?.call(i),
                  defaultTextCol: text2,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminTabItemView extends StatelessWidget {
  final AdminTabItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final Color defaultTextCol;

  const _AdminTabItemView({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.defaultTextCol,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AdminColors.indigo : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? AdminColors.indigo : defaultTextCol,
              ),
            ),
            if (item.count != null) ...[
              const SizedBox(width: 8),
              AdminCountBadge(
                count: item.count!,
                color: item.countColor ?? AdminColors.indigo,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// 4. COUNT BADGE (Inside tabs)
// ──────────────────────────────────────────────────────────────────────────
class AdminCountBadge extends StatelessWidget {
  final int count;
  final Color color;
  final String? label;

  const AdminCountBadge({
    super.key,
    required this.count,
    this.color = AdminColors.indigo,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    if (label != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label!,
            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          _buildBadge(),
        ],
      );
    }
    return _buildBadge();
  }

  Widget _buildBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$count',
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// 5. STATUS BADGE
// ──────────────────────────────────────────────────────────────────────────
enum AdminBadgeType { indigo, blue, emerald, amber, rose, gray }

class AdminBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final AdminBadgeType? type;

  const AdminBadge({
    super.key,
    required this.label,
    this.color,
    this.type,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ??
        switch (type) {
          AdminBadgeType.indigo => AdminColors.indigo,
          AdminBadgeType.blue => AdminColors.blue,
          AdminBadgeType.emerald => AdminColors.emerald,
          AdminBadgeType.amber => AdminColors.amber,
          AdminBadgeType.rose => AdminColors.rose,
          AdminBadgeType.gray => AdminColors.text3,
          null => AdminColors.blue,
        };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: effectiveColor.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: effectiveColor,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// 6. FILTER CHIP
// ──────────────────────────────────────────────────────────────────────────
class AdminChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onSelected;
  final Color activeColor;

  const AdminChip({
    super.key,
    required this.label,
    required this.isSelected,
    this.onTap,
    this.onSelected,
    Color? color,
    Color? activeColor,
  }) : activeColor = color ?? activeColor ?? AdminColors.indigo;


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1E293B) : AdminColors.surface;
    final border = isDark ? const Color(0xFF334155) : AdminColors.border;
    final text2 = isDark ? const Color(0xFFCBD5E1) : AdminColors.text2;
    final callback = onTap ?? onSelected ?? () {};

    return Material(
      color: isSelected ? activeColor : surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          callback();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? activeColor : border,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : text2,
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// 7. SUMMARY BAR (e.g. Invites, Revenue, Reports)
// ──────────────────────────────────────────────────────────────────────────
class AdminSummaryBar extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Widget? trailing;

  const AdminSummaryBar({
    super.key,
    required this.icon,
    Color? iconColor,
    Color? color,
    required this.label,
    required this.value,
    this.trailing,
  }) : iconColor = color ?? iconColor ?? AdminColors.indigo;


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF131B2E) : AdminColors.surface;
    final border = isDark ? const Color(0xFF1E293B) : AdminColors.border;
    final text1 = isDark ? Colors.white : AdminColors.text1;

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: AdminColors.text3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: text1,
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// 8. STAT CARD (Grid item)
// ──────────────────────────────────────────────────────────────────────────
class AdminStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final String? subtext;
  final IconData icon;
  final Color? accentColor;
  final Color? color;

  const AdminStatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.subtext,
    required this.icon,
    this.accentColor,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? accentColor ?? AdminColors.indigo;
    final effectiveSubtitle = subtitle ?? subtext ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF131B2E) : AdminColors.surface;
    final border = isDark ? const Color(0xFF1E293B) : AdminColors.border;
    final text2 = isDark ? const Color(0xFF94A3B8) : AdminColors.text2;

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: text2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: effectiveColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: effectiveColor, size: 15),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: effectiveColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (effectiveSubtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                effectiveSubtitle,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: AdminColors.text3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// 9. MINI STAT (Inline block)
// ──────────────────────────────────────────────────────────────────────────
class AdminMiniStat extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;
  final Color? color;

  const AdminMiniStat({
    super.key,
    required this.value,
    required this.label,
    this.valueColor,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? valueColor ?? AdminColors.indigo;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface2 = isDark ? const Color(0xFF1E293B) : AdminColors.surface2;
    final border = isDark ? const Color(0xFF334155) : AdminColors.border;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: effectiveColor,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AdminColors.text3,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// 10. INFO BOX
// ──────────────────────────────────────────────────────────────────────────
class AdminInfoBox extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;

  const AdminInfoBox({
    super.key,
    required this.text,
    this.icon = Icons.info_outline_rounded,
    this.color = AdminColors.amber,
  });

  const AdminInfoBox.amber({
    super.key,
    required this.text,
    this.icon = Icons.info_outline_rounded,
  }) : color = AdminColors.amber;

  const AdminInfoBox.rose({
    super.key,
    required this.text,
    this.icon = Icons.error_outline_rounded,
  }) : color = AdminColors.rose;

  const AdminInfoBox.blue({
    super.key,
    required this.text,
    this.icon = Icons.info_outline_rounded,
  }) : color = AdminColors.blue;

  const AdminInfoBox.emerald({
    super.key,
    required this.text,
    this.icon = Icons.check_circle_outline_rounded,
  }) : color = AdminColors.emerald;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: color,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// 11. BUTTONS (Matching .btn, .btn-primary, .btn-success, etc.)
// ──────────────────────────────────────────────────────────────────────────
class AdminButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final bool isFullWidth;
  final bool isSmall;
  final bool isOutlined;

  AdminButton({
    super.key,
    required this.label,
    VoidCallback? onTap,
    VoidCallback? onPressed,
    this.icon,
    Color? backgroundColor,
    Color? textColor,
    this.borderColor,
    this.isFullWidth = false,
    this.isSmall = false,
    this.isOutlined = false,
  })  : onTap = onTap ?? onPressed ?? (() {}),
        backgroundColor = backgroundColor ??
            (isOutlined ? Colors.transparent : AdminColors.indigo),
        textColor = textColor ??
            (isOutlined ? AdminColors.indigo : Colors.white);

  factory AdminButton.primary({
    required String label,
    VoidCallback? onTap,
    VoidCallback? onPressed,
    IconData? icon,
    bool isFullWidth = false,
    bool isSmall = false,
  }) =>
      AdminButton(
        label: label,
        onTap: onTap ?? onPressed,
        icon: icon,
        backgroundColor: AdminColors.indigo,
        textColor: Colors.white,
        isFullWidth: isFullWidth,
        isSmall: isSmall,
      );

  factory AdminButton.success({
    required String label,
    VoidCallback? onTap,
    VoidCallback? onPressed,
    IconData? icon,
    bool isSmall = false,
    bool isFullWidth = false,
  }) =>
      AdminButton(
        label: label,
        onTap: onTap ?? onPressed,
        icon: icon,
        backgroundColor: AdminColors.emerald,
        textColor: Colors.white,
        isSmall: isSmall,
        isFullWidth: isFullWidth,
      );

  factory AdminButton.danger({
    required String label,
    VoidCallback? onTap,
    VoidCallback? onPressed,
    IconData? icon,
    bool isSmall = false,
    bool isFullWidth = false,
  }) =>
      AdminButton(
        label: label,
        onTap: onTap ?? onPressed,
        icon: icon,
        backgroundColor: Colors.transparent,
        textColor: AdminColors.rose,
        borderColor: AdminColors.rose,
        isSmall: isSmall,
        isFullWidth: isFullWidth,
      );

  factory AdminButton.ghost({
    required String label,
    VoidCallback? onTap,
    VoidCallback? onPressed,
    IconData? icon,
    bool isSmall = false,
    bool isFullWidth = false,
  }) =>
      AdminButton(
        label: label,
        onTap: onTap ?? onPressed,
        icon: icon,
        backgroundColor: Colors.transparent,
        textColor: AdminColors.text2,
        borderColor: AdminColors.borderStrong,
        isSmall: isSmall,
        isFullWidth: isFullWidth,
      );

  factory AdminButton.amber({
    required String label,
    VoidCallback? onTap,
    VoidCallback? onPressed,
    IconData? icon,
    bool isSmall = false,
    bool isFullWidth = false,
  }) =>
      AdminButton(
        label: label,
        onTap: onTap ?? onPressed,
        icon: icon,
        backgroundColor: AdminColors.amber,
        textColor: Colors.white,
        isSmall: isSmall,
        isFullWidth: isFullWidth,
      );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: isFullWidth ? double.infinity : null,
          padding: EdgeInsets.symmetric(
            horizontal: isSmall ? 10 : 14,
            vertical: isSmall ? 6 : (isFullWidth ? 13 : 8),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: borderColor ??
                  (isOutlined ? AdminColors.indigo : Colors.transparent),
            ),
          ),
          alignment: isFullWidth ? Alignment.center : null,
          child: Row(
            mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: textColor, size: isSmall ? 13 : 15),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: isSmall ? 11 : 12,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// 12. DIRECTION / STATUS PILL (IN / OUT / PAID / PENDING)
// ──────────────────────────────────────────────────────────────────────────
class AdminDirectionPill extends StatelessWidget {
  final String label;
  final bool isIncoming;

  const AdminDirectionPill({
    super.key,
    String? label,
    bool? isIncoming,
    bool? isOut,
  })  : isIncoming = isIncoming ?? !(isOut ?? false),
        label = label ?? (isOut == true ? 'OUT' : (isIncoming == false ? 'OUT' : 'IN'));

  @override
  Widget build(BuildContext context) {
    final col = isIncoming ? AdminColors.emerald : AdminColors.rose;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: col,
        ),
      ),
    );
  }
}

