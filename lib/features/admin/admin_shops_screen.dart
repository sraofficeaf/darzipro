import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/theme_extensions.dart';
import '../../shared/providers/admin_providers.dart';
import '../../core/services/admin_service.dart';
import 'widgets/admin_ui_kit.dart';
import 'admin_create_user_modal.dart';

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
                  AdminIconBtn(
                    icon: Icons.edit_rounded,
                    color: AdminColors.indigo,
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showEditShopDialog(context, shop);
                    },
                  ),
                  const SizedBox(width: 6),
                  AdminIconBtn(
                    icon: Icons.close_rounded,
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
              _DetailRow('Plan Tier', _str(shop['plan_code'] ?? shop['plan'] ?? shop['plan_type'], 'trial').toUpperCase()),
              _DetailRow('Level Unlocked', 'Level ${_toInt(shop['invite_level_unlocked'], 1)}'),
              _DetailRow('Storage Status', _getStorageStatus(shop)),
              const SizedBox(height: 10),
              _buildLifetimeAccessSection(context, shop, () => Navigator.pop(ctx)),
              const SizedBox(height: 12),
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
                child: AdminButton.primary(
                  label: _isSavingNotes ? 'Saving...' : 'Save Admin Notes',
                  icon: _isSavingNotes ? null : Icons.save_rounded,
                  onPressed: _isSavingNotes
                      ? null
                      : () async {
                          setSheetState(() {});
                          await _handleSaveNotes(shop);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
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
          title: Text('Edit Shop Details', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
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
            AdminButton.primary(
              label: 'Save Changes',
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
                  setState(() {
                    _selectedShop = null;
                  });
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to update shop details.')),
                  );
                }
              },
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
            // Top Header Bar (RepaintBoundary for zero scroll cost)
            RepaintBoundary(
              child: AdminPageHeader(
                title: 'Shop Management',
                subtitle: 'Monitor registered shops, plan tiers, storage usage & invite levels',
                action: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AdminIconBtn(
                      icon: Icons.refresh_rounded,
                      tooltip: 'Refresh',
                      onPressed: () => ref.invalidate(adminLicensesProvider),
                    ),
                    const SizedBox(width: 8),
                    AdminButton.primary(
                      label: 'Add Shop Owner',
                      icon: Icons.person_add_rounded,
                      onPressed: () async {
                        final created = await showDialog<bool>(
                          context: context,
                          builder: (_) => const AdminCreateUserModal(),
                        );
                        if (created == true) {
                          ref.invalidate(adminLicensesProvider);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Search & Filter Toolbar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: surface,
                border: Border(bottom: BorderSide(color: border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                        style: GoogleFonts.inter(fontSize: 13, color: text1),
                        decoration: InputDecoration(
                          hintText: 'Search shop, owner, code...',
                          hintStyle: GoogleFonts.inter(fontSize: 12, color: text2),
                          prefixIcon: Icon(Icons.search_rounded, size: 18, color: text2),
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          filled: true,
                          fillColor: bg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AdminColors.indigo),
                          ),
                        ),
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
                      DropdownMenuItem(value: 'trial', child: Text('⏳ Free Trial')),
                      DropdownMenuItem(value: 'basic', child: Text('⚡ Basic Plan')),
                      DropdownMenuItem(value: 'standard', child: Text('🚀 Standard Plan')),
                      DropdownMenuItem(value: 'unlimited', child: Text('💎 Unlimited Plan')),
                      DropdownMenuItem(value: 'founding', child: Text('👑 Founding Member')),
                      DropdownMenuItem(value: 'lifetime', child: Text('👑 Lifetime Access')),
                      DropdownMenuItem(value: 'deleted', child: Text('🗑️ Deleted Accounts')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedFilter = v);
                    },
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: licensesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AdminColors.indigo)),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('Error loading shops: $err', style: GoogleFonts.inter(color: AdminColors.rose)),
                  ),
                ),
                data: (shops) {
                  final filtered = shops.where((s) {
                    if (s['is_platform_account'] == true) return false;

                    final name = _getShopName(s).toLowerCase();
                    final owner = _getOwnerName(s).toLowerCase();
                    final phone = _getPhone(s).toLowerCase();
                    final code = _str(s['invite_code'], '').toLowerCase();
                    final city = _getCity(s).toLowerCase();
                    final shopStatus = _str(s['status'], 'active');

                    if (_searchQuery.isNotEmpty) {
                      final match = name.contains(_searchQuery) ||
                          owner.contains(_searchQuery) ||
                          phone.contains(_searchQuery) ||
                          code.contains(_searchQuery) ||
                          city.contains(_searchQuery);
                      if (!match) return false;
                    }

                    if (_selectedFilter == 'deleted') return shopStatus == 'deleted';
                    if (shopStatus == 'deleted') return false;

                    if (_selectedFilter == 'all') return true;
                    final isLifetime = s['lifetime_access'] == true || s['subscription_status'] == 'lifetime';
                    if (_selectedFilter == 'lifetime') return isLifetime;
                    final p = _str(s['plan_code'] ?? s['plan'] ?? s['plan_type'], 'trial').toLowerCase();
                    if (_selectedFilter == 'trial') return p == 'trial';
                    if (_selectedFilter == 'basic') return p == 'basic';
                    if (_selectedFilter == 'standard') return p == 'standard';
                    if (_selectedFilter == 'unlimited') return p == 'unlimited';
                    if (_selectedFilter == 'founding') return p == 'founding';
                    return p == _selectedFilter;
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
                                width: 360,
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
                          itemBuilder: (ctx, idx) => RepaintBoundary(
                            child: _buildMobileShopCard(context, filtered[idx]),
                          ),
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
        final isLifetime = (s['lifetime_access'] == true) || (s['subscription_status'] == 'lifetime');
        final plan = _str(s['plan_code'] ?? s['plan'] ?? s['plan_type'], 'trial').toLowerCase();
        final level = _toInt(s['invite_level_unlocked'], 1);
        final (planLabel, planColor) = _getPlanBadgeInfo(plan, isLifetime);
        final storageStr = _getStorageStatus(s);

        return RepaintBoundary(
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AdminColors.indigo.withValues(alpha: 0.08)
                  : surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? AdminColors.indigo
                    : isDeleted
                        ? AdminColors.rose.withValues(alpha: 0.3)
                        : border,
              ),
              boxShadow: context.cardShadow,
            ),
            child: ListTile(
              onTap: () => _selectShop(s),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      _getShopName(s),
                      style: GoogleFonts.outfit(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: isDeleted ? AdminColors.rose : text1,
                      ),
                    ),
                  ),
                  if (isDeleted)
                    const AdminBadge(label: '🗑️ Deleted', color: AdminColors.rose)
                  else ...[AdminBadge(label: planLabel, color: planColor)],
                  const SizedBox(width: 8),
                  AdminBadge(label: 'Lvl $level', color: AdminColors.violet),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Owner: ${_getOwnerName(s)} · Code: ${_str(s['invite_code'], 'None')}',
                        style: GoogleFonts.inter(fontSize: 11, color: text2),
                      ),
                    ),
                    if (!isDeleted)
                      Text(
                        storageStr,
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: text2),
                      ),
                  ],
                ),
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
    final isLifetime = (s['lifetime_access'] == true) || (s['subscription_status'] == 'lifetime');
    final plan = _str(s['plan_code'] ?? s['plan'] ?? s['plan_type'], 'trial').toLowerCase();
    final level = _toInt(s['invite_level_unlocked'], 1);
    final (planLabel, planColor) = _getPlanBadgeInfo(plan, isLifetime);
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
        boxShadow: context.cardShadow,
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
                              AdminBadge(label: planLabel, color: planColor),
                              const SizedBox(height: 4),
                              AdminBadge(label: 'Lvl $level', color: AdminColors.violet),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(height: 1, color: border.withValues(alpha: 0.6)),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.qr_code_rounded, size: 14, color: AdminColors.emerald),
                              const SizedBox(width: 4),
                              Text('Code: ', style: GoogleFonts.inter(fontSize: 11.5, color: text2)),
                              Text(inviteCode, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: text1)),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.storage_rounded, size: 14, color: AdminColors.blue),
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
                          Text('Invited By: $invitedByCode', style: GoogleFonts.inter(fontSize: 11.5, color: text2)),
                          Row(
                            children: [
                              Text('Details & Notes', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: AdminColors.indigo)),
                              const Icon(Icons.chevron_right_rounded, size: 16, color: AdminColors.indigo),
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
    final plan = _str(s['plan_code'] ?? s['plan'] ?? s['plan_type'], 'trial').toLowerCase();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(_getShopName(s), style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: text1))),
              AdminIconBtn(icon: Icons.edit_rounded, color: AdminColors.indigo, onPressed: () => _showEditShopDialog(context, s)),
              const SizedBox(width: 4),
              AdminIconBtn(icon: Icons.close, onPressed: () => setState(() => _selectedShop = null)),
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
          const SizedBox(height: 10),
          _buildLifetimeAccessSection(context, s),
          const SizedBox(height: 16),

          Text('Admin Notes', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: text1)),
          const SizedBox(height: 6),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Enter internal notes...'),
          ),
          const SizedBox(height: 10),
          AdminButton.primary(
            label: _isSavingNotes ? 'Saving...' : 'Save Notes',
            onPressed: _isSavingNotes ? null : () => _handleSaveNotes(),
          ),
        ],
      ),
    );
  }

  Widget _buildLifetimeAccessSection(BuildContext context, Map<String, dynamic> shop, [VoidCallback? onDone]) {
    final isLifetime = (shop['lifetime_access'] == true) || (shop['subscription_status'] == 'lifetime');
    final text1 = context.text1;
    final text2 = context.text2;

    if (isLifetime) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AdminColors.amber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AdminColors.amber),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.workspace_premium_rounded, color: AdminColors.amber, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('👑 Lifetime Unlimited Access Active',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: AdminColors.amber)),
                      Text('Permanent unlimited access. No monthly fees or renewals.',
                          style: GoogleFonts.inter(fontSize: 11, color: text2)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                AdminButton.danger(
                  label: 'Revoke Lifetime',
                  icon: Icons.remove_circle_outline_rounded,
                  onPressed: () {
                    if (onDone != null) onDone();
                    _showRevokeLifetimeDialog(context, shop);
                  },
                ),
                const SizedBox(width: 8),
                AdminButton.ghost(
                  label: 'Change Plan',
                  icon: Icons.swap_horiz_rounded,
                  onPressed: () {
                    if (onDone != null) onDone();
                    _showChangePlanDialog(context, shop);
                  },
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('👑 Lifetime Access',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: text1)),
                    Text('Override subscription with permanent unlimited access.',
                        style: GoogleFonts.inter(fontSize: 11, color: text2)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              AdminButton.amber(
                label: 'Grant Lifetime',
                icon: Icons.workspace_premium_rounded,
                onPressed: () {
                  if (onDone != null) onDone();
                  _showGrantLifetimeDialog(context, shop);
                },
              ),
              const SizedBox(width: 8),
              AdminButton.ghost(
                label: 'Change Plan',
                icon: Icons.swap_horiz_rounded,
                onPressed: () {
                  if (onDone != null) onDone();
                  _showChangePlanDialog(context, shop);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRevokeLifetimeDialog(BuildContext context, Map<String, dynamic> shop) {
    final shopId = _str(shop['id'], '');
    final shopName = _getShopName(shop);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AdminColors.rose, size: 26),
            const SizedBox(width: 8),
            Text('Revoke Lifetime Access', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text('Are you sure you want to revoke lifetime access for "$shopName"? The shop will revert to standard trial/active plan rules.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          AdminButton.danger(
            label: 'Revoke Lifetime',
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await AdminService.instance.revokeLifetimeAccess(shopId, newPlan: 'trial');
              if (context.mounted) {
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lifetime access revoked for $shopName')));
                  ref.invalidate(adminLicensesProvider);
                  setState(() => _selectedShop = null);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to revoke lifetime access')));
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showChangePlanDialog(BuildContext context, Map<String, dynamic> shop) {
    final shopId = _str(shop['id'], '');
    final shopName = _getShopName(shop);
    String selectedPlan = _str(shop['plan_code'] ?? shop['plan'], 'trial');
    String selectedStatus = _str(shop['subscription_status'], 'active');

    final availablePlans = ['trial', 'basic', 'standard', 'unlimited', 'founding'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Change Plan for $shopName', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select New Plan Tier:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: availablePlans.contains(selectedPlan) ? selectedPlan : 'standard',
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: availablePlans.map((p) => DropdownMenuItem(value: p, child: Text(p.toUpperCase()))).toList(),
                onChanged: (v) => setDialogState(() => selectedPlan = v ?? 'standard'),
              ),
              const SizedBox(height: 14),
              Text('Subscription Status:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: ['active', 'trial', 'past_due', 'cancelled'].contains(selectedStatus) ? selectedStatus : 'active',
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'trial', child: Text('Trial')),
                  DropdownMenuItem(value: 'past_due', child: Text('Past Due')),
                  DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                ],
                onChanged: (v) => setDialogState(() => selectedStatus = v ?? 'active'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            AdminButton.primary(
              label: 'Apply Plan Change',
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await AdminService.instance.updateShopPlan(
                  shopId,
                  newPlan: selectedPlan,
                  newStatus: selectedStatus,
                );
                if (context.mounted) {
                  if (ok) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Plan updated to ${selectedPlan.toUpperCase()}!')));
                    ref.invalidate(adminLicensesProvider);
                    setState(() => _selectedShop = null);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update shop plan')));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showGrantLifetimeDialog(BuildContext context, Map<String, dynamic> shop) {
    final shopId = _str(shop['id'], '');
    final shopName = _getShopName(shop);
    final reasonCtrl = TextEditingController();
    double storageGb = 5.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.workspace_premium_rounded, color: AdminColors.amber, size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Grant Lifetime Access',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Grant permanent unlimited access to "$shopName"?',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                const AdminInfoBox.amber(
                  text: '• Plan set to Unlimited permanently.\n• Shop never locks into read-only mode.\n• No monthly subscription fees required.',
                ),
                const SizedBox(height: 14),
                Text('Storage Quota: ${storageGb.toStringAsFixed(1)} GB',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                Slider(
                  value: storageGb,
                  min: 1.0,
                  max: 20.0,
                  divisions: 19,
                  label: '${storageGb.toInt()} GB',
                  activeColor: AdminColors.amber,
                  onChanged: (v) => setDialogState(() => storageGb = v),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Reason / Admin Notes',
                    hintText: 'e.g. Grandfathered early adopter / VIP partner',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            AdminButton.amber(
              label: 'Confirm Lifetime Access',
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await AdminService.instance.grantLifetimeAccess(
                  shopId,
                  storageGb: storageGb,
                );
                final reason = reasonCtrl.text.trim();
                if (reason.isNotEmpty) {
                  final existing = _str(shop['notes'], '');
                  final notes = existing.isEmpty
                      ? '👑 Lifetime granted: $reason'
                      : '$existing\n[${DateTime.now().toIso8601String().split('T')[0]}] Lifetime granted: $reason';
                  await AdminService.instance.updateLicenseNotes(shopId, notes);
                }
                if (context.mounted) {
                  if (ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('👑 Lifetime access granted to $shopName!')),
                    );
                    ref.invalidate(adminLicensesProvider);
                    setState(() => _selectedShop = null);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to grant lifetime access')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  (String, Color) _getPlanBadgeInfo(String plan, [bool isLifetime = false]) {
    if (isLifetime) return ('👑 Lifetime Unlimited', AdminColors.amber);
    return switch (plan.toLowerCase()) {
      'trial' => ('⏳ Free Trial', AdminColors.text3),
      'basic' => ('⚡ Basic Plan', AdminColors.blue),
      'standard' => ('🚀 Standard Plan', AdminColors.violet),
      'unlimited' => ('💎 Unlimited Plan', AdminColors.emerald),
      'founding' => ('👑 Founding Member', AdminColors.amber),
      'mobile_only' || 'full_access' || 'full_access_3yr' => ('👑 Lifetime (Legacy)', AdminColors.amber),
      _ => ('⚡ $plan Plan', AdminColors.blue),
    };
  }

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
    final mb = (bytes / (1024 * 1024)).toStringAsFixed(1);
    return '$mb MB / Limited';
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
