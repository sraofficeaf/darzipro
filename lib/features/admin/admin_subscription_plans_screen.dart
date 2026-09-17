import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/services/admin_service.dart';
import '../../core/services/subscription_service.dart';
import '../../core/theme/theme_extensions.dart';
import '../../shared/providers/admin_providers.dart';
import 'widgets/admin_ui_kit.dart';

class AdminSubscriptionPlansScreen extends ConsumerStatefulWidget {
  const AdminSubscriptionPlansScreen({super.key});

  @override
  ConsumerState<AdminSubscriptionPlansScreen> createState() =>
      _AdminSubscriptionPlansScreenState();
}

class _AdminSubscriptionPlansScreenState
    extends ConsumerState<AdminSubscriptionPlansScreen> {
  String? _editingPlanId;
  final Map<String, TextEditingController> _nameEnControllers = {};
  final Map<String, TextEditingController> _nameUrControllers = {};
  final Map<String, TextEditingController> _priceControllers = {};
  final Map<String, TextEditingController> _maxOrdersControllers = {};
  final Map<String, TextEditingController> _maxCustomersControllers = {};
  bool _isSaving = false;
  String? _saveError;

  // Founding Offer Settings
  bool _foundingSettingsLoaded = false;
  bool _isSavingFounding = false;
  String? _foundingSaveError;
  final _feeCtrl          = TextEditingController();
  final _freeMonthsCtrl   = TextEditingController();
  final _monthlyFixedCtrl = TextEditingController();
  final _storageGbCtrl    = TextEditingController();
  final _slotsCtrl        = TextEditingController();
  final _endDateCtrl      = TextEditingController();
  String _monthlyMode     = 'linked'; // 'linked' or 'fixed'
  bool _offerEnabled      = true;
  int _foundingShopsCount = 0;


  @override
  void initState() {
    super.initState();
    _loadFoundingSettings();
  }

  Future<void> _loadFoundingSettings() async {
    final settings = await AdminService.instance.fetchAppSettings(prefix: 'founding');
    final count    = await SubscriptionService.instance.countFoundingShops();
    if (!mounted) return;
    setState(() {
      _foundingShopsCount     = count;
      _foundingSettingsLoaded = true;
      _feeCtrl.text          = settings['founding_activation_fee']   ?? '35000';
      _freeMonthsCtrl.text   = settings['founding_free_months']      ?? '6';
      _monthlyFixedCtrl.text = settings['founding_monthly_fixed']    ?? '500';
      _storageGbCtrl.text    = settings['founding_storage_limit_gb'] ?? '5';
      _slotsCtrl.text        = settings['founding_slots_total']      ?? '50';
      _endDateCtrl.text      = settings['founding_offer_end_date']   ?? '';
      _monthlyMode           = settings['founding_monthly_mode']     ?? 'linked';
      _offerEnabled          = (settings['founding_offer_enabled']   ?? 'true') == 'true';
    });
  }

  @override
  void dispose() {
    for (final c in _nameEnControllers.values) { c.dispose(); }
    for (final c in _nameUrControllers.values) { c.dispose(); }
    for (final c in _priceControllers.values) { c.dispose(); }
    for (final c in _maxOrdersControllers.values) { c.dispose(); }
    for (final c in _maxCustomersControllers.values) { c.dispose(); }
    _feeCtrl.dispose();
    _freeMonthsCtrl.dispose();
    _monthlyFixedCtrl.dispose();
    _storageGbCtrl.dispose();
    _slotsCtrl.dispose();
    _endDateCtrl.dispose();
    super.dispose();
  }

  void _initControllersForPlan(Map<String, dynamic> plan) {
    final id = plan['id'] as String;
    if (!_nameEnControllers.containsKey(id)) {
      _nameEnControllers[id] = TextEditingController(text: plan['name_en'] as String? ?? '');
      _nameUrControllers[id] = TextEditingController(text: plan['name_ur'] as String? ?? '');
      _priceControllers[id] = TextEditingController(text: '${plan['price_pkr'] ?? 0}');
      _maxOrdersControllers[id] = TextEditingController(
          text: plan['max_orders_per_month'] != null ? '${plan['max_orders_per_month']}' : '');
      _maxCustomersControllers[id] = TextEditingController(
          text: plan['max_active_customers'] != null ? '${plan['max_active_customers']}' : '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = context.bg;
    final text1 = context.text1;
    final text2 = context.text2;

    final plansAsync = ref.watch(adminSubscriptionPlansProvider);
    final statsAsync = ref.watch(adminSubscriptionStatsProvider);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header (RepaintBoundary for zero scroll cost)
            RepaintBoundary(
              child: AdminPageHeader(
                title: 'Subscription Plans',
                subtitle: 'Edit plan prices and limits — changes take effect immediately',
                action: AdminIconBtn(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Refresh Plans',
                  onPressed: () {
                    ref.invalidate(adminSubscriptionPlansProvider);
                    ref.invalidate(adminSubscriptionStatsProvider);
                  },
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Subscription Stats Row
                        statsAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, _) => const SizedBox.shrink(),
                          data: (stats) => RepaintBoundary(child: _StatsRow(stats: stats)),
                        ),
                        const SizedBox(height: 20),

                        // Plans Table
                        Text(
                          'Plan Definitions',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: text1),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Prices and limits read from this table at runtime — nothing is hardcoded in the app.',
                          style: GoogleFonts.inter(fontSize: 11.5, color: text2),
                        ),
                        const SizedBox(height: 14),

                        if (_saveError != null) ...[
                          AdminInfoBox.rose(text: _saveError!),
                          const SizedBox(height: 12),
                        ],

                        plansAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator(color: AdminColors.indigo)),
                          error: (e, _) => Text('Error: $e', style: const TextStyle(color: AdminColors.rose)),
                          data: (plans) {
                            for (final plan in plans) {
                              _initControllersForPlan(plan);
                            }
                            return Column(
                              children: plans.map((plan) {
                                final id = plan['id'] as String;
                                final isEditing = _editingPlanId == id;
                                return RepaintBoundary(
                                  child: _PlanEditCard(
                                    plan: plan,
                                    isEditing: isEditing,
                                    isSaving: _isSaving,
                                    nameEnCtrl: _nameEnControllers[id]!,
                                    nameUrCtrl: _nameUrControllers[id]!,
                                    priceCtrl: _priceControllers[id]!,
                                    maxOrdersCtrl: _maxOrdersControllers[id]!,
                                    maxCustomersCtrl: _maxCustomersControllers[id]!,
                                    onEdit: () => setState(() {
                                      _editingPlanId = isEditing ? null : id;
                                      _saveError = null;
                                    }),
                                    onSave: () => _savePlan(plan, id),
                                    onToggleActive: (val) => _toggleActive(plan, val),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),

                        const SizedBox(height: 28),

                        // ── Founding Member Offer Settings ───────────
                        RepaintBoundary(
                          child: _FoundingOfferSection(
                            loaded: _foundingSettingsLoaded,
                            foundingShopsCount: _foundingShopsCount,
                            feeCtrl: _feeCtrl,
                            freeMonthsCtrl: _freeMonthsCtrl,
                            monthlyFixedCtrl: _monthlyFixedCtrl,
                            storageGbCtrl: _storageGbCtrl,
                            slotsCtrl: _slotsCtrl,
                            endDateCtrl: _endDateCtrl,
                            monthlyMode: _monthlyMode,
                            offerEnabled: _offerEnabled,
                            isSaving: _isSavingFounding,
                            saveError: _foundingSaveError,
                            onModeChange: (v) => setState(() => _monthlyMode = v),
                            onToggleEnabled: (v) => setState(() => _offerEnabled = v),
                            onSave: _saveFoundingSettings,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _savePlan(Map<String, dynamic> originalPlan, String id) async {
    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    final price = int.tryParse(_priceControllers[id]!.text.trim()) ?? 0;
    final maxOrders = int.tryParse(_maxOrdersControllers[id]!.text.trim());
    final maxCustomers = int.tryParse(_maxCustomersControllers[id]!.text.trim());

    final updatedPlan = {
      'id': id,
      'code': originalPlan['code'],
      'name_en': _nameEnControllers[id]!.text.trim(),
      'name_ur': _nameUrControllers[id]!.text.trim(),
      'price_pkr': price,
      'max_orders_per_month': maxOrders,
      'max_active_customers': maxCustomers,
      'sort_order': originalPlan['sort_order'],
      'is_active': originalPlan['is_active'],
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    final success = await AdminService.instance.upsertSubscriptionPlan(updatedPlan);

    setState(() {
      _isSaving = false;
      if (success) {
        _editingPlanId = null;
        ref.invalidate(adminSubscriptionPlansProvider);
      } else {
        _saveError = 'Failed to save plan. Please try again.';
      }
    });
  }

  Future<void> _saveFoundingSettings() async {
    setState(() {
      _isSavingFounding = true;
      _foundingSaveError = null;
    });
    final pairs = {
      'founding_activation_fee':   _feeCtrl.text.trim(),
      'founding_free_months':      _freeMonthsCtrl.text.trim(),
      'founding_monthly_mode':     _monthlyMode,
      'founding_monthly_fixed':    _monthlyFixedCtrl.text.trim(),
      'founding_storage_limit_gb': _storageGbCtrl.text.trim(),
      'founding_slots_total':      _slotsCtrl.text.trim(),
      'founding_offer_end_date':   _endDateCtrl.text.trim(),
      'founding_offer_enabled':    _offerEnabled ? 'true' : 'false',
    };
    bool allOk = true;
    for (final e in pairs.entries) {
      final ok = await AdminService.instance.updateAppSetting(e.key, e.value);
      if (!ok) allOk = false;
    }
    if (!mounted) return;
    setState(() {
      _isSavingFounding = false;
      if (!allOk) {
        _foundingSaveError = 'Some settings failed to save. Please retry.';
      } else {
        ref.invalidate(adminReportsDataProvider);
        ref.invalidate(adminSubscriptionStatsProvider);
      }
    });
  }

  Future<void> _toggleActive(Map<String, dynamic> plan, bool value) async {
    await AdminService.instance.upsertSubscriptionPlan({
      ...plan,
      'is_active': value,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    ref.invalidate(adminSubscriptionPlansProvider);
  }
}

// ── Stats Row ───────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final mrr      = (stats['mrr']              as int?) ?? 0;
    final fMrr     = (stats['founding_mrr']     as int?) ?? 0;
    final fCount   = (stats['founding_count']   as int?) ?? 0;
    final grace    = (stats['grace_count']      as int?) ?? 0;
    final readOnly = (stats['read_only_count']  as int?) ?? 0;
    final lifetime = (stats['lifetime_count']   as int?) ?? 0;
    final renewals = (stats['upcoming_renewals_7d'] as int?) ?? 0;
    final totalMrr = mrr + fMrr;

    final items = [
      ('Total MRR',    'Rs ${NumberFormat('#,###').format(totalMrr)}/mo', AdminColors.emerald),
      ('Founding',     '$fCount shops${fMrr > 0 ? " · Rs ${NumberFormat('#,###').format(fMrr)}/mo" : " (free)"} ', AdminColors.amber),
      ('Lifetime',     '$lifetime shops',  AdminColors.amber),
      ('Grace Period', '$grace shops',     AdminColors.blue),
      ('Read-Only',    '$readOnly shops',  AdminColors.rose),
      ('Renewing (7d)','$renewals shops',  AdminColors.violet),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((item) {
        return AdminMiniStat(
          label: item.$1,
          value: item.$2,
          color: item.$3,
        );
      }).toList(),
    );
  }
}

// ── Plan Edit Card ──────────────────────────────────────────────────────────

class _PlanEditCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final bool isEditing;
  final bool isSaving;
  final TextEditingController nameEnCtrl;
  final TextEditingController nameUrCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController maxOrdersCtrl;
  final TextEditingController maxCustomersCtrl;
  final VoidCallback onEdit;
  final VoidCallback onSave;
  final ValueChanged<bool> onToggleActive;

  const _PlanEditCard({
    required this.plan,
    required this.isEditing,
    required this.isSaving,
    required this.nameEnCtrl,
    required this.nameUrCtrl,
    required this.priceCtrl,
    required this.maxOrdersCtrl,
    required this.maxCustomersCtrl,
    required this.onEdit,
    required this.onSave,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final text1 = context.text1;
    final text2 = context.text2;
    final surface = context.surface;
    final border = context.border;
    final isActive = plan['is_active'] as bool? ?? true;
    final code = plan['code'] as String? ?? '';

    Color accentColor;
    switch (code) {
      case 'unlimited':
      case 'enterprise':
        accentColor = AdminColors.emerald;
        break;
      case 'standard':
      case 'pro':
        accentColor = AdminColors.amber;
        break;
      case 'basic':
        accentColor = AdminColors.blue;
        break;
      default:
        accentColor = AdminColors.indigo;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isEditing ? accentColor.withValues(alpha: 0.5) : border,
          width: isEditing ? 1.5 : 1,
        ),
        boxShadow: context.cardShadow,
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                AdminBadge(label: code.toUpperCase(), color: accentColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    plan['name_en'] as String? ?? code,
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: text1),
                  ),
                ),
                // Active toggle
                Row(
                  children: [
                    Text('Active', style: GoogleFonts.inter(fontSize: 11, color: text2)),
                    const SizedBox(width: 6),
                    Switch.adaptive(
                      value: isActive,
                      activeTrackColor: AdminColors.indigo,
                      onChanged: onToggleActive,
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onEdit,
                  child: Text(
                    isEditing ? 'Cancel' : 'Edit',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isEditing ? AdminColors.rose : accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Edit form
          if (isEditing) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _TextField(ctrl: nameEnCtrl, label: 'Name (EN)')),
                      const SizedBox(width: 10),
                      Expanded(child: _TextField(ctrl: nameUrCtrl, label: 'Name (UR)')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _TextField(ctrl: priceCtrl, label: 'Price (PKR)', isNumeric: true)),
                      const SizedBox(width: 10),
                      Expanded(child: _TextField(ctrl: maxOrdersCtrl, label: 'Max Orders (blank=∞)', isNumeric: true)),
                      const SizedBox(width: 10),
                      Expanded(child: _TextField(ctrl: maxCustomersCtrl, label: 'Max Customers (blank=∞)', isNumeric: true)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: AdminButton.primary(
                      label: isSaving ? 'Saving...' : 'Save Changes',
                      icon: isSaving ? null : Icons.save_rounded,
                      onPressed: isSaving ? null : onSave,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const AdminInfoBox.amber(
                    text: 'Price change applies to all new billings immediately. Existing cycle amounts remain unchanged.',
                  ),
                ],
              ),
            ),
          ] else ...[
            // View mode summary
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
              child: Row(
                children: [
                  AdminBadge(
                    label: 'Rs ${NumberFormat('#,###').format(plan['price_pkr'] ?? 0)}/mo',
                    color: accentColor,
                  ),
                  const SizedBox(width: 8),
                  AdminBadge(
                    label: plan['max_orders_per_month'] != null
                        ? '${plan['max_orders_per_month']} orders'
                        : '∞ orders',
                    color: AdminColors.blue,
                  ),
                  const SizedBox(width: 8),
                  AdminBadge(
                    label: plan['max_active_customers'] != null
                        ? '${plan['max_active_customers']} customers'
                        : '∞ customers',
                    color: AdminColors.emerald,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final bool isNumeric;
  const _TextField({required this.ctrl, required this.label, this.isNumeric = false});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: context.text1),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 11, color: context.text2),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AdminColors.indigo),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }
}

// ── Founding Offer Settings Section ────────────────────────────────────────

class _FoundingOfferSection extends StatelessWidget {
  final bool loaded;
  final int foundingShopsCount;
  final TextEditingController feeCtrl;
  final TextEditingController freeMonthsCtrl;
  final TextEditingController monthlyFixedCtrl;
  final TextEditingController storageGbCtrl;
  final TextEditingController slotsCtrl;
  final TextEditingController endDateCtrl;
  final String monthlyMode;
  final bool offerEnabled;
  final bool isSaving;
  final String? saveError;
  final ValueChanged<String> onModeChange;
  final ValueChanged<bool> onToggleEnabled;
  final VoidCallback onSave;

  const _FoundingOfferSection({
    required this.loaded,
    required this.foundingShopsCount,
    required this.feeCtrl,
    required this.freeMonthsCtrl,
    required this.monthlyFixedCtrl,
    required this.storageGbCtrl,
    required this.slotsCtrl,
    required this.endDateCtrl,
    required this.monthlyMode,
    required this.offerEnabled,
    required this.isSaving,
    required this.saveError,
    required this.onModeChange,
    required this.onToggleEnabled,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final text1   = context.text1;
    final text2   = context.text2;
    final surface = context.surface;
    final border  = context.border;
    final slotsTotal = int.tryParse(slotsCtrl.text) ?? 0;
    final slotsRemaining = slotsTotal > 0 ? (slotsTotal - foundingShopsCount).clamp(0, slotsTotal) : null;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.amber.withValues(alpha: 0.4), width: 1.5),
        boxShadow: context.cardShadow,
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AdminColors.amber.withValues(alpha: 0.07),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                const Text('👑', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Founding Member Offer Settings',
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: text1),
                      ),
                      Text(
                        'These settings are read at runtime from app_settings table.',
                        style: GoogleFonts.inter(fontSize: 11, color: text2),
                      ),
                    ],
                  ),
                ),
                // Live slots badge
                if (slotsRemaining != null)
                  AdminBadge(
                    label: '$slotsRemaining / $slotsTotal slots left',
                    color: slotsRemaining < 5 ? AdminColors.rose : AdminColors.emerald,
                  ),
                const SizedBox(width: 8),
                AdminBadge(
                  label: '$foundingShopsCount active',
                  color: AdminColors.amber,
                ),
                const SizedBox(width: 8),
                // Enable toggle
                Row(
                  children: [
                    Text('Enabled', style: GoogleFonts.inter(fontSize: 11, color: text2)),
                    const SizedBox(width: 4),
                    Switch.adaptive(
                      value: offerEnabled,
                      activeTrackColor: AdminColors.amber,
                      onChanged: onToggleEnabled,
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (!loaded)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: AdminColors.amber, strokeWidth: 2),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (saveError != null) ...[
                    AdminInfoBox.rose(text: saveError!),
                    const SizedBox(height: 12),
                  ],

                  // Row 1: Activation fee, Free months, Storage
                  Row(
                    children: [
                      Expanded(child: _TextField(ctrl: feeCtrl, label: 'Activation Fee (PKR)', isNumeric: true)),
                      const SizedBox(width: 10),
                      Expanded(child: _TextField(ctrl: freeMonthsCtrl, label: 'Free Period (months)', isNumeric: true)),
                      const SizedBox(width: 10),
                      Expanded(child: _TextField(ctrl: storageGbCtrl, label: 'Storage Limit (GB)', isNumeric: true)),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Row 2: Monthly mode, fixed fee, slots, end date
                  Row(
                    children: [
                      // Monthly mode dropdown
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Monthly Fee Mode', style: GoogleFonts.inter(fontSize: 11, color: text2)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: border),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButton<String>(
                                value: monthlyMode,
                                isExpanded: true,
                                underline: const SizedBox.shrink(),
                                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: text1),
                                items: const [
                                  DropdownMenuItem(value: 'linked', child: Text('Linked to Basic plan')),
                                  DropdownMenuItem(value: 'fixed',  child: Text('Fixed amount')),
                                ],
                                onChanged: (v) { if (v != null) onModeChange(v); },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TextField(
                          ctrl: monthlyFixedCtrl,
                          label: 'Monthly Fixed Fee (PKR)',
                          isNumeric: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _TextField(ctrl: slotsCtrl, label: 'Total Slots (0=∞)', isNumeric: true)),
                      const SizedBox(width: 10),
                      Expanded(child: _TextField(ctrl: endDateCtrl, label: 'Offer End Date (YYYY-MM-DD, blank=none)')),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: AdminButton.primary(
                          label: isSaving ? 'Saving...' : '💾 Save Founding Settings',
                          icon: isSaving ? null : Icons.save_rounded,
                          onPressed: isSaving ? null : onSave,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const AdminInfoBox.amber(
                    text: 'Monthly fee mode "Linked" reads the Basic plan price at billing time. '
                        '"Fixed" uses the amount above. Activation fee changes apply only to new activations.',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
