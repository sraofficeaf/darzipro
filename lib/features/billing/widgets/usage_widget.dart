import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../shared/providers/subscription_provider.dart';
import '../../../shared/providers/supabase_providers.dart';

/// Compact usage widget for the Dashboard.
/// Full version for the Subscription Plan screen.
class UsageWidget extends ConsumerWidget {
  final bool compact;
  const UsageWidget({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(subscriptionStateProvider);
    final shopAsync = ref.watch(currentShopProvider);
    final storageLimitMb =
        ref.watch(shopStorageAllowanceProvider).valueOrNull ?? 0;

    return subAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (sub) {
        // Lifetime shops: no usage widget needed
        if (sub.isLifetime) return const SizedBox.shrink();

        final isUrdu = Localizations.localeOf(context).languageCode == 'ur';
        final storageUsedBytes =
            (shopAsync.value?['storage_used_bytes'] as int?) ?? 0;
        return compact
            ? _CompactUsage(
                sub: sub,
                isUrdu: isUrdu,
                storageUsedBytes: storageUsedBytes,
                storageLimitMb: storageLimitMb,
              )
            : _FullUsage(
                sub: sub,
                isUrdu: isUrdu,
                storageUsedBytes: storageUsedBytes,
                storageLimitMb: storageLimitMb,
              );
      },
    );
  }
}

// ── Compact version for Dashboard ──────────────────────────────────────────

class _CompactUsage extends StatelessWidget {
  final SubscriptionState sub;
  final bool isUrdu;
  final int storageUsedBytes;
  final int storageLimitMb;
  const _CompactUsage({
    required this.sub,
    required this.isUrdu,
    required this.storageUsedBytes,
    required this.storageLimitMb,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final surface = isDark ? const Color(0x0DFFFFFF) : Colors.white;
    final border = isDark ? const Color(0x12FFFFFF) : const Color(0xFFE2E8F0);
    final text1 = context.text1;
    final text2 = context.text2;

    final driving = sub.drivingMetric;
    final isApproaching = sub.isApproachingLimit;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isApproaching
              ? AppColors.accent.withValues(alpha: 0.4)
              : border,
          width: isApproaching ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isUrdu ? sub.planNameUr : sub.planNameEn,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
              const Spacer(),
              if (sub.cycleEnd != null)
                Text(
                  DateFormat('dd MMM').format(sub.cycleEnd!),
                  style: GoogleFonts.inter(fontSize: 10, color: text2),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Orders progress
          if (sub.maxOrders != null) ...[
            _MiniProgressRow(
              label: isUrdu ? 'آرڈر' : 'Orders',
              used: sub.ordersUsed,
              max: sub.maxOrders,
              progress: sub.ordersProgress,
              isDriving: driving == 'orders',
              color: AppColors.blue,
              text1: text1,
            ),
            const SizedBox(height: 6),
          ],

          // Customers progress
          if (sub.maxCustomers != null) ...[
            _MiniProgressRow(
              label: isUrdu ? 'گاہک' : 'Customers',
              used: sub.activeCustomers,
              max: sub.maxCustomers,
              progress: sub.customersProgress,
              isDriving: driving == 'customers',
              color: AppColors.teal,
              text1: text1,
            ),
          ],

          // Storage progress
          if (storageLimitMb > 0) ...[
            const SizedBox(height: 6),
            _StorageMiniRow(
              usedBytes: storageUsedBytes,
              limitMb: storageLimitMb,
              isUrdu: isUrdu,
              text1: text1,
            ),
          ],

          // 85% warning
          if (isApproaching) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isUrdu
                    ? '⚠️ Aap apni limit ke qareeb hain'
                    : '⚠️ Approaching your plan limit',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Full version for Plan & Billing screen ──────────────────────────────────

class _FullUsage extends StatelessWidget {
  final SubscriptionState sub;
  final bool isUrdu;
  final int storageUsedBytes;
  final int storageLimitMb;
  const _FullUsage({
    required this.sub,
    required this.isUrdu,
    required this.storageUsedBytes,
    required this.storageLimitMb,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final surface = isDark ? const Color(0x0DFFFFFF) : Colors.white;
    final border = isDark ? const Color(0x12FFFFFF) : const Color(0xFFE2E8F0);
    final text1 = context.text1;
    final text2 = context.text2;
    final text3 = context.text3;

    final driving = sub.drivingMetric;
    final isApproaching = sub.isApproachingLimit;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isApproaching
              ? AppColors.accent.withValues(alpha: 0.4)
              : border,
          width: isApproaching ? 1.5 : 1,
        ),
        boxShadow: context.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isUrdu ? 'Aapka Plan' : 'Your Plan',
                      style: GoogleFonts.inter(fontSize: 11, color: text3, fontWeight: FontWeight.w600, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          isUrdu ? sub.planNameUr : sub.planNameEn,
                          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: text1),
                        ),
                        const SizedBox(width: 8),
                        if (sub.planPricePkr > 0)
                          Text(
                            sub.isFounding
                                ? 'Rs ${NumberFormat('#,###').format(sub.planPricePkr)} one-time'
                                : (isUrdu
                                    ? 'Rs ${NumberFormat('#,###').format(sub.planPricePkr)}/mahina'
                                    : 'Rs ${NumberFormat('#,###').format(sub.planPricePkr)}/mo'),
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.accent, fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Status badge
              _StatusBadge(status: sub.subscriptionStatus, isUrdu: isUrdu),
            ],
          ),

          const SizedBox(height: 20),

          // Orders metric
          if (sub.maxOrders != null) ...[
            _FullProgressRow(
              label: isUrdu ? 'Is mahine ke orders' : 'Orders this cycle',
              used: sub.ordersUsed,
              max: sub.maxOrders!,
              progress: sub.ordersProgress,
              isDriving: driving == 'orders',
              color: AppColors.blue,
              isUrdu: isUrdu,
              text1: text1,
              text2: text2,
            ),
            const SizedBox(height: 16),
          ] else ...[
            _UnlimitedRow(
              label: isUrdu ? 'Orders' : 'Orders',
              value: sub.ordersUsed,
              text1: text1,
              text2: text2,
            ),
            const SizedBox(height: 16),
          ],

          // Active customers metric
          if (sub.maxCustomers != null) ...[
            _FullProgressRow(
              label: isUrdu ? 'Active customers' : 'Active customers',
              used: sub.activeCustomers,
              max: sub.maxCustomers!,
              progress: sub.customersProgress,
              isDriving: driving == 'customers',
              color: AppColors.teal,
              isUrdu: isUrdu,
              text1: text1,
              text2: text2,
            ),
          ] else ...[
            _UnlimitedRow(
              label: isUrdu ? 'Active customers' : 'Active customers',
              value: sub.activeCustomers,
              text1: text1,
              text2: text2,
            ),
          ],

          // Storage progress
          if (storageLimitMb > 0) ...[
            const SizedBox(height: 16),
            _StorageFullRow(
              usedBytes: storageUsedBytes,
              limitMb: storageLimitMb,
              isUrdu: isUrdu,
              text1: text1,
              text2: text2,
            ),
          ],

          // 85% warning
          if (isApproaching) ...[
            const SizedBox(height: 16),
            _ApproachingWarning(sub: sub, isUrdu: isUrdu),
          ],

          // Billing info
          if (sub.cycleEnd != null && !sub.isTrial) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isUrdu ? 'Agla bill' : 'Next billing date',
                  style: GoogleFonts.inter(fontSize: 13, color: text2),
                ),
                Text(
                  '${DateFormat('dd MMM yyyy').format(sub.cycleEnd!)} — Rs ${NumberFormat('#,###').format(sub.planPricePkr)}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: text1,
                  ),
                ),
              ],
            ),
          ],

          // Trial info
          if (sub.isTrial) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            _TrialInfo(sub: sub, isUrdu: isUrdu, text2: text2),
          ],
        ],
      ),
    );
  }
}

// ── Sub-widgets ─────────────────────────────────────────────────────────────

class _MiniProgressRow extends StatelessWidget {
  final String label;
  final int used;
  final int? max;
  final double progress;
  final bool isDriving;
  final Color color;
  final Color text1;

  const _MiniProgressRow({
    required this.label,
    required this.used,
    required this.max,
    required this.progress,
    required this.isDriving,
    required this.color,
    required this.text1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$label: $used / ${max ?? '∞'}',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: isDriving ? AppColors.accent : text1,
                fontWeight: isDriving ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (isDriving) ...[
              const SizedBox(width: 4),
              Text('★', style: TextStyle(fontSize: 9, color: AppColors.accent)),
            ],
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withValues(alpha: 0.12),
            color: isDriving ? AppColors.accent : color,
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}

class _FullProgressRow extends StatelessWidget {
  final String label;
  final int used;
  final int max;
  final double progress;
  final bool isDriving;
  final Color color;
  final bool isUrdu;
  final Color text1;
  final Color text2;

  const _FullProgressRow({
    required this.label,
    required this.used,
    required this.max,
    required this.progress,
    required this.isDriving,
    required this.color,
    required this.isUrdu,
    required this.text1,
    required this.text2,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isDriving ? AppColors.accent : color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDriving ? activeColor : text2,
                    fontWeight: isDriving ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (isDriving) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      isUrdu
                          ? 'yeh aapka plan decide kar raha hai'
                          : 'Driving your plan',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Text(
              '$used / $max',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDriving ? activeColor : text1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: activeColor.withValues(alpha: 0.10),
            color: progress >= 0.85
                ? AppColors.accent
                : activeColor,
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

class _UnlimitedRow extends StatelessWidget {
  final String label;
  final int value;
  final Color text1;
  final Color text2;
  const _UnlimitedRow({required this.label, required this.value, required this.text1, required this.text2});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: text2)),
        Row(
          children: [
            Text(
              '$value',
              style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w600, color: text1),
            ),
            const SizedBox(width: 4),
            Text(
              '/ ∞',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.teal),
            ),
          ],
        ),
      ],
    );
  }
}

class _ApproachingWarning extends StatelessWidget {
  final SubscriptionState sub;
  final bool isUrdu;
  const _ApproachingWarning({required this.sub, required this.isUrdu});

  @override
  Widget build(BuildContext context) {
    final driving = sub.drivingMetric;
    String message;
    if (driving == 'orders' && sub.maxOrders != null) {
      final remaining = sub.maxOrders! - sub.ordersUsed;
      message = isUrdu
          ? '⚠️ Sirf $remaining orders baqi hain (${sub.ordersUsed}/${sub.maxOrders}). Limit ke baad plan khud-ba-khud upgrade ho jayega.'
          : '⚠️ Only $remaining orders left (${sub.ordersUsed}/${sub.maxOrders}). Your plan will auto-upgrade when reached.';
    } else if (driving == 'customers' && sub.maxCustomers != null) {
      message = isUrdu
          ? '⚠️ Aap customer limit ke qareeb hain (${sub.activeCustomers}/${sub.maxCustomers}). Limit ke baad aapka plan khud-ba-khud upgrade ho jayega.'
          : '⚠️ You\'re near your customer limit (${sub.activeCustomers}/${sub.maxCustomers}). Your plan will auto-upgrade when reached.';
    } else {
      message = isUrdu
          ? '⚠️ Aap apni plan limit ke qareeb hain.'
          : '⚠️ You\'re approaching your plan limit.';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: AppColors.accent,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
      ),
    );
  }
}

class _TrialInfo extends StatelessWidget {
  final SubscriptionState sub;
  final bool isUrdu;
  final Color text2;
  const _TrialInfo({required this.sub, required this.isUrdu, required this.text2});

  @override
  Widget build(BuildContext context) {
    final ordersLeft = sub.trialOrdersRemaining;
    final daysLeft = sub.trialDaysRemaining;

    return Row(
      children: [
        const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.accent),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            isUrdu
                ? 'Trial: ${ordersLeft != null ? "$ordersLeft orders" : ""} ${daysLeft != null ? "ya $daysLeft din" : ""} baaqi'
                : 'Trial: ${ordersLeft != null ? "$ordersLeft orders" : ""} ${daysLeft != null ? "or $daysLeft days" : ""} remaining',
            style: GoogleFonts.inter(fontSize: 12, color: text2),
          ),
        ),
      ],
    );
  }
}

// ── Storage progress helpers ────────────────────────────────────────────────

/// Formats raw bytes → human-readable string: "X.X MB" or "X.X GB".
String _fmtBytes(int bytes) {
  final mb = bytes / (1024 * 1024);
  if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(1)} GB';
  return '${mb.toStringAsFixed(1)} MB';
}

/// Formats a limit in MB → "X GB" or "X MB" (clean integer where possible).
String _fmtLimitMb(int mb) {
  if (mb >= 1024 && mb % 1024 == 0) return '${mb ~/ 1024} GB';
  if (mb >= 1000 && mb % 1000 == 0) return '${mb ~/ 1000} GB';
  return '$mb MB';
}

class _StorageMiniRow extends StatelessWidget {
  final int usedBytes;
  final int limitMb;
  final bool isUrdu;
  final Color text1;

  const _StorageMiniRow({
    required this.usedBytes,
    required this.limitMb,
    required this.isUrdu,
    required this.text1,
  });

  @override
  Widget build(BuildContext context) {
    final limitBytes = limitMb * 1024 * 1024;
    final progress = limitBytes > 0
        ? (usedBytes / limitBytes).clamp(0.0, 1.0)
        : 0.0;
    final color = progress >= 0.9
        ? AppColors.accent
        : const Color(0xFF7C6AFF); // indigo-ish
    final label = isUrdu ? 'اسٹوریج' : 'Storage';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ${_fmtBytes(usedBytes)} / ${_fmtLimitMb(limitMb)}',
          style: GoogleFonts.inter(
            fontSize: 10,
            color: text1,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withValues(alpha: 0.12),
            color: color,
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}

class _StorageFullRow extends StatelessWidget {
  final int usedBytes;
  final int limitMb;
  final bool isUrdu;
  final Color text1;
  final Color text2;

  const _StorageFullRow({
    required this.usedBytes,
    required this.limitMb,
    required this.isUrdu,
    required this.text1,
    required this.text2,
  });

  @override
  Widget build(BuildContext context) {
    final limitBytes = limitMb * 1024 * 1024;
    final progress = limitBytes > 0
        ? (usedBytes / limitBytes).clamp(0.0, 1.0)
        : 0.0;
    final color = progress >= 0.9
        ? AppColors.accent
        : const Color(0xFF7C6AFF);
    final label = isUrdu ? 'اسٹوریج' : 'Storage';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: text2,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${_fmtBytes(usedBytes)} / ${_fmtLimitMb(limitMb)}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: text1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withValues(alpha: 0.10),
            color: progress >= 0.9 ? AppColors.accent : color,
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final bool isUrdu;
  const _StatusBadge({required this.status, required this.isUrdu});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'active':
        color = AppColors.teal;
        label = isUrdu ? '✅ Active' : '✅ Active';
        break;
      case 'trial':
        color = AppColors.accent;
        label = isUrdu ? '🆓 Trial' : '🆓 Trial';
        break;
      case 'grace':
        color = AppColors.accent;
        label = isUrdu ? '⏳ Grace' : '⏳ Grace';
        break;
      case 'read_only':
        color = AppColors.red;
        label = isUrdu ? '🔒 Bnd' : '🔒 Suspended';
        break;
      case 'expiring':
        color = AppColors.accent;
        label = isUrdu ? '⏰ Renew' : '⏰ Renewal Due';
        break;
      case 'lifetime':
        color = AppColors.teal;
        label = '👑 Lifetime';
        break;
      default:
        color = AppColors.blue;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
