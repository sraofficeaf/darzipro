import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/theme_extensions.dart';

final adminAgenciesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = Supabase.instance.client;
  final res = await client.rpc('admin_get_agencies');
  if (res is List) {
    return List<Map<String, dynamic>>.from(res);
  }
  return [];
});

class AdminAgenciesScreen extends ConsumerStatefulWidget {
  const AdminAgenciesScreen({super.key});

  @override
  ConsumerState<AdminAgenciesScreen> createState() => _AdminAgenciesScreenState();
}

class _AdminAgenciesScreenState extends ConsumerState<AdminAgenciesScreen> {
  bool _isProcessing = false;

  String _fmt(dynamic minor) {
    final int val = minor is num ? (minor / 100).round() : 0;
    return 'Rs ${NumberFormat('#,##0').format(val)}';
  }

  Future<void> _showGrantAgencyDialog() async {
    final shopIdCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final percentCtrl = TextEditingController(text: '10.0');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Grant Agency Role', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: shopIdCtrl, decoration: const InputDecoration(labelText: 'Shop UUID', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Agency Code (e.g. AGY-LAHORE)', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Display Name', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: percentCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Initial Profit Share %', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
            child: const Text('Grant Role', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      final client = Supabase.instance.client;
      await client.rpc('admin_grant_agency_role', params: {
        'p_shop_id': shopIdCtrl.text.trim(),
        'p_agency_code': codeCtrl.text.trim(),
        'p_display_name': nameCtrl.text.trim(),
        'p_initial_percent': double.tryParse(percentCtrl.text.trim()) ?? 10.0,
      });
      if (mounted) {
        ref.invalidate(adminAgenciesProvider);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Agency role granted successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showUpdateRateDialog(String shopId, String currentPercent) async {
    final percentCtrl = TextEditingController(text: currentPercent);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Change Agency Profit Share', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rate changes take effect on the 1st of next month. Payments made this month continue at the current rate.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: percentCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'New Profit %', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
            child: const Text('Schedule Rate', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      final client = Supabase.instance.client;
      await client.rpc('admin_update_agency_rate', params: {
        'p_agency_shop_id': shopId,
        'p_new_percent': double.tryParse(percentCtrl.text.trim()) ?? 10.0,
      });
      if (mounted) {
        ref.invalidate(adminAgenciesProvider);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Rate change scheduled for 1st of next month!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _toggleAgencyActive(String shopId, bool currentlyActive) async {
    setState(() => _isProcessing = true);
    try {
      final client = Supabase.instance.client;
      if (currentlyActive) {
        await client.rpc('admin_revoke_agency_role', params: {'p_agency_shop_id': shopId});
      } else {
        await client.from('agency_profiles').update({'is_active': true, 'deactivated_at': null}).eq('shop_id', shopId);
      }
      if (mounted) {
        ref.invalidate(adminAgenciesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(currentlyActive ? 'Agency revoked (set to read-only).' : 'Agency reactivated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showAssignShopAgencyDialog(List<Map<String, dynamic>> agencies) async {
    final shopIdCtrl = TextEditingController();
    String? selectedAgencyId = agencies.isNotEmpty ? agencies.first['shop_id']?.toString() : null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Assign Shop to Agency', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter the UUID of the tailor shop to assign to an agency reseller:', style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: shopIdCtrl,
                decoration: const InputDecoration(labelText: 'Shop UUID', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 14),
              const Text('Select Agency Reseller:', style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: selectedAgencyId,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: agencies.map((a) {
                  final id = a['shop_id']?.toString() ?? '';
                  final name = a['display_name'] ?? a['agency_code'] ?? id;
                  return DropdownMenuItem(value: id, child: Text(name));
                }).toList(),
                onChanged: (v) => setDialogState(() => selectedAgencyId = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
              child: const Text('Assign Shop', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;
    final shopId = shopIdCtrl.text.trim();
    if (shopId.isEmpty || selectedAgencyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shop UUID and Agency are required.')));
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final client = Supabase.instance.client;
      await client.rpc('admin_assign_shop_agency', params: {
        'p_shop_id': shopId,
        'p_agency_shop_id': selectedAgencyId,
      });
      if (mounted) {
        ref.invalidate(adminAgenciesProvider);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Shop successfully assigned to agency!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final agenciesAsync = ref.watch(adminAgenciesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Agency Reseller Management', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: context.textPrimary)),
                    const SizedBox(height: 4),
                    Text('Manage agency reseller roles, assign shops, set monthly profit shares, and oversee payouts.', style: GoogleFonts.inter(fontSize: 13, color: context.text2)),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.link_rounded, size: 18),
                      label: const Text('Assign Shop to Agency'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isProcessing
                          ? null
                          : () {
                              final currentAgencies = agenciesAsync.valueOrNull ?? [];
                              if (currentAgencies.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('No active agencies available to assign to.')),
                                );
                                return;
                              }
                              _showAssignShopAgencyDialog(currentAgencies);
                            },
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_business_rounded, size: 18),
                      label: const Text('Grant Agency Role'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isProcessing ? null : _showGrantAgencyDialog,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: agenciesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (agencies) {
                  if (agencies.isEmpty) {
                    return Center(
                      child: Text('No agencies created yet. Click "Grant Agency Role" to get started.', style: GoogleFonts.inter(color: context.text2)),
                    );
                  }

                  return ListView.builder(
                    itemCount: agencies.length,
                    itemBuilder: (context, index) {
                      final a = agencies[index];
                      final shopId = a['shop_id'] as String;
                      final code = a['agency_code'] ?? '';
                      final displayName = a['display_name'] ?? '';
                      final shopName = a['shop_name'] ?? '';
                      final isActive = a['is_active'] == true;
                      final curPercent = a['current_percent']?.toString() ?? '0';
                      final pendingPercent = a['pending_percent']?.toString();
                      final pendingDate = a['pending_percent_effective_from']?.toString();
                      final totalShops = a['shops_count'] ?? 0;
                      final activeShops = a['active_shops_count'] ?? 0;
                      final totalEarned = _fmt(a['total_earned_minor']);
                      final available = _fmt(a['available_minor']);
                      final paid = _fmt(a['paid_minor']);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? const Color(0x2EFFFFFF) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(code, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF0D9488))),
                                    ),
                                    const SizedBox(width: 12),
                                    Text('$displayName ($shopName)', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary)),
                                  ],
                                ),
                                Switch(
                                  value: isActive,
                                  activeThumbColor: const Color(0xFF10B981),
                                  onChanged: _isProcessing ? null : (val) => _toggleAgencyActive(shopId, isActive),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Rate: $curPercent% profit share', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimary)),
                                      if (pendingPercent != null)
                                        Text('Scheduled: $pendingPercent% starting $pendingDate', style: GoogleFonts.inter(fontSize: 12, color: Colors.amber.shade700)),
                                      const SizedBox(height: 4),
                                      Text('Shops: $totalShops total ($activeShops active)', style: GoogleFonts.inter(fontSize: 12, color: context.text2)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('Earned: $totalEarned · Available: $available · Paid: $paid', style: GoogleFonts.inter(fontSize: 13, color: context.textPrimary)),
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.edit, size: 14),
                                      label: const Text('Change Rate'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF0D9488),
                                        side: const BorderSide(color: Color(0xFF0D9488)),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: _isProcessing ? null : () => _showUpdateRateDialog(shopId, curPercent),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
