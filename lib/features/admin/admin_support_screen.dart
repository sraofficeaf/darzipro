import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_extensions.dart';

class AdminSupportScreen extends StatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  State<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends State<AdminSupportScreen> {
  // Track open state for expandable cheat sheet cards (all open by default for easy scanning)
  final Map<int, bool> _expandedSections = {
    1: true,
    2: true,
    3: true,
    4: true,
    5: true,
    6: true,
    7: true,
  };

  void _toggleSection(int sectionId) {
    setState(() {
      _expandedSections[sectionId] = !(_expandedSections[sectionId] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bg = context.bg;
    final surface = context.surface;
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Header ───────────────────────────────────────────────────
            Container(
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
                      children: [
                        Text(
                          '📖 Help & Business Logic Reference',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: text1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Internal cheat sheet & quick reference for Darzi Pro system mechanics, tier rules, and profit logic',
                          style: GoogleFonts.inter(fontSize: 12, color: text2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Reference Cards Content ──────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Section 1: Registration Tiers & Level Unlocks
                  _buildCheatSection(
                    context,
                    sectionId: 1,
                    icon: Icons.workspace_premium_rounded,
                    iconColor: AppColors.accent,
                    title: '1. Registration Tiers & Invite Level Unlocks',
                    subtitle: 'Base plan prices and how deep each plan unlocks earning levels',
                    content: Column(
                      children: const [
                        _DetailRowItem(
                          title: '📱 Mobile Only Plan (Rs 12,000)',
                          detail: 'invite_level_unlocked = 1 · Earns Level 1 (15%) direct invites only.',
                        ),
                        SizedBox(height: 8),
                        _DetailRowItem(
                          title: '⭐ Full Access Plan (Rs 35,000)',
                          detail: 'invite_level_unlocked = 2 · Earns 2 levels deep: Level 1 (15%) & Level 2 (2.5%).',
                        ),
                        SizedBox(height: 8),
                        _DetailRowItem(
                          title: '💎 Full Access + 3yr Plan (Rs 70,000)',
                          detail: 'invite_level_unlocked = 4 · Earns all 4 levels deep: L1 (15%), L2 (2.5%), L3 (1.5%), L4 (1.0%). Includes 3-year bundled storage.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Section 2: 4-Level Invite Profit Breakdown
                  _buildCheatSection(
                    context,
                    sectionId: 2,
                    icon: Icons.account_tree_rounded,
                    iconColor: const Color(0xFF10CBA0),
                    title: '2. Multi-Level Invite Percentage Breakdown',
                    subtitle: 'Commission percentage per level & the depth eligibility rule',
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.surface2,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: const [
                              _RuleRow('Level 1 (Direct Inviter)', '15.0%'),
                              Divider(),
                              _RuleRow('Level 2 (2nd Generation)', '2.5%'),
                              Divider(),
                              _RuleRow('Level 3 (3rd Generation)', '1.5%'),
                              Divider(),
                              _RuleRow('Level 4 (4th Generation)', '1.0%'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '💡 Core Rule: YOUR OWN plan tier decides how deep you earn in the invite chain, up to your invite_level_unlocked. (e.g. A Mobile Only user earns 0% from Level 2-4 downlines).',
                            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: text1, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Section 3: Upgrade Request Paths
                  _buildCheatSection(
                    context,
                    sectionId: 3,
                    icon: Icons.upgrade_rounded,
                    iconColor: const Color(0xFF3B82F6),
                    title: '3. Upgrade Request Paths & Differential Fees',
                    subtitle: 'Exact payment differences when shops upgrade their active plan',
                    content: Column(
                      children: const [
                        _DetailRowItem(
                          title: 'Mobile Only ➔ Full Access',
                          detail: 'Difference Fee: Rs 23,000 (Rs 35,000 - Rs 12,000). Updates invite_level_unlocked from 1 to 2.',
                        ),
                        SizedBox(height: 8),
                        _DetailRowItem(
                          title: 'Mobile Only ➔ Full Access + 3yr',
                          detail: 'Difference Fee: Rs 58,000 (Rs 70,000 - Rs 12,000). Updates invite_level_unlocked from 1 to 4.',
                        ),
                        SizedBox(height: 8),
                        _DetailRowItem(
                          title: 'Full Access ➔ Full Access + 3yr',
                          detail: 'Difference Fee: Rs 35,000 (Rs 70,000 - Rs 35,000). Updates invite_level_unlocked from 2 to 4.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Section 4: Storage Add-on System
                  _buildCheatSection(
                    context,
                    sectionId: 4,
                    icon: Icons.cloud_done_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    title: '4. Storage Add-on System & Free Allowance',
                    subtitle: 'Bundled storage limits, add-on pricing, and lifetime rules',
                    content: Column(
                      children: const [
                        _DetailRowItem(
                          title: '📦 Free Base Allowance (1.5 MB)',
                          detail: 'Every base license gets 1.5 MB free storage for suit designs & customer media.',
                        ),
                        SizedBox(height: 8),
                        _DetailRowItem(
                          title: '💳 Monthly Add-on (Rs 1,200/mo)',
                          detail: 'Provides extra storage for 30 days. Triggers Level 1 commission of Rs 180 (15%) for inviter.',
                        ),
                        SizedBox(height: 8),
                        _DetailRowItem(
                          title: '📅 Annual Add-on (Rs 10,000/yr)',
                          detail: 'Provides extra storage for 365 days. Triggers Level 1 commission of Rs 1,500 (15%) for inviter.',
                        ),
                        SizedBox(height: 8),
                        _DetailRowItem(
                          title: '💎 3-Year Bundled Storage',
                          detail: 'Included bundled automatically with Full Access + 3yr tier for 1,095 days.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Section 5: Approvals Queue & Multi-Level Profit Trigger
                  _buildCheatSection(
                    context,
                    sectionId: 5,
                    icon: Icons.published_with_changes_rounded,
                    iconColor: const Color(0xFFEC4899),
                    title: '5. Approvals Queue & Automatic Profit Trigger',
                    subtitle: 'What happens when admin approves requests in the Approvals queue',
                    content: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.surface2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('When Admin clicks "Approve" in Approvals Queue:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: text1)),
                          const SizedBox(height: 6),
                          Text('1. License Status & Dates: License status becomes active, plan tier updated, and expiration date set.', style: GoogleFonts.inter(fontSize: 11.5, color: text2)),
                          const SizedBox(height: 4),
                          Text('2. Upline Chain Scan: System checks invited_by_code up to 4 levels up.', style: GoogleFonts.inter(fontSize: 11.5, color: text2)),
                          const SizedBox(height: 4),
                          Text('3. Profit Calculation: For each qualified upline shop (invite_level_unlocked >= current_level), 15%/2.5%/1.5%/1.0% profit is calculated and added to profit_earnings as pending.', style: GoogleFonts.inter(fontSize: 11.5, color: text2)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Section 6: Payout Threshold & Payout Delay Settings
                  _buildCheatSection(
                    context,
                    sectionId: 6,
                    icon: Icons.payments_rounded,
                    iconColor: const Color(0xFFF5A623),
                    title: '6. Payout Threshold & Payout Delay Rules',
                    subtitle: 'How Minimum Threshold and Delay Days work together in payout processing',
                    content: Column(
                      children: const [
                        _DetailRowItem(
                          title: '💵 Minimum Payout Threshold (default Rs 1,000)',
                          detail: 'Configurable in Admin Settings. Shops must accumulate at least this total amount in eligible pending earnings before a payout batch is created.',
                        ),
                        SizedBox(height: 8),
                        _DetailRowItem(
                          title: '⏳ Payout Delay Days (default 0 days)',
                          detail: 'Configurable in Admin Settings. Rolling age filter based on each earning\'s earned_at timestamp. Only earnings where earned_at <= (now - delay_days) count toward payout.',
                        ),
                        SizedBox(height: 8),
                        _DetailRowItem(
                          title: '📊 Combined Behavior',
                          detail: 'Available Balance (ready now) includes earnings past the delay period. Aging Balance (ready soon) includes earnings still within the delay window.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Section 7: Platform Restriction Logic
                  _buildCheatSection(
                    context,
                    sectionId: 7,
                    icon: Icons.devices_rounded,
                    iconColor: const Color(0xFF6366F1),
                    title: '7. Platform Access Restriction Logic',
                    subtitle: 'Which plans can log in to Mobile, Web, or Windows Desktop apps',
                    content: Column(
                      children: const [
                        _DetailRowItem(
                          title: '📱 Mobile Only Plan Restrictions',
                          detail: 'Restricted exclusively to Mobile Android/iOS apps. Attempting to log into Windows Desktop or Web app triggers the check-platform-access gate, blocking entry with an upgrade prompt.',
                        ),
                        SizedBox(height: 8),
                        _DetailRowItem(
                          title: '💻 Full Access & Full Access + 3yr Plans',
                          detail: 'Full cross-platform access. Can log in seamlessly across Windows Desktop, Web Browser, Android, and iOS apps.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheatSection(
    BuildContext context, {
    required int sectionId,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget content,
  }) {
    final isOpen = _expandedSections[sectionId] ?? true;
    final surface = context.surface;
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: context.cardShadow,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleSection(sectionId),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: text1),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(fontSize: 11.5, color: text2),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: text2,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: content,
            ),
            crossFadeState: isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

class _DetailRowItem extends StatelessWidget {
  final String title;
  final String detail;

  const _DetailRowItem({required this.title, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: context.text1)),
          const SizedBox(height: 3),
          Text(detail, style: GoogleFonts.inter(fontSize: 11.5, color: context.text2, height: 1.4)),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  final String level;
  final String percent;

  const _RuleRow(this.level, this.percent);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(level, style: GoogleFonts.inter(fontSize: 12, color: context.text2)),
          Text(percent, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent)),
        ],
      ),
    );
  }
}
