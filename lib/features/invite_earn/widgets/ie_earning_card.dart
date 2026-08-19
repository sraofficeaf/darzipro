import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/theme_extensions.dart';

/// Teal accent color for Invite & Earn section
const Color ieAccent = Color(0xFF10CBA0);
const Color ieAccentDark = Color(0xFF059669);
const Color ieAccentBg = Color(0x1A10CBA0);
const Color ieAccentBorder = Color(0x3310CBA0);

/// Reusable stat card for Invite & Earn home screen
class IeEarningCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final Widget? trailingHeader;
  final IconData icon;
  final Widget? action;
  final VoidCallback? onTap;
  /// If true, use larger padding and value font (for Registered Users card)
  final bool large;

  const IeEarningCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.trailingHeader,
    required this.icon,
    this.action,
    this.onTap,
    this.large = false,
    bool highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final surface = context.surface;
    final text1 = context.text1;
    final text2 = context.text2;
    final text3 = context.text3;

    final cardPadding = large
        ? const EdgeInsets.symmetric(horizontal: 18, vertical: 18)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 14);
    final valueSize = large ? 28.0 : 20.0;
    final iconSize = large ? 36.0 : 30.0;
    final iconInnerSize = large ? 20.0 : 16.0;
    final iconRadius = large ? 10.0 : 8.0;

    Widget card = Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          top: BorderSide(
            color: ieAccent,
            width: 2.5,
          ),
        ),
        boxShadow: isDark
            ? [
                const BoxShadow(
                  color: Color(0x0F10CBA0),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ]
            : [
                const BoxShadow(
                  color: Color(0x0C000000),
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
              ],
      ),
      padding: cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── Top Row: Icon + Title ──
          Row(
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: ieAccentBg,
                  borderRadius: BorderRadius.circular(iconRadius),
                  border: Border.all(color: ieAccentBorder, width: 1),
                ),
                child: Center(child: Icon(icon, size: iconInnerSize, color: ieAccent)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: large ? 13 : 11,
                    fontWeight: FontWeight.w700,
                    color: text3,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ?trailingHeader,
            ],
          ),
          const SizedBox(height: 14),

          // ── Amount Value ──
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: valueSize,
              fontWeight: FontWeight.w800,
              color: text1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          if (subtitle != null) ...[
            const SizedBox(height: 5),
            Text(
              subtitle!,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: text2,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          ?action,
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: ieAccent.withValues(alpha: 0.08),
        child: card,
      );
    }
    return card;
  }
}
