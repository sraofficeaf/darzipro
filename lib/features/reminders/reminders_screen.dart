import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/responsive/responsive.dart';
import '../../shared/providers/reminders_provider.dart';

// ── COLOR CONSTANTS (CACHED) ────────────────────────────────────────────────
class _RemColors {
  static const ink = Color(0xFF111827);
  static const muted = Color(0xFF7B8494);
  static const faint = Color(0xFFAAB2BF);
  static const line = Color(0xFFE8EAF0);
  static const paper = Color(0xFFF5F6F8);

  static const dark = Color(0xFF151922);
  static const darkCard = Color(0xFF181D27);
  static const darkLine = Color(0xFF333946);

  static const gold = Color(0xFFE9A227);
  static const goldBg = Color(0xFFFFF6E5);
  static const goldLine = Color(0xFFF3DDA8);

  static const green = Color(0xFF18B887);
  static const greenBg = Color(0xFFEAFBF5);
  static const greenLine = Color(0xFFCFEFE3);

  static const rose = Color(0xFFEF5261);
  static const roseBg = Color(0xFFFFF0F2);
  static const roseLine = Color(0xFFFFD9DE);
}

// ── REMINDERS SCREEN ────────────────────────────────────────────────────────
class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(remindersProvider);
    final isDesktop = Responsive.isDesktop(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? _RemColors.dark : _RemColors.paper;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 40 : 20,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. SCREEN HEAD
              RepaintBoundary(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NOTIFICATIONS',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                        color: _RemColors.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Reminders',
                              style: GoogleFonts.manrope(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.8,
                                color: isDark ? Colors.white : _RemColors.ink,
                              ),
                            ),
                            if (reminders.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _RemColors.roseBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${reminders.length}',
                                  style: GoogleFonts.ibmPlexMono(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: _RemColors.rose,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (reminders.isNotEmpty)
                          OutlinedButton(
                            onPressed: () {
                              ref.read(remindersProvider.notifier).clearAll();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white : _RemColors.ink,
                              backgroundColor:
                                  isDark ? _RemColors.darkCard : Colors.white,
                              side: BorderSide(
                                color: isDark ? _RemColors.darkLine : _RemColors.line,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                            ),
                            child: Text(
                              'Clear All',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Keep track of overdue deliveries, upcoming due orders, and ready-for-pickup items.',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _RemColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2. VIRTUALIZED REMINDERS LIST
              Expanded(
                child: reminders.isEmpty
                    ? _buildEmptyState(isDark)
                    : ListView.builder(
                        itemCount: reminders.length,
                        cacheExtent: 200,
                        itemBuilder: (context, index) {
                          final reminder = reminders[index];
                          return RepaintBoundary(
                            child: _buildReminderCard(context, ref, reminder, isDark),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReminderCard(
    BuildContext context,
    WidgetRef ref,
    ReminderModel reminder,
    bool isDark,
  ) {
    Color iconBg;
    Color iconBorder;
    Color accentColor;
    String iconEmoji;
    String titleText;
    String subText;

    if (reminder.type == 'overdue') {
      iconBg = isDark ? const Color(0x28EF5261) : _RemColors.roseBg;
      iconBorder = _RemColors.roseLine;
      accentColor = _RemColors.rose;
      iconEmoji = '🚨';
      titleText = 'Overdue: ${reminder.customerName}';
      subText = reminder.message;
    } else if (reminder.type == 'today') {
      iconBg = isDark ? const Color(0x28E9A227) : _RemColors.goldBg;
      iconBorder = _RemColors.goldLine;
      accentColor = _RemColors.gold;
      iconEmoji = '⏰';
      titleText = 'Due Today: ${reminder.customerName}';
      subText = 'Delivery scheduled for today';
    } else {
      iconBg = isDark ? const Color(0x2818B887) : _RemColors.greenBg;
      iconBorder = _RemColors.greenLine;
      accentColor = _RemColors.green;
      iconEmoji = '✅';
      titleText = 'Ready: ${reminder.customerName}';
      subText = 'Ready for pickup · Order ${reminder.tokenNumber}';
    }

    final cardBg = reminder.type == 'overdue'
        ? (isDark ? const Color(0x18EF5261) : const Color(0xFFFFF9FA))
        : (isDark ? _RemColors.darkCard : Colors.white);

    final cardBorder = reminder.type == 'overdue'
        ? _RemColors.roseLine
        : (isDark ? _RemColors.darkLine : _RemColors.line);

    return Dismissible(
      key: Key(reminder.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _RemColors.roseBg,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded, color: _RemColors.rose, size: 22),
      ),
      onDismissed: (_) {
        ref.read(remindersProvider.notifier).removeReminder(reminder.id);
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/orders/${reminder.orderId}');
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: cardBorder, width: 1.5),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.035),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // Left Accent Line
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 3.5,
                      color: accentColor,
                    ),
                  ),

                  // Card Content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        const SizedBox(width: 4),
                        // 44x44px Icon Container
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: iconBg,
                            border: Border.all(color: iconBorder, width: 1),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Center(
                            child: Text(
                              iconEmoji,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Title & Subtext
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                titleText,
                                style: GoogleFonts.manrope(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : _RemColors.ink,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                subText,
                                style: GoogleFonts.dmSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: _RemColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Time Ago & Dismiss Button
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _timeAgo(reminder.createdAt),
                              style: GoogleFonts.dmSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: _RemColors.faint,
                              ),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                ref
                                    .read(remindersProvider.notifier)
                                    .removeReminder(reminder.id);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? _RemColors.dark
                                      : const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: Text(
                                    '✕',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _RemColors.muted,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: isDark ? _RemColors.darkCard : _RemColors.paper,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                '🔔',
                style: TextStyle(fontSize: 34),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No reminders right now',
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : _RemColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Overdue deliveries and order alerts will appear here',
            style: GoogleFonts.dmSans(
              fontSize: 12.5,
              color: _RemColors.muted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
