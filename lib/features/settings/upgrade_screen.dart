import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:darzi_pro/core/constants/app_colors.dart';
import 'package:darzi_pro/core/widgets/shared_widgets.dart';
import 'package:darzi_pro/shared/providers/license_provider.dart';

class UpgradeScreen extends ConsumerStatefulWidget {
  const UpgradeScreen({super.key});

  @override
  ConsumerState<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends ConsumerState<UpgradeScreen> {
  final TextEditingController _keyController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _activateLicense() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a license key.', style: GoogleFonts.inter()),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await ref.read(licenseProvider.notifier).activate(key);

    setState(() => _isLoading = false);

    if (result.success && result.license != null) {
      if (!mounted) return;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: AppCard(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.teal.withValues(alpha: 0.15),
                      border: Border.all(color: AppColors.teal.withValues(alpha: 0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.teal.withValues(alpha: 0.2),
                          blurRadius: 20,
                        )
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.check_circle_outline, color: AppColors.teal, size: 36),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GoldGradientText(
                    'License Activated!',
                    style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Welcome to ${result.license!.plan.toUpperCase()} Plan!\nYour shop "${result.license!.shopName}" is now connected to the cloud.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 14, color: t2, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  GoldButton(
                    onPressed: () {
                      Navigator.pop(context); // close dialog
                      Navigator.pop(context); // go back to settings
                    },
                    child: Text(
                      'Great, Let\'s Go!',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A0F00),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Verification failed', style: GoogleFonts.inter()),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final license = ref.watch(licenseProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final t3 = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: t1, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: GoldGradientText(
          'Darzi Pro Upgrade',
          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Plan Card
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: license.isFree ? t2.withValues(alpha: 0.1) : AppColors.accentS,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        license.isFree ? Icons.person_outline : Icons.workspace_premium_rounded,
                        color: license.isFree ? t2 : AppColors.accent,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            license.isFree ? 'Free Plan (Offline)' : '${license.plan.toUpperCase()} Plan Active',
                            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: t1),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            license.isFree
                                ? 'All data is stored locally on this device.'
                                : 'Shop: ${license.shopName} • Cloud Sync Enabled',
                            style: GoogleFonts.inter(fontSize: 13, color: t2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Plan Comparison Table
            Text(
              'Compare Plans',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: t1),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(1.2),
                  1: FlexColumnWidth(1.0),
                  2: FlexColumnWidth(1.2),
                },
                border: TableBorder(
                  horizontalInside: BorderSide(color: AppColors.accent.withValues(alpha: 0.1), width: 1),
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
                      _buildTableCell('❌'),
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
                      _buildTableCell('PKR 0', isHighlight: true),
                      _buildTableCell('PKR 500/mo', isHighlight: true),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Payment Instructions Card
            Text(
              'How to Upgrade',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: t1),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStepRow('1', 'Send payment of PKR 500 (or as agreed) to:'),
                    Padding(
                      padding: const EdgeInsets.only(left: 36, top: 8, bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• Easypaisa: 0300-1234567 (Saifur Rahman)',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: t1),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '• JazzCash:  0300-1234567 (Saifur Rahman)',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: t1),
                          ),
                        ],
                      ),
                    ),
                    _buildStepRow('2', 'Send screenshot of the receipt on WhatsApp:'),
                    Padding(
                      padding: const EdgeInsets.only(left: 36, top: 8, bottom: 12),
                      child: Text(
                        '• Support Number: +92 300 1234567',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: t1),
                      ),
                    ),
                    _buildStepRow('3', 'Receive your license key (format: DARZI-XXXX-XXXX-XXXX)'),
                    const SizedBox(height: 12),
                    _buildStepRow('4', 'Enter key below to activate Pro features immediately'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // License Key Input
            Text(
              'Activate License Key',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: t1),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    TextField(
                      controller: _keyController,
                      style: GoogleFonts.inter(color: t1, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: 'DARZI-XXXX-XXXX-XXXX',
                        hintStyle: GoogleFonts.inter(color: t3, letterSpacing: 1.5),
                        prefixIcon: const Icon(Icons.vpn_key_rounded, color: AppColors.accent),
                        filled: true,
                        fillColor: AppColors.accentSS,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.accent.withValues(alpha: 0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.accent),
                        ),
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 16),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                        : GoldButton(
                            onPressed: _activateLicense,
                            child: Text(
                              'Activate License',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1A0F00),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.accent),
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false, bool isHighlight = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text,
        textAlign: isHeader ? TextAlign.left : TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: isHeader || isHighlight ? FontWeight.bold : FontWeight.normal,
          color: isHighlight
              ? AppColors.teal
              : (isHeader ? t1 : t2),
        ),
      ),
    );
  }

  Widget _buildStepRow(String stepNum, String description) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              stepNum,
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: bg),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            description,
            style: GoogleFonts.inter(fontSize: 13, color: t2, height: 1.4),
          ),
        ),
      ],
    );
  }
}
