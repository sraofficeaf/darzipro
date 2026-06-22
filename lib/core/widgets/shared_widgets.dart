import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../constants/app_enums.dart';

// ── Money formatter ────────────────────────────────────────────────────
String formatMoney(double amount) {
  final formatter = NumberFormat('#,##0', 'en_US');
  return '₨ ${formatter.format(amount)}';
}

String formatMoneyShort(double amount) {
  if (amount >= 1000000) {
    return '₨ ${(amount / 1000000).toStringAsFixed(1)}M';
  } else if (amount >= 1000) {
    return '₨ ${(amount / 1000).toStringAsFixed(0)}k';
  }
  return '₨ ${amount.toStringAsFixed(0)}';
}

String formatDate(DateTime date) {
  return DateFormat('MMM dd, yyyy').format(date);
}

String formatDateShort(DateTime date) {
  return DateFormat('MMM dd').format(date);
}

// ── Status color helper ────────────────────────────────────────────────
Color statusColor(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return AppColors.accent;
    case OrderStatus.cutting:
      return AppColors.purple;
    case OrderStatus.stitching:
      return AppColors.blue;
    case OrderStatus.ready:
      return AppColors.teal;
    case OrderStatus.delivered:
      return AppColors.statusDelivered;
    case OrderStatus.cancelled:
      return AppColors.red;
  }
}

Color statusBgColor(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return AppColors.accentS;
    case OrderStatus.cutting:
      return AppColors.purpleS;
    case OrderStatus.stitching:
      return AppColors.blueS;
    case OrderStatus.ready:
      return AppColors.tealS;
    case OrderStatus.delivered:
      return AppColors.borderDark;
    case OrderStatus.cancelled:
      return AppColors.redS;
  }
}

// ── Status Pill Widget ─────────────────────────────────────────────────
class StatusPill extends StatelessWidget {
  final OrderStatus status;

  const StatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    final bg = statusBgColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Customer Avatar ────────────────────────────────────────────────────
class CustomerAvatar extends StatelessWidget {
  final String name;
  final double size;
  final double fontSize;
  final CustomerGender? gender;
  final double? borderRadius;

  const CustomerAvatar({
    super.key,
    required this.name,
    this.size = 44,
    this.fontSize = 17,
    this.gender,
    this.borderRadius,
  });

  List<Color> get _gradientColors {
    // Pick gradient based on first letter
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';
    final code = initial.codeUnitAt(0);
    final gradients = [
      AppColors.avatarBlue,
      AppColors.avatarPurple,
      AppColors.avatarGreen,
      AppColors.avatarAmber,
      AppColors.avatarPink,
      AppColors.avatarBrand,
    ];
    return gradients[code % gradients.length];
  }

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _gradientColors,
        ),
        borderRadius: BorderRadius.circular(borderRadius ?? size / 2),
      ),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ── Card Border Painter ────────────────────────────────────────────────
class CardBorderPainter extends CustomPainter {
  final Color borderCol;
  final Color borderTopCol;
  final double radius;
  final double strokeWidth;

  CardBorderPainter({
    required this.borderCol,
    required this.borderTopCol,
    this.radius = 16,
    this.strokeWidth = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final halfStroke = strokeWidth / 2;
    final paint = Paint()
      ..color = borderCol
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rect = Rect.fromLTWH(
      halfStroke,
      halfStroke,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final adjustedRadius = radius - halfStroke;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(adjustedRadius));
    canvas.drawRRect(rrect, paint);

    final topPaint = Paint()
      ..color = borderTopCol
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final topPath = Path();
    topPath.moveTo(halfStroke, radius);
    topPath.arcToPoint(
      Offset(radius, halfStroke),
      radius: Radius.circular(adjustedRadius),
      clockwise: true,
    );
    topPath.lineTo(size.width - radius, halfStroke);
    topPath.arcToPoint(
      Offset(size.width - halfStroke, radius),
      radius: Radius.circular(adjustedRadius),
      clockwise: true,
    );

    canvas.drawPath(topPath, topPaint);
  }

  @override
  bool shouldRepaint(covariant CardBorderPainter oldDelegate) {
    return oldDelegate.borderCol != borderCol ||
        oldDelegate.borderTopCol != borderTopCol ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

// ── App Card ──────────────────────────────────────────────────────────
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final List<Color>? gradientColors;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.borderColor,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? AppColors.surfDark : AppColors.surfLight;
    final borderCol = borderColor ?? (isDark ? AppColors.borderDark : AppColors.borderLight);
    final borderTopCol = isDark ? AppColors.borderTopDark : AppColors.borderTopLight;

    Widget cardContent = Padding(
      padding: padding ?? const EdgeInsets.all(18),
      child: child,
    );

    Widget cardBody;

    if (gradientColors != null) {
      cardBody = Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors!,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderCol, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: cardContent,
      );
    } else if (isDark) {
      cardBody = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 20,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: CustomPaint(
          foregroundPainter: CardBorderPainter(
            borderCol: borderCol,
            borderTopCol: borderTopCol,
            radius: 16,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: surf,
                child: cardContent,
              ),
            ),
          ),
        ),
      );
    } else {
      cardBody = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: CustomPaint(
          foregroundPainter: CardBorderPainter(
            borderCol: borderCol,
            borderTopCol: borderTopCol,
            radius: 16,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: surf,
              borderRadius: BorderRadius.circular(16),
            ),
            child: cardContent,
          ),
        ),
      );
    }


    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: cardBody,
      );
    }
    return cardBody;
  }
}

// ── Section Header ─────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              action!,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ),
      ],
    );
  }
}

// ── App Text Field ─────────────────────────────────────────────────────
class AppTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final String? prefixIcon;
  final Widget? prefix;
  final Widget? suffix;
  final bool obscureText;
  final TextEditingController? controller;
  final String? initialValue;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final int maxLines;
  final bool autofocus;
  final FocusNode? focusNode;

  const AppTextField({
    super.key,
    this.label = '',
    this.hint,
    this.prefixIcon,
    this.prefix,
    this.suffix,
    this.obscureText = false,
    this.controller,
    this.initialValue,
    this.keyboardType,
    this.onChanged,
    this.validator,
    this.maxLines = 1,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_onFocusChange);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final text2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final text3 = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label.isNotEmpty) ...[
          Text(
            widget.label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: text2,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0x0FFFFFFF) : const Color(0xFFF4F6FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isFocused
                  ? const Color(0xFFF5A623) // gold when focused
                  : (isDark ? const Color(0x12FFFFFF) : const Color(0x1F000000)),
              width: 1.5,
            ),
            boxShadow: _isFocused
                ? const [BoxShadow(color: Color(0x25F5A623), blurRadius: 8)]
                : const [],
          ),
          child: Row(
            crossAxisAlignment: widget.maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              if (widget.prefixIcon != null)
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(
                    widget.prefixIcon!,
                    style: TextStyle(color: text3, fontSize: 16),
                  ),
                )
              else if (widget.prefix != null)
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: widget.prefix!,
                ),
              Expanded(
                child: TextFormField(
                  controller: widget.controller,
                  initialValue: widget.initialValue,
                  obscureText: widget.obscureText,
                  keyboardType: widget.keyboardType,
                  onChanged: widget.onChanged,
                  validator: widget.validator,
                  maxLines: widget.maxLines,
                  autofocus: widget.autofocus,
                  focusNode: _focusNode,
                  style: GoogleFonts.inter(fontSize: 14, color: text1),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: GoogleFonts.inter(fontSize: 14, color: text3),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              if (widget.suffix != null)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: widget.suffix!,
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

// ── KPI Card ───────────────────────────────────────────────────────────
class KpiCard extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final String? change;
  final Color? valueColor;
  final Color? accentColor;
  final VoidCallback? onTap;
  final List<Color>? gradientColors;
  final EdgeInsets? padding;

  const KpiCard({
    super.key,
    required this.emoji,
    required this.value,
    required this.label,
    this.change,
    this.valueColor,
    this.accentColor,
    this.onTap,
    this.gradientColors,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final t3 = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

    Widget valueWidget;
    if (gradientColors != null) {
      valueWidget = GradientText(
        value,
        style: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
          height: 1,
        ),
        colors: gradientColors!,
      );
    } else {
      valueWidget = Text(
        value,
        style: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: valueColor ?? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
          letterSpacing: -0.5,
          height: 1,
        ),
      );
    }

    return AppCard(
      onTap: onTap,
      borderColor: accentColor?.withValues(alpha: 0.25),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              if (change != null)
                Text(
                  change!,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: accentColor ?? t3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          valueWidget,
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: accentColor ?? t2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty State ────────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Loading Widget ─────────────────────────────────────────────────────
class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.accent,
        strokeWidth: 2.5,
      ),
    );
  }
}

// ── Pulsing Skeleton Loader ─────────────────────────────────────────────
class PulsingSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const PulsingSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  @override
  State<PulsingSkeleton> createState() => _PulsingSkeletonState();
}

class _PulsingSkeletonState extends State<PulsingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.12, end: 0.25).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white : Colors.black;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: _animation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

class CardSkeleton extends StatelessWidget {
  const CardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? AppColors.surfDark : AppColors.surfLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surf,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PulsingSkeleton(width: 44, height: 44, borderRadius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PulsingSkeleton(width: 140, height: 16),
                    const SizedBox(height: 6),
                    const PulsingSkeleton(width: 90, height: 12),
                  ],
                ),
              ),
              const PulsingSkeleton(width: 50, height: 14),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              PulsingSkeleton(width: 100, height: 14),
              PulsingSkeleton(width: 80, height: 18),
            ],
          ),
        ],
      ),
    );
  }
}

class ListSkeleton extends StatelessWidget {
  final int count;
  const ListSkeleton({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: const CardSkeleton(),
      ),
    );
  }
}

class GoldGradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextAlign textAlign;

  const GoldGradientText(
    this.text, {
    super.key,
    required this.style,
    this.textAlign = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark
        ? [const Color(0xFFF5A623), const Color(0xFFFFD080), const Color(0xFFF5A623)]
        : [const Color(0xFFD97706), const Color(0xFFF59E0B), const Color(0xFFD97706)];

    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & bounds.size),
      child: Text(
        text,
        style: style.copyWith(color: Colors.white),
        textAlign: textAlign,
      ),
    );
  }
}

class GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final List<Color> colors;
  final TextAlign textAlign;

  const GradientText(
    this.text, {
    super.key,
    required this.style,
    required this.colors,
    this.textAlign = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & bounds.size),
      child: Text(
        text,
        style: style.copyWith(color: Colors.white),
        textAlign: textAlign,
      ),
    );
  }
}

class GoldButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double? width;
  final double height;
  final double borderRadius;

  const GoldButton({
    super.key,
    required this.child,
    this.onPressed,
    this.width,
    this.height = 48,
    this.borderRadius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark
        ? [const Color(0xFFF5A623), const Color(0xFFD4791A)]
        : [const Color(0xFFD97706), const Color(0xFFB45309)];
    final glow = isDark
        ? const Color(0x59F5A623)
        : const Color(0x40D97706);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: onPressed == null
            ? []
            : [
                BoxShadow(
                  color: glow,
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: const Color(0xFF1A0F00),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          padding: EdgeInsets.zero,
        ),
        child: child,
      ),
    );
  }
}

