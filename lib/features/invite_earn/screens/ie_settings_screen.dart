import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../shared/providers/invite_providers.dart';
import '../../../shared/providers/supabase_providers.dart';
import '../widgets/ie_earning_card.dart';

class IeSettingsScreen extends ConsumerStatefulWidget {
  const IeSettingsScreen({super.key});

  @override
  ConsumerState<IeSettingsScreen> createState() => _IeSettingsScreenState();
}

class _IeSettingsScreenState extends ConsumerState<IeSettingsScreen> {
  final _accountNumberCtrl = TextEditingController();
  final _accountNameCtrl = TextEditingController();
  String _selectedMethod = 'easypaisa';
  bool _isSaving = false;
  bool _loaded = false;

  static const _methods = [
    {'value': 'easypaisa', 'label': 'Easypaisa', 'icon': '📱'},
    {'value': 'jazzcash', 'label': 'JazzCash', 'icon': '💳'},
    {'value': 'bank', 'label': 'Bank Transfer', 'icon': '🏦'},
  ];

  @override
  void dispose() {
    _accountNumberCtrl.dispose();
    _accountNameCtrl.dispose();
    super.dispose();
  }

  void _loadSettings(Map<String, dynamic> data) {
    if (_loaded) return;
    _loaded = true;
    _selectedMethod = data['payout_method'] as String? ?? 'easypaisa';
    _accountNumberCtrl.text = data['payout_account_number'] as String? ?? '';
    _accountNameCtrl.text = data['payout_account_name'] as String? ?? '';
  }

  Future<void> _save() async {
    final shopId = ref.read(currentShopIdProvider);
    if (shopId == null) return;
    setState(() => _isSaving = true);
    final success = await savePayoutSettings(
      shopId: shopId,
      method: _selectedMethod,
      accountNumber: _accountNumberCtrl.text.trim(),
      accountName: _accountNameCtrl.text.trim(),
    );
    ref.invalidate(inviteSettingsProvider);
    setState(() => _isSaving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? '✅ Payout settings saved!' : '❌ Failed to save. Try again.',
          style: GoogleFonts.inter(fontSize: 13),
        ),
        backgroundColor: success ? ieAccent : const Color(0xFFFF3A58),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(inviteSettingsProvider);
    final notifPrefs = ref.watch(ieNotifPrefsProvider);
    final notifNotifier = ref.read(ieNotifPrefsProvider.notifier);
    final text1 = context.text1;
    final text2 = context.text2;
    final surface = context.surface;
    final border = context.border;

    return Scaffold(
      backgroundColor: context.bg,
      body: settingsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: ieAccent)),
        error: (_, _) => const SizedBox.shrink(),
        data: (data) {
          _loadSettings(data);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Settings',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: text1,
                  ),
                ),
                const SizedBox(height: 20),

                // ── Payout Method ──────────────────────────────────────
                Text(
                  'Payout Method',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: text2,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                ...(_methods.map((m) {
                  final isSelected = _selectedMethod == m['value'];
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selectedMethod = m['value']!),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected ? ieAccentBg : surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? ieAccent : border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(m['icon']!,
                              style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              m['label']!,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? ieAccent : text1,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded,
                                color: ieAccent, size: 20),
                        ],
                      ),
                    ),
                  );
                })),
                const SizedBox(height: 16),

                // ── Account Fields ─────────────────────────────────────
                Text(
                  'Account Details',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: text2,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                _IeTextField(
                  controller: _accountNumberCtrl,
                  label: 'Account Number / Phone',
                  hint: 'e.g. 03001234567',
                  icon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                  border: border,
                  surface: surface,
                  text1: text1,
                  text2: text2,
                ),
                const SizedBox(height: 10),
                _IeTextField(
                  controller: _accountNameCtrl,
                  label: 'Account Holder Name',
                  hint: 'Full name on account',
                  icon: Icons.person_rounded,
                  border: border,
                  surface: surface,
                  text1: text1,
                  text2: text2,
                ),
                const SizedBox(height: 20),

                // ── Save Button ────────────────────────────────────────
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ieAccent,
                      foregroundColor: const Color(0xFF0A1428),
                      disabledBackgroundColor: ieAccentBg,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF0A1428),
                            ),
                          )
                        : Text(
                            'Save Settings',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Notification Preferences ───────────────────────────
                Text(
                  'Notification Preferences',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: text2,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    children: [
                      _NotifRow(
                        label: 'When I earn money',
                        subtitle: 'Get notified on each earning event',
                        value: notifPrefs.notifyOnEarn,
                        onChanged: (v) => notifNotifier.toggleEarn(v),
                        isFirst: true,
                        border: border,
                      ),
                      _NotifRow(
                        label: 'Payout processed',
                        subtitle: 'When admin marks payout as paid',
                        value: notifPrefs.notifyOnPayout,
                        onChanged: (v) => notifNotifier.togglePayout(v),
                        isFirst: false,
                        border: border,
                      ),

                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Text Field ────────────────────────────────────────────────────────────────
class _IeTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final Color border;
  final Color surface;
  final Color text1;
  final Color text2;

  const _IeTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    required this.border,
    required this.surface,
    required this.text1,
    required this.text2,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: text2)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(fontSize: 14, color: text1),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 13, color: text2),
            prefixIcon: Icon(icon, size: 18, color: ieAccent),
            filled: true,
            fillColor: surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: ieAccent, width: 1.5)),
          ),
        ),
      ],
    );
  }
}

// ── Notif Row ─────────────────────────────────────────────────────────────────
class _NotifRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isFirst;
  final Color border;

  const _NotifRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.isFirst,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!isFirst) Divider(height: 1, color: border),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.text1)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: GoogleFonts.inter(
                            fontSize: 11, color: context.text2)),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: ieAccent,
                activeTrackColor: ieAccentBg,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
