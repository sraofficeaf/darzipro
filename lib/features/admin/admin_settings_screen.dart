import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/services/admin_service.dart';
import 'widgets/admin_ui_kit.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _thresholdCtrl = TextEditingController(text: '1000');
  final _delayCtrl = TextEditingController(text: '0');
  final _basicPriceCtrl = TextEditingController(text: '12000');
  final _proPriceCtrl = TextEditingController(text: '35000');
  final _enterprisePriceCtrl = TextEditingController(text: '70000');
  final _storageMonthlyCtrl = TextEditingController(text: '1200');
  final _storageAnnualCtrl = TextEditingController(text: '10000');

  bool _basicActive = true;
  bool _proActive = true;
  bool _enterpriseActive = true;
  bool _storageMonthlyActive = true;
  bool _storageAnnualActive = true;

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
    final config = await AdminService.instance.getPlanConfig();
    if (mounted) {
      setState(() {
        _thresholdCtrl.text = threshold.toString();
        _delayCtrl.text = delayDays.toString();
        _basicPriceCtrl.text = config['basic_price']?.toString() ?? '12000';
        _basicActive = config['basic_active'] as bool? ?? true;
        _proPriceCtrl.text = config['pro_price']?.toString() ?? '35000';
        _proActive = config['pro_active'] as bool? ?? true;
        _enterprisePriceCtrl.text = config['enterprise_price']?.toString() ?? '70000';
        _enterpriseActive = config['enterprise_active'] as bool? ?? true;
        _storageMonthlyCtrl.text = config['storage_monthly_price']?.toString() ?? '1200';
        _storageMonthlyActive = config['storage_monthly_active'] as bool? ?? true;
        _storageAnnualCtrl.text = config['storage_annual_price']?.toString() ?? '10000';
        _storageAnnualActive = config['storage_annual_active'] as bool? ?? true;
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
    final ok3 = await AdminService.instance.setPlanConfig({
      'basic_price': _basicPriceCtrl.text.trim(),
      'basic_active': _basicActive,
      'pro_price': _proPriceCtrl.text.trim(),
      'pro_active': _proActive,
      'enterprise_price': _enterprisePriceCtrl.text.trim(),
      'enterprise_active': _enterpriseActive,
      'storage_monthly_price': _storageMonthlyCtrl.text.trim(),
      'storage_monthly_active': _storageMonthlyActive,
      'storage_annual_price': _storageAnnualCtrl.text.trim(),
      'storage_annual_active': _storageAnnualActive,
    });

    if (mounted) {
      setState(() => _isSaving = false);
      if (ok1 && ok2 && ok3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved! Plan status (Active/Inactive) & pricing updated successfully.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update some settings')),
        );
      }
    }
  }

  @override
  void dispose() {
    _thresholdCtrl.dispose();
    _delayCtrl.dispose();
    _basicPriceCtrl.dispose();
    _proPriceCtrl.dispose();
    _enterprisePriceCtrl.dispose();
    _storageMonthlyCtrl.dispose();
    _storageAnnualCtrl.dispose();
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
            // Top Header Bar (RepaintBoundary for zero scroll cost)
            RepaintBoundary(
              child: AdminPageHeader(
                title: 'Admin Settings',
                subtitle: 'Configure business model parameters, payout rules, and notifications',
                action: AdminButton.primary(
                  label: _isSaving ? 'Saving...' : 'Save Settings',
                  icon: _isSaving ? null : Icons.save_rounded,
                  onPressed: _isSaving ? null : _saveSettings,
                ),
              ),
            ),

            // Body
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AdminColors.indigo))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Section 1: Business Model & Payout Configuration
                        Text(
                          '💰 Business Model & Payout Configuration',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: text1),
                        ),
                        const SizedBox(height: 10),
                        RepaintBoundary(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: border),
                              boxShadow: context.cardShadow,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    if (constraints.maxWidth < 500) {
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Minimum Payout Threshold (Rs)', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: text1)),
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
                                          Text('Payout Delay (Days)', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: text1)),
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
                                              Text('Minimum Payout Threshold (Rs)', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: text1)),
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
                                              Text('Payout Delay (Days)', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: text1)),
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
                                Text(
                                  '• Minimum Payout Threshold: Shops must reach this amount before payout processing.\n• Payout Delay: Number of days earnings must age before becoming eligible for payout (0 = immediate).',
                                  style: GoogleFonts.inter(fontSize: 11, color: text2),
                                ),
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
                        ),
                        const SizedBox(height: 20),

                        // Section 2: Plan Customization & Price Controls
                        Text(
                          '🏷️ Plan Pricing & Storage Customization',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: text1),
                        ),
                        const SizedBox(height: 10),
                        RepaintBoundary(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: border),
                              boxShadow: context.cardShadow,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Membership Tier Pricing & Active Status', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: text1)),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('📱 Basic', style: GoogleFonts.inter(fontSize: 12, color: text2)),
                                              Switch(
                                                value: _basicActive,
                                                onChanged: (v) => setState(() => _basicActive = v),
                                                activeTrackColor: AdminColors.indigo,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          TextField(
                                            controller: _basicPriceCtrl,
                                            keyboardType: TextInputType.number,
                                            style: GoogleFonts.inter(fontSize: 13, color: text1),
                                            decoration: InputDecoration(
                                              prefixText: 'Rs ',
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('🚀 Pro', style: GoogleFonts.inter(fontSize: 12, color: text2)),
                                              Switch(
                                                value: _proActive,
                                                onChanged: (v) => setState(() => _proActive = v),
                                                activeTrackColor: AdminColors.indigo,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          TextField(
                                            controller: _proPriceCtrl,
                                            keyboardType: TextInputType.number,
                                            style: GoogleFonts.inter(fontSize: 13, color: text1),
                                            decoration: InputDecoration(
                                              prefixText: 'Rs ',
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('👑 Enterprise', style: GoogleFonts.inter(fontSize: 12, color: text2)),
                                              Switch(
                                                value: _enterpriseActive,
                                                onChanged: (v) => setState(() => _enterpriseActive = v),
                                                activeTrackColor: AdminColors.indigo,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          TextField(
                                            controller: _enterprisePriceCtrl,
                                            keyboardType: TextInputType.number,
                                            style: GoogleFonts.inter(fontSize: 13, color: text1),
                                            decoration: InputDecoration(
                                              prefixText: 'Rs ',
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 12),
                                Text('💾 Extra Storage Add-on Pricing & Active Status', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: text1)),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Monthly', style: GoogleFonts.inter(fontSize: 12, color: text2)),
                                              Switch(
                                                value: _storageMonthlyActive,
                                                onChanged: (v) => setState(() => _storageMonthlyActive = v),
                                                activeTrackColor: AdminColors.indigo,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          TextField(
                                            controller: _storageMonthlyCtrl,
                                            keyboardType: TextInputType.number,
                                            style: GoogleFonts.inter(fontSize: 13, color: text1),
                                            decoration: InputDecoration(
                                              prefixText: 'Rs ',
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Annual', style: GoogleFonts.inter(fontSize: 12, color: text2)),
                                              Switch(
                                                value: _storageAnnualActive,
                                                onChanged: (v) => setState(() => _storageAnnualActive = v),
                                                activeTrackColor: AdminColors.indigo,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          TextField(
                                            controller: _storageAnnualCtrl,
                                            keyboardType: TextInputType.number,
                                            style: GoogleFonts.inter(fontSize: 13, color: text1),
                                            decoration: InputDecoration(
                                              prefixText: 'Rs ',
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const AdminInfoBox.rose(
                                  text: 'Profit Share for Storage Add-ons: 0% (Disabled globally for storage purchases).',
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => context.go('/admin/vps-resources'),
                                    icon: const Icon(Icons.dns_rounded, size: 16),
                                    label: const Text('🖥️ View Live VPS & Shop Resource Usage Analytics'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AdminColors.indigo,
                                      side: BorderSide(color: AdminColors.indigo.withValues(alpha: 0.5)),
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Section 3: Notifications
                        Text('🔔 Admin Notifications', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: text1)),
                        const SizedBox(height: 10),
                        RepaintBoundary(
                          child: Container(
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: border),
                              boxShadow: context.cardShadow,
                            ),
                            child: SwitchListTile(
                              value: _notifyOnNewRegistration,
                              onChanged: (v) => setState(() => _notifyOnNewRegistration = v),
                              title: Text('Notify on new registrations', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: text1)),
                              subtitle: Text('Receive alerts when shops submit self-registration requests', style: GoogleFonts.inter(fontSize: 11, color: text2)),
                              activeTrackColor: AdminColors.indigo,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
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
          Text(percent, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AdminColors.indigo)),
        ],
      ),
    );
  }
}
