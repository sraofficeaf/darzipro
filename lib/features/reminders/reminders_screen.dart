import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/theme_extensions.dart';
import '../../shared/providers/reminders_provider.dart';

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(remindersProvider);
    final isDesktop = Responsive.isDesktop(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : context.bg,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 40 : 20,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Text(
                    'Reminders',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: context.text1,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Count badge
                  if (reminders.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.redS,
                        border: Border.all(color: AppColors.redS, width: 1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${reminders.length}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.red,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Keep track of overdue deliveries, upcoming due orders, and items ready for customer pickup.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: context.text2,
                ),
              ),
              const SizedBox(height: 24),

              // Reminders list
              Expanded(
                child: reminders.isEmpty
                    ? _buildEmptyState(context)
                    : ListView.builder(
                        itemCount: reminders.length,
                        itemBuilder: (context, index) {
                          final reminder = reminders[index];
                          return _buildReminderCard(context, ref, reminder);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReminderCard(BuildContext context, WidgetRef ref, ReminderModel reminder) {
    Color boxBg;
    Color boxBorder;
    String iconEmoji;
    String titleText;
    String subText;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (reminder.type == 'overdue') {
      boxBg = isDark ? const Color(0x1AFF3A58) : AppColors.lightRedBg;
      boxBorder = isDark ? const Color(0x33FF3A58) : AppColors.lightRedBorder;
      iconEmoji = '🚨';
      titleText = 'Overdue: ${reminder.customerName}';
      subText = reminder.message;
    } else if (reminder.type == 'today') {
      boxBg = isDark ? const Color(0x1AF5A623) : AppColors.lightAccentBg;
      boxBorder = isDark ? const Color(0x33F5A623) : AppColors.lightAccentBorder;
      iconEmoji = '⏰';
      titleText = 'Due Today: ${reminder.customerName}';
      subText = 'Due today';
    } else { // ready
      boxBg = isDark ? const Color(0x1A10CBA0) : AppColors.lightTealBg;
      boxBorder = isDark ? const Color(0x3310CBA0) : AppColors.lightTealBorder;
      iconEmoji = '✅';
      titleText = 'Ready: ${reminder.customerName}';
      subText = 'Order ${reminder.tokenNumber}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x09FFFFFF) : context.surface,
        border: Border.all(color: isDark ? const Color(0x12FFFFFF) : context.border, width: 1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Dismissible(
          key: Key(reminder.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: isDark ? const Color(0x1AFF3A58) : AppColors.lightRedBg,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: Icon(
              Icons.delete_outline_rounded,
              color: isDark ? const Color(0xFFFF3A58) : AppColors.lightRed,
              size: 24,
            ),
          ),
          onDismissed: (direction) {
            ref.read(remindersProvider.notifier).removeReminder(reminder.id);
          },
          child: InkWell(
            onTap: () {
              context.push('/orders/${reminder.orderId}');
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Left icon box
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: boxBg,
                      border: Border.all(color: boxBorder, width: 1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        iconEmoji,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Center texts
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titleText,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.text1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subText,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: context.text2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Right time ago & dismiss
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _timeAgo(reminder.createdAt),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: context.text3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () {
                          ref.read(remindersProvider.notifier).removeReminder(reminder.id);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: context.text3,
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

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: isDark ? const Color(0x0AFFFFFF) : context.surface2,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                '🔔',
                style: TextStyle(fontSize: 32),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No reminders right now',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.text1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Overdue and upcoming deliveries will appear here',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: context.text2,
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
