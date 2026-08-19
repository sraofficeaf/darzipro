import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/utils/plan_utils.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../shared/providers/invite_providers.dart';
import '../widgets/ie_earning_card.dart';
import '../widgets/ie_invite_row.dart';

class IeMyInvitesScreen extends ConsumerStatefulWidget {
  const IeMyInvitesScreen({super.key});

  @override
  ConsumerState<IeMyInvitesScreen> createState() => _IeMyInvitesScreenState();
}

class _IeMyInvitesScreenState extends ConsumerState<IeMyInvitesScreen> {
  String _search = '';
  String _filter = 'all'; // all / active / pending / inactive

  @override
  Widget build(BuildContext context) {
    final shopsAsync = ref.watch(myInvitedShopsProvider);
    final text1 = context.text1;
    final text2 = context.text2;
    final border = context.border;

    return Scaffold(
      backgroundColor: context.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Search + Filter ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Invited Shops',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: text1,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                  style: GoogleFonts.inter(fontSize: 13, color: text1),
                  decoration: InputDecoration(
                    hintText: 'Search shop name...',
                    hintStyle:
                        GoogleFonts.inter(fontSize: 13, color: text2),
                    prefixIcon:
                        Icon(Icons.search_rounded, size: 18, color: text2),
                    filled: true,
                    fillColor: context.surface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: ieAccent, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['all', 'active', 'pending', 'inactive']
                        .map((f) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _FilterChip(
                                label: f[0].toUpperCase() + f.substring(1),
                                isSelected: _filter == f,
                                onTap: () => setState(() => _filter = f),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),

          // ── List ─────────────────────────────────────────────────────
          Expanded(
            child: shopsAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: ieAccent)),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Color(0xFFFF3A58), size: 36),
                    const SizedBox(height: 12),
                    Text('Failed to load shops',
                        style: GoogleFonts.inter(color: text2)),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => ref.invalidate(myInvitedShopsProvider),
                      child: Text('Retry',
                          style: GoogleFonts.inter(
                              color: ieAccent, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              data: (shops) {
                final filtered = shops.where((s) {
                  final name =
                      (s['name'] as String? ?? '').toLowerCase();
                  final status = s['status'] as String? ?? 'inactive';
                  final matchSearch =
                      _search.isEmpty || name.contains(_search);
                  final matchFilter =
                      _filter == 'all' || status == _filter;
                  return matchSearch && matchFilter;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🤝',
                            style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 16),
                        Text(
                          shops.isEmpty
                              ? 'No shops invited yet'
                              : 'No matches found',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: text1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          shops.isEmpty
                              ? 'Share your invite code to get started!'
                              : 'Try a different search or filter',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: text2),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: ieAccent,
                  onRefresh: () async =>
                      ref.invalidate(myInvitedShopsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, i) => IeInviteRow(
                      shop: filtered[i],
                      onTap: () =>
                          _showDetail(context, filtered[i]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showDetail(
      BuildContext context, Map<String, dynamic> shop) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _InviteDetailScreen(shop: shop),
      ),
    );
  }
}

// ── Filter chip ──────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? ieAccent : context.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? ieAccent : context.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? const Color(0xFF0A1428)
                : context.text2,
          ),
        ),
      ),
    );
  }
}

// ── Invite Detail Sub-screen ─────────────────────────────────────────────────
class _InviteDetailScreen extends ConsumerWidget {
  final Map<String, dynamic> shop;
  const _InviteDetailScreen({required this.shop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text1 = context.text1;
    final text2 = context.text2;
    final surface = context.surface;
    final border = context.border;
    final name = shop['name'] as String? ?? 'Unknown';
    final earned = shop['total_earned_from'] as int? ?? 0;
    final status = shop['status'] as String? ?? 'inactive';
    final plan = shop['plan'] as String? ?? 'full_access';
    final createdAt = shop['created_at'] as String? ?? '';

    final earningsAsync = ref.watch(profitEarningsProvider);

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: text1),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          name,
          style: GoogleFonts.outfit(
              fontSize: 17, fontWeight: FontWeight.w800, color: text1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
              ),
              child: Column(
                children: [
                  _row('Status',
                      status[0].toUpperCase() + status.substring(1), text1, text2),
                  _row('Plan', AppPlanUtils.getLabel(plan), text1, text2),
                  _row('Total Earned', 'Rs ${_fmt(earned)}', ieAccent, text2),
                  _row('Registered',
                      createdAt.isNotEmpty
                          ? createdAt.split('T')[0]
                          : '-', text1, text2),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Earnings from this shop',
                style: GoogleFonts.outfit(
                    fontSize: 16, fontWeight: FontWeight.w800, color: text1)),
            const SizedBox(height: 12),
            earningsAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: ieAccent)),
              error: (_, _) =>
                  Text('Failed to load', style: GoogleFonts.inter(color: text2)),
              data: (earnings) {
                final shopId = shop['id'] as String?;
                final filtered = earnings
                    .where((e) => e['invited_shop_id'] == shopId)
                    .toList();
                if (filtered.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: surface, borderRadius: BorderRadius.circular(12)),
                    child: Center(
                        child: Text('No earnings from this shop yet',
                            style: GoogleFonts.inter(color: text2))),
                  );
                }
                return Container(
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: border),
                    itemBuilder: (context, i) {
                      final e = filtered[i];
                      final type = e['earning_type'] as String? ?? '';
                      final amount = e['amount'] as int? ?? 0;
                      final date = e['earned_at'] as String? ?? '';
                      return ListTile(
                        leading: const Icon(Icons.monetization_on_rounded,
                            color: ieAccent, size: 22),
                        title: Text(type,
                            style: GoogleFonts.inter(
                                fontSize: 13, color: text1, fontWeight: FontWeight.w500)),
                        subtitle: Text(
                            date.isNotEmpty ? date.split('T')[0] : '',
                            style: GoogleFonts.inter(fontSize: 11, color: text2)),
                        trailing: Text('Rs ${_fmt(amount)}',
                            style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: ieAccent)),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, Color valueColor, Color labelColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(fontSize: 13, color: labelColor)),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w700, color: valueColor)),
        ],
      ),
    );
  }

  String _fmt(int v) => v.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
}
