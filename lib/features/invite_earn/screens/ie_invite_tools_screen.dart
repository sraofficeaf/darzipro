import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../shared/providers/invite_providers.dart';
import '../widgets/ie_earning_card.dart';
import 'ie_guide_screen.dart';

class IeInviteToolsScreen extends ConsumerWidget {
  const IeInviteToolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(inviteStatsProvider);
    final text1 = context.text1;
    final text2 = context.text2;
    final surface = context.surface;
    final border = context.border;

    return Scaffold(
      backgroundColor: context.bg,
      body: statsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: ieAccent)),
        error: (_, _) => const SizedBox.shrink(),
        data: (stats) {
          final inviteCode = stats['invite_code'] as String? ?? '';
          final inviteLink = inviteCode.isNotEmpty
              ? 'https://darzipro.pk/join?ref=$inviteCode'
              : 'https://darzipro.pk/join';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Invite Tools',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: text1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Share your unique code and earn on every signup!',
                            style: GoogleFonts.inter(fontSize: 12, color: text2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const IeGuideScreen()),
                        );
                      },
                      icon: const Icon(Icons.info_outline_rounded, size: 16),
                      label: const Text('How It Works'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ieAccent.withValues(alpha: 0.14),
                        foregroundColor: ieAccent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: ieAccentBorder),

                        ),
                        textStyle: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),


                // ── Compact Invite Code Box ──────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        ieAccent.withValues(alpha: 0.12),
                        ieAccent.withValues(alpha: 0.04),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ieAccentBorder, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: ieAccent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Center(
                          child: Icon(Icons.confirmation_number_rounded, color: ieAccent, size: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'YOUR INVITE CODE',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: text2,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              inviteCode.isEmpty ? '------' : inviteCode,
                              style: GoogleFonts.firaCode(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: ieAccent,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ToolButton(
                        icon: Icons.copy_rounded,
                        label: 'Copy',
                        onTap: () => _copyCode(context, inviteCode),
                      ),
                      const SizedBox(width: 6),
                      _ToolButton(
                        icon: Icons.link_rounded,
                        label: 'Link',
                        onTap: () => _copyLink(context, inviteLink),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Tier -> Level Unlock Explainer Card ─────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ieAccentBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ieAccentBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.stars_rounded, color: ieAccent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '👑 How Multi-Level Earnings Work',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: ieAccent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Your own software tier permanently determines how many levels down your invite chain you earn from:',
                        style: GoogleFonts.inter(fontSize: 12, color: text2, height: 1.3),
                      ),
                      const SizedBox(height: 10),
                      _TierUnlockRow('📱 Basic Plan (Rs 12k)', 'Earn Level 1 (15%)', text1),
                      _TierUnlockRow('💻 Professional Plan (Rs 35k)', 'Earn Levels 1–2 (15% + 2.5%)', text1),
                      _TierUnlockRow('👑 Enterprise Plan (Rs 70k)', 'Earn Levels 1–4 Max (15% + 2.5% + 1.5% + 1%)', ieAccent),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Multi-Level Commission Structure ────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🏆 Commission Percentages (Every Payment)',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: text1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Applies to Registrations, Upgrades & Storage Add-ons:',
                        style: GoogleFonts.inter(fontSize: 11, color: text2),
                      ),
                      const SizedBox(height: 12),
                      _CommRow('Level 1 (Direct Inviter)', '15.0%', text1, text2),
                      _CommRow('Level 2 (Inviter’s Inviter)', '2.5%', text1, text2),
                      _CommRow('Level 3 (3rd Generation)', '1.5%', text1, text2),
                      _CommRow('Level 4 (4th Generation)', '1.0%', text1, text2),
                    ],
                  ),
                ),
                const SizedBox(height: 20),


                // ── Share Buttons ───────────────────────────────────────
                Text(
                  'Share Now',
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: text1,
                  ),
                ),
                const SizedBox(height: 12),

                // WhatsApp
                _ShareButton(
                  icon: Icons.chat_rounded,
                  label: 'Share on WhatsApp',
                  subtitle: 'Send pre-filled invite message',
                  color: const Color(0xFF25D366),
                  onTap: () => _shareWhatsApp(context, inviteCode, inviteLink),
                ),
                const SizedBox(height: 10),

                // Generic share
                _ShareButton(
                  icon: Icons.share_rounded,
                  label: 'Share via...',
                  subtitle: 'Email, SMS, other apps',
                  color: ieAccent,
                  onTap: () => _shareGeneric(inviteCode, inviteLink),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  void _copyCode(BuildContext context, String code) {
    if (code.isEmpty) return;
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invite code copied!',
            style: GoogleFonts.inter(fontSize: 13)),
        backgroundColor: ieAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _copyLink(BuildContext context, String link) {
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Link copied!',
            style: GoogleFonts.inter(fontSize: 13)),
        backgroundColor: ieAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareWhatsApp(BuildContext context, String code, String link) async {
    final message = Uri.encodeComponent(
      '👋 Salam! Darzi Pro use karo — tailor shop management software. '
      'Mere invite code se register karo aur special discount pao!\n\n'
      '🎯 Invite Code: $code\n'
      '🔗 Register: $link',
    );
    final url = Uri.parse('whatsapp://send?text=$message');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      final webUrl = Uri.parse('https://wa.me/?text=$message');
      if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _shareGeneric(String code, String link) async {
    await Share.share(
      'Check out Darzi Pro — professional tailor shop management software! '
      'Use my invite code $code when you register: $link',
      subject: 'Join Darzi Pro with my invite code!',
    );
  }
}

// ── Tool Button ──────────────────────────────────────────────────────────────
class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14, color: ieAccent),
      label: Text(
        label,
        style: GoogleFonts.inter(
            fontSize: 11.5, fontWeight: FontWeight.w700, color: ieAccent),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: ieAccentBorder, width: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: ieAccentBg,
      ),
    );
  }
}

// ── Commission Row ───────────────────────────────────────────────────────────
class _CommRow extends StatelessWidget {
  final String label;
  final String amount;
  final Color textColor;
  final Color mutedColor;
  const _CommRow(this.label, this.amount, this.textColor, this.mutedColor);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label,
                style: GoogleFonts.inter(fontSize: 13, color: textColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Text(
            amount,
            style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ieAccent),
          ),
        ],
      ),
    );
  }
}

class _TierUnlockRow extends StatelessWidget {
  final String tier;
  final String unlocks;
  final Color textColor;
  const _TierUnlockRow(this.tier, this.unlocks, this.textColor);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x0AFFFFFF) : const Color(0x0A000000),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tier,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: textColor),
          ),
          const SizedBox(height: 2),
          Text(
            unlocks,
            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: ieAccent),
          ),
        ],
      ),
    );
  }
}



// ── Share Button ─────────────────────────────────────────────────────────────
class _ShareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ShareButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: context.text2)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
          ],
        ),
      ),
    );
  }
}
