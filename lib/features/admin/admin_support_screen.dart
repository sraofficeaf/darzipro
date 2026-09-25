import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/theme_extensions.dart';
import 'widgets/admin_ui_kit.dart';

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
    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Header ───────────────────────────────────────────────────
            const AdminPageHeader(
              title: 'Help & Business Logic Reference',
              subtitle: 'Internal cheat sheet & quick reference for Darzi Pro system mechanics, tier rules, and profit logic',
            ),

            // ── Reference Cards Content ──────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Section 1: Subscription Plans & Level Unlocks
                  _buildCheatSection(
                    context,
                    sectionId: 1,
                    icon: Icons.workspace_premium_rounded,
                    iconColor: AdminColors.amber,
                    title: '1. Subscription Plans & Invite Level Unlocks',
                    subtitle: 'Current subscription plans, pricing, and how deep each plan unlocks earning levels',
                    content: Column(
                      children: const [
                        _DetailRowItem(
                          title: '⏳ Free Trial (14 Days / 20 Orders)',
                          detail: 'invite_level_unlocked = 1 · 10 MB storage. Full feature testing before choosing a plan.',
                        ),
                        SizedBox(height: 8),
                        _DetailRowItem(
                          title: '⚡ Basic Plan (Rs 500/mo)',
                          detail: 'invite_level_unlocked = 1 · Earns Level 1 (15%) direct invites. 20 MB storage.',
                        ),
                        SizedBox(height: 8),
                        _DetailRowItem(
                          title: '🚀 Standard Plan (Rs 1,500/mo)',
                          detail: 'invite_level_unlocked = 2 · Earns 2 levels deep: L1 (15%) & L2 (2.5%). 50 MB storage.',
                        ),
                        SizedBox(height: 8),
                        _DetailRowItem(
                          title: '💎 Unlimited Plan (Rs 2,500/mo)',
                          detail: 'invite_level_unlocked = 4 · Earns all 4 levels: L1 (15%), L2 (2.5%), L3 (1.5%), L4 (1.0%). 100 MB storage.',
                        ),
                        SizedBox(height: 8),
                        _DetailRowItem(
                          title: '👑 Founding Member Plan (Rs 35,000 one-time fee)',
                          detail: 'First 6 months free, then locked monthly rate · Unlimited orders & customers · 5 GB storage · Earns all 4 levels deep.',
                        ),
                        SizedBox(height: 8),
                        _DetailRowItem(
                          title: '👑 Lifetime Access (Grandfathered Legacy)',
                          detail: 'invite_level_unlocked = 4 · Grandfathered shops from legacy pricing with permanent unlimited access.',
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
                    iconColor: AdminColors.emerald,
                    title: '2. Multi-Level Invite Percentage Breakdown',
                    subtitle: 'Profit percentage per level & the depth eligibility rule',
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.surface2,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: context.border.withValues(alpha: 0.6)),
                          ),
                          child: Column(
                            children: const [
                              _RuleRow('Level 1 (Direct Inviter)', '15.0%'),
                              Divider(height: 12),
                              _RuleRow('Level 2 (2nd Generation)', '2.5%'),
                              Divider(height: 12),
                              _RuleRow('Level 3 (3rd Generation)', '1.5%'),
                              Divider(height: 12),
                              _RuleRow('Level 4 (4th Generation)', '1.0%'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const AdminInfoBox(
                          text: '💡 Core Rule: YOUR OWN plan tier decides how deep you earn in the invite chain, up to your invite_level_unlocked. (e.g. A Mobile Only user earns 0% from Level 2-4 downlines).',
                          color: AdminColors.blue,
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
                    iconColor: AdminColors.blue,
                    title: '3. Subscription Upgrades & Billing Cycles',
                    subtitle: 'How shops upgrade plans and transition between tiers',
                    content: Column(
                      children: const [
                        _DetailRowItem(
                          title: 'Trial ➔ Any Paid Plan',
                          detail: 'Shops can upgrade at any time during or after trial. Selecting Basic, Standard, Unlimited, or Founding activates the chosen subscription upon payment confirmation.',
                        ),
                        SizedBox(height: 8),
                        _DetailRowItem(
                          title: 'Basic ➔ Standard / Unlimited',
                          detail: 'Month-to-month subscription upgrade. Higher plans immediately unlock higher order/customer limits and deeper multi-level invite profit depth.',
                        ),
                        SizedBox(height: 8),
                        _DetailRowItem(
                          title: 'Founding Member Activation',
                          detail: 'Shops pay the one-time Rs 35,000 activation fee, receiving 6 months free subscription + 5 GB storage + VIP status badge.',
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
                    iconColor: AdminColors.violet,
                    title: '4. Storage Add-on System & Free Allowance',
                    subtitle: 'Bundled storage limits, add-on pricing, and lifetime rules',
                    content: Column(
                      children: const [
                        _DetailRowItem(
                          title: '📦 Plan Storage Allowance (Configurable per Plan)',
                          detail: 'Every plan receives its own storage allowance configured in Subscription Plans (Trial 100 MB, Basic 250 MB, Standard 1 GB, Unlimited 3 GB, Founding 5 GB).',
                        ),
                        SizedBox(height: 8),
                        _DetailRowItem(
                          title: '💳 Monthly Add-on (+1 GB @ Rs 250/mo)',
                          detail: 'Adds +1 GB storage to the plan allowance for 30 days. Configurable in App Settings.',
                        ),
                        SizedBox(height: 8),
                        _DetailRowItem(
                          title: '📅 Annual Add-on (+1 GB @ Rs 2,500/yr)',
                          detail: 'Adds +1 GB storage to the plan allowance for 365 days. Configurable in App Settings.',
                        ),
                        SizedBox(height: 8),
                        _DetailRowItem(
                          title: '💎 Legacy Bundled Storage',
                          detail: 'Preserved for grandfathered legacy shops until expiration; all shops can add monthly or annual storage add-ons at any time.',
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
                    iconColor: AdminColors.rose,
                    title: '5. Approvals Queue & Automatic Profit Trigger',
                    subtitle: 'What happens when admin approves requests in the Approvals queue',
                    content: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.surface2,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.border.withValues(alpha: 0.6)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('When Admin clicks "Approve" in Approvals Queue:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: context.text1)),
                          const SizedBox(height: 6),
                          Text('1. License Status & Dates: License status becomes active, plan tier updated, and expiration date set.', style: GoogleFonts.inter(fontSize: 11.5, color: context.text2)),
                          const SizedBox(height: 4),
                          Text('2. Agency Attribution: System checks whether the shop is registered under an active Agency (agency_shop_id).', style: GoogleFonts.inter(fontSize: 11.5, color: context.text2)),
                          const SizedBox(height: 4),
                          Text('3. Agency Profit Calculation: The agency earns their assigned percentage on the payment, recorded into agency_earnings.', style: GoogleFonts.inter(fontSize: 11.5, color: context.text2)),
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
                    iconColor: AdminColors.amber,
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

                  // Section 7: Platform Access Logic
                  _buildCheatSection(
                    context,
                    sectionId: 7,
                    icon: Icons.devices_rounded,
                    iconColor: AdminColors.indigo,
                    title: '7. Platform Access & Cross-Device Sync',
                    subtitle: 'Device support and multi-platform access rules across plans',
                    content: Column(
                      children: const [
                        _DetailRowItem(
                          title: '📱 Cross-Platform Access (All Plans)',
                          detail: 'All active subscription plans (Trial, Basic, Standard, Unlimited, Founding, and Lifetime) enjoy full access across Windows Desktop, Web Browser, Android, and iOS applications.',
                        ),
                        SizedBox(height: 8),
                        _DetailRowItem(
                          title: '🔒 Subscription Status Enforcements',
                          detail: 'Active & Grace Period: full read/write access. Read-Only mode: shops past grace period can view and search existing customer records and orders, but cannot create new data until renewing.',
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

    return RepaintBoundary(
      child: Container(
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
          Text(percent, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AdminColors.emerald)),
        ],
      ),
    );
  }
}

