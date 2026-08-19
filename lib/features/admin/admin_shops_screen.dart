import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../shared/providers/admin_providers.dart';
import '../../core/services/admin_service.dart';

class AdminShopsScreen extends ConsumerStatefulWidget {
  const AdminShopsScreen({super.key});

  @override
  ConsumerState<AdminShopsScreen> createState() => _AdminShopsScreenState();
}

class _AdminShopsScreenState extends ConsumerState<AdminShopsScreen> {
  String _selectedFilter = 'all'; // 'all' | 'mobile_only' | 'full_access' | 'full_access_3yr'
  String _searchQuery = '';
  Map<String, dynamic>? _selectedShop;
  final _notesCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  bool _isSavingNotes = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Ultra-Safe Type Helpers ───────────────────────────────────────────────
  String _str(dynamic v, [String fallback = 'N/A']) {
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  int _toInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  String _getShopName(Map<String, dynamic> s) =>
      _str(s['shop_name'] ?? s['name'] ?? s['shopName'], 'Shop');

  String _getOwnerName(Map<String, dynamic> s) =>
      _str(s['shop_owner_name'] ?? s['owner_name'] ?? s['owner'], 'N/A');

  String _getCity(Map<String, dynamic> s) =>
      _str(s['shop_city'] ?? s['city'], 'N/A');

  String _getPhone(Map<String, dynamic> s) =>
      _str(s['whatsapp_number'] ?? s['whatsapp'] ?? s['phone'], 'N/A');

  void _selectShop(Map<String, dynamic> shop) {
    setState(() {
      _selectedShop = shop;
      _notesCtrl.text = _str(shop['notes'], '');
    });
  }

  Future<void> _handleSaveNotes([Map<String, dynamic>? shopToSave]) async {
    final target = shopToSave ?? _selectedShop;
    if (target == null) return;
    setState(() => _isSavingNotes = true);

    final id = _str(target['id'], '');
    if (id.isEmpty) {
      setState(() => _isSavingNotes = false);
      return;
    }

    final success = await AdminService.instance.updateLicenseNotes(
      id,
      _notesCtrl.text.trim(),
    );

    setState(() => _isSavingNotes = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin notes saved successfully!')),
      );
      ref.invalidate(adminLicensesProvider);
    }
  }

  void _showShopDetailBottomSheet(BuildContext context, Map<String, dynamic> shop) {
    _notesCtrl.text = _str(shop['notes'], '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _getShopName(shop),
                      style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: context.text1),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, color: AppColors.accent),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showEditShopDialog(context, shop);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _DetailRow('Owner Name', _getOwnerName(shop)),
              _DetailRow('Owner Email', _str(shop['email'], 'N/A')),
              _DetailRow('WhatsApp / Phone', _getPhone(shop)),
              _DetailRow('Address', _str(shop['address'], 'N/A')),
              _DetailRow('City', _getCity(shop)),
              _DetailRow('Invite Code', _str(shop['invite_code'], 'None')),
              _DetailRow('Invited By', _str(shop['invited_by_code'], 'Direct Sign Up')),
              _DetailRow('Plan Tier', _str(shop['plan'] ?? shop['plan_type'], 'mobile_only').toUpperCase()),
              _DetailRow('Level Unlocked', 'Level ${_toInt(shop['invite_level_unlocked'], 1)}'),
              _DetailRow('Storage Status', _getStorageStatus(shop)),
              const SizedBox(height: 16),
              Text('Admin Notes', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: context.text1)),
              const SizedBox(height: 6),
              TextField(
                controller: _notesCtrl,
                maxLines: 3,
                style: GoogleFonts.inter(fontSize: 13, color: context.text1),
                decoration: InputDecoration(
                  hintText: 'Enter internal admin notes for this shop...',
                  hintStyle: GoogleFonts.inter(fontSize: 12, color: context.text2),
                  filled: true,
                  fillColor: context.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.border)),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSavingNotes
                      ? null
                      : () async {
                          setSheetState(() {});
                          await _handleSaveNotes(shop);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Save Admin Notes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditShopDialog(BuildContext context, Map<String, dynamic> shop) async {
    final shopId = _str(shop['id'], '');
    final nameCtrl = TextEditingController(text: _getShopName(shop));
    final phoneCtrl = TextEditingController(text: shop['phone'] ?? shop['whatsapp'] ?? '');
    final addressCtrl = TextEditingController(text: shop['address'] ?? '');
    final emailCtrl = TextEditingController();
    
    // Fetch email dynamically from licenses table
    try {
      final client = AdminService.instance.client;
      final lic = await client.from('licenses').select('email').eq('shop_id', shopId).maybeSingle();
      if (lic != null) {
        emailCtrl.text = _str(lic['email'], '');
      }
    } catch (_) {}

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('✏️ Edit Shop Details', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Shop Name')),
                const SizedBox(height: 10),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone / WhatsApp Number')),
                const SizedBox(height: 10),
                TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Shop Address')),
                const SizedBox(height: 10),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Owner Email')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final phone = phoneCtrl.text.trim();
                final address = addressCtrl.text.trim();
                final email = emailCtrl.text.trim();

                if (name.isEmpty || phone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Shop Name and Phone are required')),
                  );
                  return;
                }

                final ok = await AdminService.instance.updateShopDetails(
                  shopId: shopId,
                  name: name,
                  phone: phone,
                  address: address,
                  email: email,
                );

                if (ok && context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Shop details updated successfully!')),
                  );
                  ref.invalidate(adminLicensesProvider);
                  // Clear active selection to force reload
                  setState(() {
                    _selectedShop = null;
                  });
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to update shop details.')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateManualModal(BuildContext context) {
    final shopNameCtrl = TextEditingController();
    final ownerCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String planSelected = 'full_access';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('➕ Create Manual Shop License', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: shopNameCtrl, decoration: const InputDecoration(labelText: 'Shop Name')),
                const SizedBox(height: 10),
                TextField(controller: ownerCtrl, decoration: const InputDecoration(labelText: 'Owner Name')),
                const SizedBox(height: 10),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number')),
                const SizedBox(height: 10),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email Address')),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: planSelected,
                  decoration: const InputDecoration(labelText: 'Select Plan Tier'),
                  items: const [
                    DropdownMenuItem(value: 'mobile_only', child: Text('📱 Basic Plan (Rs 12,000)')),
                    DropdownMenuItem(value: 'full_access', child: Text('🚀 Professional Plan (Rs 35,000)')),
                    DropdownMenuItem(value: 'full_access_3yr', child: Text('👑 Enterprise Plan (Rs 70,000)')),
                  ],
                  onChanged: (v) {
                    if (v != null) setModalState(() => planSelected = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (shopNameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter Shop Name & Phone.')));
                  return;
                }
                int amount = 12000;
                if (planSelected == 'full_access_3yr') {
                  amount = 70000;
                } else if (planSelected == 'full_access') {
                  amount = 35000;
                }

                final ok = await AdminService.instance.createLicense(
                  shopName: shopNameCtrl.text.trim(),
                  ownerName: ownerCtrl.text.trim(),
                  city: 'Manual Admin Entry',
                  whatsapp: phoneCtrl.text.trim(),
                  plan: planSelected,
                  durationDays: planSelected == 'full_access_3yr' ? 1095 : 365,
                  key: 'MANUAL-${DateTime.now().millisecondsSinceEpoch}',
                  paymentMethod: 'Manual Cash / Transfer',
                  amount: amount,
                  transactionId: 'MANUAL-ADMIN',
                );

                if (ok && context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Manual License created successfully!')));
                  ref.invalidate(adminLicensesProvider);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
              child: const Text('Create License'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final licensesAsync = ref.watch(adminLicensesProvider);
    final isWide = MediaQuery.of(context).size.width >= 720;

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
            // ── Top Header Bar (Responsive) ──────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surface,
                border: Border(bottom: BorderSide(color: border)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 650;

                  if (isMobile) {
                    // 📱 Mobile Header Layout (Stacked)
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '👥 Shop Management',
                              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: text1),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh_rounded, size: 20),
                              color: text2,
                              tooltip: 'Refresh',
                              onPressed: () => ref.invalidate(adminLicensesProvider),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            // Search bar
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                                style: GoogleFonts.inter(fontSize: 12, color: text1),
                                decoration: InputDecoration(
                                  hintText: 'Search shop, owner, code...',
                                  hintStyle: GoogleFonts.inter(fontSize: 12, color: text2),
                                  prefixIcon: Icon(Icons.search_rounded, size: 18, color: text2),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  filled: true,
                                  fillColor: bg,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: border)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: border)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Plan Filter Dropdown
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: border),
                              ),
                              child: DropdownButton<String>(
                                value: _selectedFilter,
                                dropdownColor: surface,
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: text1),
                                underline: const SizedBox.shrink(),
                                icon: Icon(Icons.filter_list_rounded, size: 16, color: text2),
                                items: const [
                                  DropdownMenuItem(value: 'all', child: Text('All Plans')),
                                  DropdownMenuItem(value: 'mobile_only', child: Text('📱 Mobile')),
                                  DropdownMenuItem(value: 'full_access', child: Text('⭐ Full')),
                                  DropdownMenuItem(value: 'full_access_3yr', child: Text('💎 3Yr')),
                                  DropdownMenuItem(value: 'deleted', child: Text('🗑️ Deleted')),
                                ],
                                onChanged: (v) {
                                  if (v != null) setState(() => _selectedFilter = v);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _showCreateManualModal(context),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('+ Create Manual License'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  // 🖥️ Desktop Header Layout (Single Row)
                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '👥 Shop Management',
                              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: text1),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Monitor registered shops, plan tiers, storage usage & invite levels',
                              style: GoogleFonts.inter(fontSize: 12, color: text2),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 200,
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                          style: GoogleFonts.inter(fontSize: 12, color: text1),
                          decoration: InputDecoration(
                            hintText: 'Search shop...',
                            hintStyle: GoogleFonts.inter(fontSize: 12, color: text2),
                            prefixIcon: Icon(Icons.search_rounded, size: 16, color: text2),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            filled: true,
                            fillColor: bg,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: border)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      DropdownButton<String>(
                        value: _selectedFilter,
                        dropdownColor: surface,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: text1),
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Plans')),
                          DropdownMenuItem(value: 'mobile_only', child: Text('📱 Basic Plan')),
                          DropdownMenuItem(value: 'full_access', child: Text('🚀 Professional Plan')),
                          DropdownMenuItem(value: 'full_access_3yr', child: Text('👑 Enterprise Plan')),
                          DropdownMenuItem(value: 'deleted', child: Text('🗑️ Deleted Accounts')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedFilter = v);
                        },
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showCreateManualModal(context),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('+ Create Manually'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // ── Main Content ──────────────────────────────────────────────────
            Expanded(
              child: licensesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('Error loading shops: $err', style: GoogleFonts.inter(color: Colors.red)),
                  ),
                ),
                data: (shops) {
                  final filtered = shops.where((s) {
                    // Always hide platform account from normal lists
                    if (s['is_platform_account'] == true) return false;

                    final name = _getShopName(s).toLowerCase();
                    final owner = _getOwnerName(s).toLowerCase();
                    final phone = _getPhone(s).toLowerCase();
                    final code = _str(s['invite_code'], '').toLowerCase();
                    final city = _getCity(s).toLowerCase();
                    final shopStatus = _str(s['status'], 'active');

                    // Search query filter
                    if (_searchQuery.isNotEmpty) {
                      final match = name.contains(_searchQuery) ||
                          owner.contains(_searchQuery) ||
                          phone.contains(_searchQuery) ||
                          code.contains(_searchQuery) ||
                          city.contains(_searchQuery);
                      if (!match) return false;
                    }

                    // Deleted filter: show only deleted accounts
                    if (_selectedFilter == 'deleted') return shopStatus == 'deleted';

                    // Normal filters: hide deleted accounts
                    if (shopStatus == 'deleted') return false;

                    // Plan filter
                    if (_selectedFilter == 'all') return true;
                    final p = _str(s['plan'] ?? s['plan_type'], 'mobile_only').toLowerCase();
                    if (_selectedFilter == 'full_access_3yr') return p == 'full_access_3yr';
                    if (_selectedFilter == 'full_access') return p == 'full_access' || p == 'pro' || p == 'business';
                    if (_selectedFilter == 'mobile_only') return p == 'mobile_only' || p == 'free' || p == 'starter' || p.isEmpty;
                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.storefront_outlined, size: 48, color: text2.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          Text('No shops match your search or filter.', style: GoogleFonts.inter(color: text2, fontSize: 13)),
                        ],
                      ),
                    );
                  }

                  return isWide
                      ? Row(
                          children: [
                            Expanded(flex: 3, child: _buildShopsTable(context, filtered)),
                            if (_selectedShop != null)
                              Container(
                                width: 340,
                                decoration: BoxDecoration(
                                  color: surface,
                                  border: Border(left: BorderSide(color: border)),
                                ),
                                child: _buildShopDetailPanel(context, _selectedShop!),
                              ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, idx) => _buildMobileShopCard(context, filtered[idx]),
                        );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopsTable(BuildContext context, List<Map<String, dynamic>> shops) {
    final surface = context.surface;
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: shops.length,
      itemBuilder: (context, index) {
        final s = shops[index];
        final isSelected = _selectedShop?['id'] == s['id'];
        final isDeleted = _str(s['status'], 'active') == 'deleted';
        final plan = _str(s['plan'] ?? s['plan_type'], 'mobile_only').toLowerCase();
        final level = _toInt(s['invite_level_unlocked'], 1);
        final (planLabel, planColor) = _getPlanBadgeInfo(plan);
        final storageStr = _getStorageStatus(s);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accent.withValues(alpha: 0.1)
                : isDeleted
                    ? const Color(0x08FF3A58)
                    : surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppColors.accent
                  : isDeleted
                      ? const Color(0x33FF3A58)
                      : border,
            ),
          ),
          child: ListTile(
            onTap: () => _selectShop(s),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    _getShopName(s),
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDeleted ? const Color(0xFFFF3A58) : text1,
                    ),
                  ),
                ),
                if (isDeleted)
                  _Badge(label: '🗑️ Deleted', color: const Color(0xFFFF3A58))
                else ...[_Badge(label: planLabel, color: planColor)],
                const SizedBox(width: 8),
                _Badge(label: 'Lvl $level', color: const Color(0xFF8B5CF6)),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(child: Text('Owner: ${_getOwnerName(s)} · Code: ${_str(s['invite_code'], 'None')}', style: GoogleFonts.inter(fontSize: 11, color: text2))),
                  if (!isDeleted) Text(storageStr, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: text2)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileShopCard(BuildContext context, Map<String, dynamic> s) {
    final surface = context.surface;
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;

    final shopName = _getShopName(s);
    final ownerName = _getOwnerName(s);
    final phone = _getPhone(s);
    final plan = _str(s['plan'] ?? s['plan_type'], 'mobile_only').toLowerCase();
    final level = _toInt(s['invite_level_unlocked'], 1);
    final (planLabel, planColor) = _getPlanBadgeInfo(plan);
    final storageStr = _getStorageStatus(s);
    final inviteCode = _str(s['invite_code'], 'None');
    final invitedByCode = _str(s['invited_by_code'], 'Direct');

    final email = _str(s['email'], 'N/A');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            Container(height: 3.5, color: planColor),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showShopDetailBottomSheet(context, s),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                // Header Row: Shop name & Plan badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shopName,
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: text1),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Owner: $ownerName ${email != "N/A" ? "· $email" : ""} ${phone != "N/A" ? "· $phone" : ""}',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: text2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _Badge(label: planLabel, color: planColor),
                        const SizedBox(height: 4),
                        _Badge(label: 'Lvl $level', color: const Color(0xFF8B5CF6)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(height: 1, color: border.withValues(alpha: 0.8)),
                const SizedBox(height: 10),
                // Subtitle info row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.qr_code_rounded, size: 14, color: Color(0xFF10CBA0)),
                        const SizedBox(width: 4),
                        Text('Code: ', style: GoogleFonts.inter(fontSize: 11.5, color: text2)),
                        Text(inviteCode, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: text1)),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.storage_rounded, size: 14, color: Color(0xFF3B82F6)),
                        const SizedBox(width: 4),
                        Text(storageStr, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: text2)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Invited By: $invitedByCode',
                      style: GoogleFonts.inter(fontSize: 11.5, color: text2),
                    ),
                    Row(
                      children: [
                        Text('Details & Notes', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.accent)),
                        const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.accent),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  ),
),
);
}




  Widget _buildShopDetailPanel(BuildContext context, Map<String, dynamic> s) {
    final text1 = context.text1;
    final plan = _str(s['plan'] ?? s['plan_type'], 'mobile_only').toLowerCase();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(_getShopName(s), style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: text1))),
              IconButton(icon: const Icon(Icons.edit_rounded, color: AppColors.accent), onPressed: () => _showEditShopDialog(context, s)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _selectedShop = null)),
            ],
          ),
          const SizedBox(height: 12),
          _DetailRow('Owner Name', _getOwnerName(s)),
          _DetailRow('WhatsApp / Phone', _getPhone(s)),
          _DetailRow('Address', _str(s['address'], 'N/A')),
          _DetailRow('City', _getCity(s)),
          _DetailRow('Invite Code', _str(s['invite_code'], 'None')),
          _DetailRow('Invited By', _str(s['invited_by_code'], 'Direct Sign Up')),
          _DetailRow('Plan Tier', plan.toUpperCase()),
          _DetailRow('Level Unlocked', 'Level ${_toInt(s['invite_level_unlocked'], 1)}'),
          _DetailRow('Storage Status', _getStorageStatus(s)),
          const SizedBox(height: 16),

          Text('Admin Notes', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: text1)),
          const SizedBox(height: 6),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Enter internal notes...'),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _isSavingNotes ? null : () => _handleSaveNotes(),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: _isSavingNotes ? const CircularProgressIndicator() : const Text('Save Notes'),
          ),
        ],
      ),
    );
  }

  (String, Color) _getPlanBadgeInfo(String plan) => switch (plan) {
        'mobile_only' => ('📱 Basic Plan', const Color(0xFF3B82F6)),
        'full_access' => ('🚀 Professional Plan', const Color(0xFFF5A623)),
        'full_access_3yr' => ('👑 Enterprise Plan', const Color(0xFF10B981)),
        _ => ('📱 Basic Plan', const Color(0xFF3B82F6)),
      };

  String _getStorageStatus(Map<String, dynamic> s) {
    if (s['storage_addon_active'] == true) return 'Unlimited (Add-on Active)';
    final bundledStr = s['bundled_storage_expires_at']?.toString();
    if (bundledStr != null && bundledStr.isNotEmpty) {
      final exp = DateTime.tryParse(bundledStr);
      if (exp != null && DateTime.now().isBefore(exp)) {
        final days = exp.difference(DateTime.now()).inDays;
        return 'Unlimited (3Yr, $days d)';
      }
    }
    final bytes = _toInt(s['storage_used_bytes'], 0);
    final mb = (bytes / 1000000).toStringAsFixed(1);
    return '$mb MB / Limited';
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String val;

  const _DetailRow(this.label, this.val);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: context.text2)),
          Expanded(
            child: Text(
              val,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: context.text1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
