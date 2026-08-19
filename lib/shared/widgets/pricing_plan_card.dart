import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class PricingPlanCard extends StatelessWidget {
  final String planId;
  final String name;
  final String price;
  final String priceLabel;
  final String subtitle;
  final String? badge;
  final bool isPopular;
  final bool isSelected;
  final Color accentColor;
  final List<String> features;
  final String? buttonText;
  final VoidCallback onSelect;

  const PricingPlanCard({
    super.key,
    required this.planId,
    required this.name,
    required this.price,
    required this.priceLabel,
    required this.subtitle,
    this.badge,
    this.isPopular = false,
    required this.isSelected,
    required this.accentColor,
    required this.features,
    this.buttonText,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Palette configurations based on Dark/Light mode
    final cardBg = isDark
        ? (isSelected || isPopular
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF1E1B4B).withValues(alpha: isSelected ? 0.95 : 0.8),
                  const Color(0xFF0F172A).withValues(alpha: 0.98),
                ],
              )
            : const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF0A0F1D)],
              ))
        : (isSelected || isPopular
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFF5F3FF),
                  Colors.white,
                ],
              )
            : const LinearGradient(
                colors: [Colors.white, Color(0xFFFAFAFC)],
              ));

    final borderColor = isSelected
        ? accentColor
        : (isPopular
            ? accentColor.withValues(alpha: isDark ? 0.45 : 0.35)
            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)));

    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final pillBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final pillTextColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor,
          width: isSelected ? 2.2 : (isPopular ? 1.4 : 1.0),
        ),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: accentColor.withValues(alpha: isDark ? 0.28 : 0.16),
              blurRadius: 24,
              spreadRadius: 1,
              offset: const Offset(0, 8),
            )
          else if (isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            )
          else
            BoxShadow(
              color: const Color(0x0A000000),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Ambient corner glow for selected card (Dark Mode)
          if (isDark && (isSelected || isPopular))
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.15),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Badge Header
                SizedBox(
                  height: 26,
                  child: Center(
                    child: (badge != null && badge!.isNotEmpty)
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: isPopular
                                  ? const LinearGradient(
                                      colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                                    )
                                  : null,
                              color: isPopular ? null : accentColor.withValues(alpha: isDark ? 0.22 : 0.12),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: isPopular
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : null,
                            ),
                            child: Text(
                              badge!,
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: isPopular ? Colors.white : accentColor,
                                letterSpacing: 0.8,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),

                const SizedBox(height: 10),

                // Plan Name
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: -0.2,
                  ),
                ),

                const SizedBox(height: 10),

                // Price Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      price,
                      style: GoogleFonts.outfit(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  priceLabel,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: subColor,
                  ),
                ),

                const SizedBox(height: 14),

                // Subtitle / Tagline Capsule Pill
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: pillBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: pillTextColor,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Divider line
                Container(
                  height: 1,
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                ),

                const SizedBox(height: 16),

                // Feature Checklist
                ...features.map((feat) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 1.5, right: 9),
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: isDark ? 0.18 : 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: 13,
                              color: isDark ? accentColor : accentColor,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              feat,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),

                const SizedBox(height: 18),

                // Bottom Action Button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onSelect();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: isPopular
                                  ? [const Color(0xFF8B5CF6), const Color(0xFF6366F1)]
                                  : [accentColor, accentColor.withValues(alpha: 0.85)],
                            )
                          : null,
                      color: isSelected
                          ? null
                          : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        width: 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isSelected) ...[
                          const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          buttonText ?? (isSelected ? 'Selected Plan' : 'Select Plan'),
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white : const Color(0xFF1E293B)),
                          ),
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
    );
  }
}
