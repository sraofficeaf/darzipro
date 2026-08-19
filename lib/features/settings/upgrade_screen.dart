import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:darzi_pro/core/theme/theme_extensions.dart';
import 'package:darzi_pro/core/constants/app_strings.dart';
import 'package:darzi_pro/shared/providers/license_provider.dart';

class UpgradeScreen extends ConsumerStatefulWidget {
  const UpgradeScreen({super.key});

  @override
  ConsumerState<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends ConsumerState<UpgradeScreen> {

  @override
  Widget build(BuildContext context) {
    final license = ref.watch(licenseProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? const Color(0xFF070D1A) : context.bg;
    final cardBg = isDark ? const Color(0x09FFFFFF) : context.surface;
    final cardBorder = isDark ? const Color(0x12FFFFFF) : context.border;
    final rimColor = isDark ? const Color(0x1AFFFFFF) : Colors.transparent;
    final text1 = isDark ? const Color(0xFFEDF4FF) : context.text1;
    final text2 = isDark ? const Color(0xFF5A7090) : context.text2;
    final backBtnBg = isDark ? const Color(0x0DFFFFFF) : context.surface2;
    final backBtnBorder = isDark ? const Color(0x14FFFFFF) : context.border;
    final dividerColor = isDark ? const Color(0x0FFFFFFF) : context.border;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Ambient background glow RadialGradient centered top
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.2,
                  colors: [
                    Color(0x1AF5A623),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Navigation Row
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(context);
                            },
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: backBtnBg,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: backBtnBorder,
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.arrow_back_rounded,
                                  color: text2,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Darzi Pro Upgrade',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: text1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Current Plan Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: cardBorder,
                            width: 1,
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Top rim
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 1,
                                decoration: BoxDecoration(
                                  color: rimColor,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    topRight: Radius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                            // Content
                            _buildCurrentPlanContent(license),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Responsive details Row/Column
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 700;
                          
                          final tableAndForm = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Compare Plans',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: text1,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: cardBorder,
                                    width: 1,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Table(
                                  columnWidths: const {
                                    0: FlexColumnWidth(1.2),
                                    1: FlexColumnWidth(1.0),
                                    2: FlexColumnWidth(1.3),
                                  },
                                  border: TableBorder(
                                    horizontalInside: BorderSide(
                                      color: dividerColor,
                                      width: 1,
                                    ),
                                  ),
                                  children: [
                                    TableRow(
                                      children: [
                                        _buildHeaderCell('Feature'),
                                        _buildHeaderCell('Free'),
                                        _buildHeaderCell('Pro / Business'),
                                      ],
                                    ),
                                    TableRow(
                                      children: [
                                        _buildTableCell('Storage', isHeader: true),
                                        _buildTableCell('Local Only'),
                                        _buildTableCell('Cloud Backup'),
                                      ],
                                    ),
                                    TableRow(
                                      children: [
                                        _buildTableCell('Sync', isHeader: true),
                                        _buildTableCell('❌', isDanger: true),
                                        _buildTableCell('Multi-Device Sync'),
                                      ],
                                    ),
                                    TableRow(
                                      children: [
                                        _buildTableCell('Devices', isHeader: true),
                                        _buildTableCell('1 Device'),
                                        _buildTableCell('Unlimited'),
                                      ],
                                    ),
                                    TableRow(
                                      children: [
                                        _buildTableCell('Support', isHeader: true),
                                        _buildTableCell('Community'),
                                        _buildTableCell('Priority WhatsApp'),
                                      ],
                                    ),
                                    TableRow(
                                      children: [
                                        _buildTableCell('Price', isHeader: true),
                                        _buildTableCell('PKR 0', isHighlight: false),
                                        _buildTableCell('PKR 1,000/mo', isHighlight: true),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );

                          final paymentInstructions = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'How to Upgrade',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: text1,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: cardBorder,
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildStepRow(
                                      '1',
                                      'Send payment of PKR 1,000 to:',
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildAccountRow(
                                            'Easypaisa',
                                            AppStrings.easypaisaNumber,
                                            AppStrings.easypaisaName,
                                          ),
                                          const SizedBox(height: 8),
                                          _buildAccountRow(
                                            'JazzCash',
                                            AppStrings.jazzCashNumber,
                                            AppStrings.jazzCashName,
                                          ),
                                        ],
                                      ),
                                    ),
                                    _buildStepRow(
                                      '2',
                                      'Send screenshot of receipt on WhatsApp:',
                                      GestureDetector(
                                        onTap: () async {
                                          HapticFeedback.lightImpact();
                                          final url = Uri.parse('https://wa.me/923099766115');
                                          if (await canLaunchUrl(url)) {
                                            await launchUrl(url, mode: LaunchMode.externalApplication);
                                          } else {
                                            Clipboard.setData(
                                              const ClipboardData(text: AppStrings.supportNumber),
                                            );
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Support number ${AppStrings.supportNumber} copied!',
                                                    style: GoogleFonts.inter(),
                                                  ),
                                                  duration: const Duration(seconds: 2),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0x05FFFFFF) : context.surface2,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: isDark ? const Color(0x0FFFFFFF) : context.border,
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.chat_bubble_outline_rounded,
                                                color: Color(0xFF10CBA0),
                                                size: 16,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  AppStrings.supportNumber,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: text1,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0x1A10CBA0),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: const Color(0xFF10CBA0),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Text(
                                                  'WHATSAPP',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: const Color(0xFF10CBA0),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    _buildStepRow(
                                      '3',
                                      'Receive your license key:',
                                      Text(
                                        'Once payment is verified, we will generate and send your custom 20-character license key.',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: text2,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                    _buildStepRow(
                                      '4',
                                      'Enter key below to activate features:',
                                      Text(
                                        'Input the license key in the form below and hit Activate.',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: text2,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );

                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: tableAndForm),
                                const SizedBox(width: 24),
                                Expanded(child: paymentInstructions),
                              ],
                            );
                          } else {
                            return Column(
                              children: [
                                tableAndForm,
                                const SizedBox(height: 28),
                                paymentInstructions,
                              ],
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }  Widget _buildCurrentPlanContent(dynamic license) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: license.isFree
                    ? (isDark ? const Color(0x0DFFFFFF) : context.surface2)
                    : const Color(0x1A10CBA0),
                border: Border.all(
                  color: license.isFree
                      ? (isDark ? const Color(0x14FFFFFF) : context.border)
                      : const Color(0x3310CBA0),
                  width: 1.5,
                ),
              ),
              child: Icon(
                license.isFree ? Icons.person_rounded : Icons.star_rounded,
                color: license.isFree ? (isDark ? const Color(0xFF5A7090) : context.text3) : const Color(0xFF10CBA0),
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        license.isFree
                            ? 'Free Plan (Offline)'
                            : '${license.plan.toUpperCase()} Plan Active',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFEDF4FF) : context.text1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: license.isFree
                              ? (isDark ? const Color(0x0F5A7090) : context.surface2)
                              : const Color(0x0F10CBA0),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: license.isFree
                                ? (isDark ? const Color(0x265A7090) : context.border)
                                : const Color(0x2610CBA0),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          license.isFree ? 'OFFLINE' : 'PRO',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: license.isFree
                                ? (isDark ? const Color(0xFF5A7090) : context.text3)
                                : const Color(0xFF10CBA0),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    license.isFree
                        ? 'All data is stored locally on this device.'
                        : 'Shop: ${license.shopName} • Cloud Sync Enabled',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF5A7090) : context.text2,
                    ),
                  ),
                ],
              ),
            ),
            if (!license.isFree && license.expiresAt != null) ...[
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: license.isExpiringSoon
                          ? const Color(0x0FF5A623)
                          : (license.isExpired ? const Color(0x0FFF3A58) : const Color(0x0F5B72F5)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: license.isExpiringSoon
                            ? const Color(0x26F5A623)
                            : (license.isExpired ? const Color(0x26FF3A58) : const Color(0x265B72F5)),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      license.isExpired
                          ? 'Expired'
                          : (license.isExpiringSoon
                              ? '${license.daysRemaining} days left'
                              : 'Active'),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: license.isExpiringSoon
                            ? const Color(0xFFF5A623)
                            : (license.isExpired ? const Color(0xFFFF3A58) : const Color(0xFF5B72F5)),
                      ),
                    ),
                  ),
                  if (license.expiresAt != null)
                    Text(
                      'Expires: ${license.expiresAt!.year}-${license.expiresAt!.month.toString().padLeft(2, '0')}-${license.expiresAt!.day.toString().padLeft(2, '0')}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF3D5470) : context.text3,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
        if (!license.isFree) ...[
          const SizedBox(height: 16),
          Divider(color: isDark ? const Color(0x0FFFFFFF) : context.border, height: 1),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                HapticFeedback.lightImpact();
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: isDark ? const Color(0xFF070D1A) : context.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: isDark ? const Color(0x14FFFFFF) : context.border),
                    ),
                    title: Text(
                      'Deactivate License',
                      style: GoogleFonts.outfit(
                        color: isDark ? const Color(0xFFEDF4FF) : context.text1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    content: Text(
                      'Are you sure you want to deactivate your license? This device will go offline.',
                      style: GoogleFonts.inter(
                        color: isDark ? const Color(0xFF5A7090) : context.text2,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(color: isDark ? const Color(0xFF5A7090) : context.text2),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(
                          'Deactivate',
                          style: GoogleFonts.inter(color: const Color(0xFFFF3A58)),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(licenseProvider.notifier).deactivate();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Colors.white, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'License deactivated successfully.',
                              style: GoogleFonts.inter(color: Colors.white),
                            ),
                          ],
                        ),
                        backgroundColor: isDark ? const Color(0xFF1E3050) : const Color(0xFF1A1F2C),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.power_settings_new_rounded, size: 16, color: Color(0xFFFF3A58)),
              label: Text(
                'Deactivate License',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFF3A58),
                ),
              ),
            ),
          ),
        ]
      ],
    );
  }

  Widget _buildHeaderCell(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Text(
        text,
        textAlign: text == 'Feature' ? TextAlign.left : TextAlign.center,
        style: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: text == 'Pro / Business' ? const Color(0xFFF5A623) : (isDark ? const Color(0xFFEDF4FF) : context.text1),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false, bool isHighlight = false, bool isDanger = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Text(
        text,
        textAlign: isHeader ? TextAlign.left : TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: isHeader || isHighlight ? FontWeight.w700 : FontWeight.w500,
          color: isHighlight
              ? const Color(0xFF10CBA0)
              : (isDanger
                  ? const Color(0xFFFF3A58)
                  : (isHeader ? (isDark ? const Color(0xFFEDF4FF) : context.text1) : (isDark ? const Color(0xFF5A7090) : context.text2))),
        ),
      ),
    );
  }

  Widget _buildStepRow(String stepNum, String title, Widget content) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF5A623), Color(0xFFD97706)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                stepNum,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1A0A00),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFEDF4FF) : context.text1,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 36, top: 8, bottom: 16),
          child: content,
        ),
      ],
    );
  }

  Widget _buildAccountRow(String provider, String number, String name) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x05FFFFFF) : context.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0x0FFFFFFF) : context.border, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: provider == 'Easypaisa'
                  ? const Color(0x1A10CBA0)
                  : const Color(0x1A9B5CF5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              provider.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: provider == 'Easypaisa'
                    ? const Color(0xFF10CBA0)
                    : const Color(0xFF9B5CF5),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  number,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFEDF4FF) : context.text1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF5A7090) : context.text2,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: number));
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$provider number copied to clipboard!', style: GoogleFonts.inter()),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Icon(
              Icons.copy_all_rounded,
              color: isDark ? const Color(0xFF3D5470) : context.text3,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}


// ── CUSTOM SCALE TRANSITION UPGRADE BUTTON ─────────────────────────────
class _UpgradeButton extends StatefulWidget {
  final VoidCallback? onTap;
  final bool isLoading;
  final String label;

  const _UpgradeButton({
    required this.onTap,
    required this.isLoading,
    required this.label,
  });

  @override
  State<_UpgradeButton> createState() => _UpgradeButtonState();
}

class _UpgradeButtonState extends State<_UpgradeButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onTap == null;
    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => setState(() => _scale = 0.97),
      onTapUp: isDisabled
          ? null
          : (_) {
              setState(() => _scale = 1.0);
              HapticFeedback.lightImpact();
              widget.onTap!();
            },
      onTapCancel: isDisabled ? null : () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF5A623), Color(0xFFD97706)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66F5A623),
                blurRadius: 22,
                offset: Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF1A0A00),
                  ),
                )
              : Text(
                  widget.label.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A0A00),
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }
}
