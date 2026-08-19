import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ── SHARED ULTRA-PROFESSIONAL TEXTFIELD (SaaS Tier) ──────────────────────
/// Used across Login, Registration, and Modals for a sleek, unified experience.
/// Features:
///  • Animated micro-label with active indicator
///  • Floating prefix icon badge with gradient activation on focus
///  • Ambient glow aura on focus
///  • Custom suffix actions (interactive eye, clear button, etc.)
///  • Dark & Light mode tailored surfaces
///  • Smooth micro-animations on focus and hover
/// ──────────────────────────────────────────────────────────────────────────
class ProField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType keyboardType;
  final FocusNode? focusNode;
  final int maxLines;
  final String? errorText;
  final bool readOnly;
  final VoidCallback? onTap;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final TextCapitalization textCapitalization;

  const ProField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType = TextInputType.text,
    this.focusNode,
    this.maxLines = 1,
    this.errorText,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  State<ProField> createState() => _ProFieldState();
}

class _ProFieldState extends State<ProField> with SingleTickerProviderStateMixin {
  late FocusNode _focus;
  bool _isFocused = false;
  late AnimationController _animController;
  late Animation<double> _focusAnim;

  @override
  void initState() {
    super.initState();
    _focus = widget.focusNode ?? FocusNode();
    _focus.addListener(_onFocus);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _focusAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
  }

  void _onFocus() {
    if (mounted) {
      setState(() => _isFocused = _focus.hasFocus);
      if (_focus.hasFocus) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    if (widget.focusNode == null) _focus.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    // Palette tokens
    final primaryAccent = isDark ? const Color(0xFFF5A623) : const Color(0xFFD97706);
    final errorColor = const Color(0xFFEF4444);

    final textColor = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final hintColor = isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8);

    final labelColor = hasError
        ? errorColor
        : (_isFocused
            ? primaryAccent
            : (isDark ? const Color(0xFF64748B) : const Color(0xFF64748B)));

    final idleBg = isDark ? const Color(0xFF0D1524) : const Color(0xFFF8FAFC);
    final focusedBg = isDark ? const Color(0xFF111D33) : const Color(0xFFFFFFFF);

    final idleBorder = isDark ? const Color(0x22FFFFFF) : const Color(0xFFE2E8F0);
    final focusedBorder = hasError ? errorColor : primaryAccent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header Micro Label with Active Dot Indicator ──
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasError
                      ? errorColor
                      : (_isFocused ? primaryAccent : Colors.transparent),
                  boxShadow: _isFocused && !hasError
                      ? [
                          BoxShadow(
                            color: primaryAccent.withValues(alpha: 0.6),
                            blurRadius: 6,
                          )
                        ]
                      : null,
                ),
              ),
              if (_isFocused || hasError) const SizedBox(width: 6),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                  letterSpacing: 0.8,
                ),
                child: Text(widget.label.toUpperCase()),
              ),
            ],
          ),
          const SizedBox(height: 7),

          // ── Sleek Input Box ──
          AnimatedBuilder(
            animation: _focusAnim,
            builder: (context, child) {
              final glowAlpha = hasError ? 0.25 : (_focusAnim.value * 0.22);
              final activeColor = hasError ? errorColor : primaryAccent;

              return Container(
                decoration: BoxDecoration(
                  color: Color.lerp(idleBg, focusedBg, _focusAnim.value),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Color.lerp(idleBorder, focusedBorder, _focusAnim.value)!,
                    width: _isFocused ? 1.5 : 1.2,
                  ),
                  boxShadow: [
                    if (_isFocused || hasError)
                      BoxShadow(
                        color: activeColor.withValues(alpha: glowAlpha),
                        blurRadius: 16,
                        spreadRadius: 0,
                        offset: const Offset(0, 3),
                      ),
                  ],
                ),
                child: child,
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                crossAxisAlignment: widget.maxLines > 1
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                children: [
                  // ── Prefix Icon Badge with Focus Gradient ──
                  Padding(
                    padding: EdgeInsets.only(top: widget.maxLines > 1 ? 6 : 0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: _isFocused && !hasError
                            ? LinearGradient(
                                colors: [
                                  isDark ? const Color(0xFFD97706) : const Color(0xFFF5A623),
                                  isDark ? const Color(0xFFF5A623) : const Color(0xFFD97706),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: _isFocused && !hasError
                            ? null
                            : (hasError
                                ? errorColor.withValues(alpha: 0.15)
                                : (isDark ? const Color(0x14FFFFFF) : const Color(0xFFEEF2F6))),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _isFocused && !hasError
                              ? Colors.transparent
                              : (hasError
                                  ? errorColor.withValues(alpha: 0.4)
                                  : (isDark ? const Color(0x18FFFFFF) : const Color(0xFFE2E8F0))),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          widget.icon,
                          size: 18,
                          color: _isFocused && !hasError
                              ? Colors.white
                              : (hasError
                                  ? errorColor
                                  : (isDark ? const Color(0xFF64748B) : const Color(0xFF8896AB))),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // ── Text Input ──
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focus,
                      obscureText: widget.obscure,
                      keyboardType: widget.keyboardType,
                      maxLines: widget.obscure ? 1 : widget.maxLines,
                      readOnly: widget.readOnly,
                      onTap: widget.onTap,
                      onChanged: widget.onChanged,
                      onSubmitted: widget.onSubmitted,
                      textCapitalization: widget.textCapitalization,
                      cursorColor: primaryAccent,
                      cursorWidth: 2,
                      cursorRadius: const Radius.circular(2),
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        color: textColor,
                        fontWeight: FontWeight.w500,
                        letterSpacing: widget.obscure ? 1.5 : 0.1,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.hint,
                        hintStyle: GoogleFonts.inter(
                          fontSize: 13.5,
                          color: hintColor,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: widget.maxLines > 1 ? 8 : 11,
                        ),
                      ),
                    ),
                  ),

                  // ── Suffix Action ──
                  if (widget.suffix != null) ...[
                    const SizedBox(width: 6),
                    Padding(
                      padding: EdgeInsets.only(top: widget.maxLines > 1 ? 6 : 0),
                      child: widget.suffix!,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Optional Error Notice ──
          if (hasError)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, size: 13, color: errorColor),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      widget.errorText!,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: errorColor,
                        fontWeight: FontWeight.w600,
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
