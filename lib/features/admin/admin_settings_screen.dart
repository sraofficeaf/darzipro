import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/services/admin_service.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _thresholdCtrl = TextEditingController(text: '1000');
  final _delayCtrl = TextEditingController(text: '0');
  bool _notifyOnNewRegistration = true;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final threshold = await AdminService.instance.getMinPayoutThreshold();
    final delayDays = await AdminService.instance.getPayoutDelayDays();
    if (mounted) {
      setState(() {
        _thresholdCtrl.text = threshold.toString();
        _delayCtrl.text = delayDays.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    final thresholdVal = int.tryParse(_thresholdCtrl.text.trim());
    final delayVal = int.tryParse(_delayCtrl.text.trim());

    if (thresholdVal == null || thresholdVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid numeric threshold (e.g. 1000)')),
      );
      return;
    }
    if (delayVal == null || delayVal < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid non-negative delay in days (e.g. 0)')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final ok1 = await AdminService.instance.setMinPayoutThreshold(thresholdVal);
    final ok2 = await AdminService.instance.setPayoutDelayDays(delayVal);

    if (mounted) {
      setState(() => _isSaving = false);
      if (ok1 && ok2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Settings saved! Threshold: Rs $thresholdVal · Delay: $delayVal Days')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update payout settings')),
        );
      }
    }
  }

  @override
  void dispose() {
    _thresholdCtrl.dispose();
    _delayCtrl.dispose();
    super.dispose();
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
            // ── Header ───────────────────────────────────────────────────────
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
                          '⚙️ Admin Settings',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: text1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Configure business model parameters, payout rules, and notifications',
                          style: GoogleFonts.inter(fontSize: 12, color: text2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Section 1: Business Model & Payout Configuration
                        Text('💰 Business Model & Payout Configuration', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: text1)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  if (constraints.maxWidth < 500) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Minimum Payout Threshold (Rs)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: text1)),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller: _thresholdCtrl,
                                          keyboardType: TextInputType.number,
                                          style: GoogleFonts.inter(fontSize: 13, color: text1),
                                          decoration: InputDecoration(
                                            hintText: 'e.g. 1000',
                                            prefixText: 'Rs ',
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text('Payout Delay (Days)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: text1)),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller: _delayCtrl,
                                          keyboardType: TextInputType.number,
                                          style: GoogleFonts.inter(fontSize: 13, color: text1),
                                          decoration: InputDecoration(
                                            hintText: 'e.g. 0',
                                            suffixText: 'Days',
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Minimum Payout Threshold (Rs)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: text1)),
                                            const SizedBox(height: 6),
                                            TextField(
                                              controller: _thresholdCtrl,
                                              keyboardType: TextInputType.number,
                                              style: GoogleFonts.inter(fontSize: 13, color: text1),
                                              decoration: InputDecoration(
                                                hintText: 'e.g. 1000',
                                                prefixText: 'Rs ',
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Payout Delay (Days)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: text1)),
                                            const SizedBox(height: 6),
                                            TextField(
                                              controller: _delayCtrl,
                                              keyboardType: TextInputType.number,
                                              style: GoogleFonts.inter(fontSize: 13, color: text1),
                                              decoration: InputDecoration(
                                                hintText: 'e.g. 0',
                                                suffixText: 'Days',
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              Text('• Minimum Payout Threshold: Shops must reach this amount before payout processing.\n• Payout Delay: Number of days earnings must age before becoming eligible for payout (0 = immediate).', style: GoogleFonts.inter(fontSize: 11, color: text2)),
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 12),
                              Text('Multi-Level Profit Percentages', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: text1)),
                              const SizedBox(height: 8),
                              const _RuleRow('Level 1 (Direct Inviter)', '15.0%'),
                              const _RuleRow('Level 2 (2nd Generation)', '2.5%'),
                              const _RuleRow('Level 3 (3rd Generation)', '1.5%'),
                              const _RuleRow('Level 4 (4th Generation)', '1.0%'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Section 2: Notifications
                        Text('🔔 Admin Notifications', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: text1)),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
                          child: Column(
                            children: [
                              SwitchListTile(
                                value: _notifyOnNewRegistration,
                                onChanged: (v) => setState(() => _notifyOnNewRegistration = v),
                                title: Text('Notify on new registrations', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: text1)),
                                subtitle: Text('Receive alerts when shops submit self-registration requests', style: GoogleFonts.inter(fontSize: 11, color: text2)),
                                activeTrackColor: AppColors.accent,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveSettings,
                          icon: _isSaving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.save_rounded),
                          label: Text(_isSaving ? 'Saving...' : 'Save Settings'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
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
