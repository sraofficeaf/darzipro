import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/utils/plan_utils.dart';
import '../../../core/theme/theme_extensions.dart';
import 'ie_earning_card.dart';

/// Row widget for each invited shop in My Invites screen
class IeInviteRow extends StatelessWidget {
  final Map<String, dynamic> shop;
  final VoidCallback? onTap;

  const IeInviteRow({super.key, required this.shop, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final text1 = context.text1;
    final text2 = context.text2;
    final surface = context.surface;
    final border = context.border;

    final name = shop['name'] as String? ?? 'Unknown';
    final status = shop['status'] as String? ?? 'inactive';
    final plan = shop['plan'] as String? ?? 'full_access';
    final earned = shop['total_earned_from'] as int? ?? 0;

    final statusColor = switch (status) {
      'active' => ieAccent,
      'pending' => const Color(0xFFF5A623),
      _ => const Color(0xFF94A3B8),
    };
    final statusLabel = switch (status) {
      'active' => 'Active',
      'pending' => 'Pending',
      _ => 'Inactive',
    };

    final (planLabel, planColor) = AppPlanUtils.getDisplayInfo(plan);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: ieAccentBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: ieAccent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: text1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      _Badge(label: planLabel, color: planColor),
                      const SizedBox(width: 6),
                      _Badge(label: statusLabel, color: statusColor),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Earned amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Rs ${_fmt(earned)}',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: ieAccent,
                  ),
                ),
                Text(
                  'earned',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: text2,
                  ),
                ),
              ],
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, size: 18,
                  color: isDark ? const Color(0xFF3D5470) : const Color(0xFFCBD5E1)),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(int v) => v.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
