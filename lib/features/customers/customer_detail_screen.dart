import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_enums.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/providers/license_provider.dart';
import 'package:pdf/pdf.dart';
import '../orders/new_order_modal.dart';
import '../orders/widgets/add_payment_modal.dart';
import '../printing/pdf_builder.dart';
import '../printing/widgets/card_image_capturer.dart';
import '../printing/widgets/naap_card_widget.dart';
import '../printing/widgets/print_progress_dialog.dart';
import 'edit_customer_modal.dart';

// ── DESIGN SYSTEM TOKENS (Match HTML Concept exactly) ────────────────────────
class _Tokens {
  _Tokens._();

  static const Color ink = Color(0xFF111827);
  static const Color muted = Color(0xFF7B8494);
  static const Color faint = Color(0xFFAAB2BF);
  static const Color line = Color(0xFFE8EAF0);
  static const Color lineSoft = Color(0xFFF1F3F7);
  static const Color paper = Color(0xFFF5F6F8);
  static const Color paper2 = Color(0xFFEEF0F4);
  static const Color white = Color(0xFFFFFFFF);

  // Gold brand accents
  static const Color gold = Color(0xFFE9A227);
  static const Color gold2 = Color(0xFFFFC65A);
  static const Color goldBg = Color(0xFFFFF6E5);
  static const Color goldLine = Color(0xFFF3DDA8);
  static const Color goldInk = Color(0xFF8A5A00);

  // Semantic
  static const Color green = Color(0xFF18B887);
  static const Color greenBg = Color(0xFFEAFBF5);
  static const Color greenLine = Color(0xFFCFEFE3);
  static const Color greenInk = Color(0xFF0E8F68);

  static const Color rose = Color(0xFFEF5261);
  static const Color rose2 = Color(0xFFD63A49);
  static const Color roseBg = Color(0xFFFFF0F2);
  static const Color roseLine = Color(0xFFFFD9DE);

  static const Color blue = Color(0xFF5478E8);
  static const Color blueBg = Color(0xFFEEF2FF);
  static const Color blueLine = Color(0xFFDCE3FA);
}

// ── BILINGUAL NAAP FIELD DEFINITION (English Key + Urdu Term) ────────────────
const Map<String, String> _kNaapBilingualKeys = {
  'lambai': 'Lambai (لمبائی)',
  'length': 'Lambai (لمبائی)',
  'teerwa': 'Teerwa (تیرہ)',
  'teera': 'Teerwa (تیرہ)',
  'shoulder': 'Teerwa (تیرہ)',
  'bazo': 'Bazo (بازو)',
  'sleeve': 'Bazo (بازو)',
  'chhaati': 'Chhaati (چھاتی)',
  'chaati': 'Chhaati (چھاتی)',
  'chest': 'Chhaati (چھاتی)',
  'baghal': 'Baghal (بغل)',
  'armhole': 'Baghal (بغل)',
  'kamar': 'Kamar (کمر)',
  'waist': 'Kamar (کمر)',
  'daman': 'Daman (دامن)',
  'hem': 'Daman (دامن)',
  'collar': 'Collar (کالر)',
  'gala': 'Collar (کالر)',
  'shalwar': 'Shalwar (شلوار)',
  'trouser': 'Shalwar (شلوار)',
  'panche': 'Panche (پانچے)',
  'bottom': 'Panche (پانچے)',
};

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerDetailScreen> createState() =>
      _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen>
    with SingleTickerProviderStateMixin {
  // Tabs: 0: Profile, 1: Naap, 2: Orders, 3: Billing
  int _activeTab = 0;

  // Order Filters
  final TextEditingController _orderSearchCtrl = TextEditingController();
  final FocusNode _orderSearchFocus = FocusNode();
  OrderStatus? _selectedStatusFilter;
  String _quickFilter = 'all'; // 'all', 'unpaid', 'due-soon', 'this-month'

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _orderSearchCtrl.dispose();
    _orderSearchFocus.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    HapticFeedback.selectionClick();
    setState(() => _activeTab = index);
  }

  String _formatK(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      final k = amount / 1000;
      return '${k.toStringAsFixed(k % 1 == 0 ? 0 : 1)}K';
    }
    return amount.toInt().toString();
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays < 30) {
      final days = diff.inDays;
      return days <= 1 ? 'recently' : '$days days ago';
    }
    final months = (diff.inDays / 30).floor();
    return months <= 1 ? '1 month ago' : '$months months ago';
  }

  @override
  Widget build(BuildContext context) {
    // ── Selective watches: sirf is customer ki zarurat ka data ──
    // customersProvider se sirf isi customer ka record — dusre customers change hone pe rebuild nahi
    final customersAsync = ref.watch(
      customersProvider.select((s) => s.whenData(
        (list) => list.where((c) => c.id == widget.customerId).toList(),
      )),
    );
    final ordersAsync = ref.watch(
      ordersProvider.select((s) => s.whenData(
        (list) => list.where((o) => o.customerId == widget.customerId).toList(),
      )),
    );
    final measurementsAsync = ref.watch(
      measurementsProvider.select((s) => s.whenData(
        (list) => list.where((m) => m.customerId == widget.customerId).toList(),
      )),
    );
    final license = ref.watch(licenseProvider);

    return Scaffold(
      backgroundColor: _Tokens.paper,
      body: SafeArea(
        child: customersAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: _Tokens.gold),
          ),
          error: (err, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: _Tokens.rose, size: 36),
                const SizedBox(height: 12),
                Text('Failed to load customer: $err',
                    style: GoogleFonts.inter(color: _Tokens.ink, fontSize: 13)),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => ref.invalidate(customersProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (customers) {
            // After select(), list has at most 1 matching customer
            final customer = customers.isNotEmpty ? customers.first : null;

            if (customer == null) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: _Tokens.ink),
                      onPressed: () => context.pop(),
                    ),
                    const Expanded(
                      child: Center(
                        child: EmptyState(
                          emoji: '🔍',
                          title: 'Customer Not Found',
                          subtitle: 'This customer may have been removed or archived.',
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            final currentCustomer = customer;
            // After select(), already filtered for this customer
            final orders = ordersAsync.value ?? [];
            final measurements = measurementsAsync.value ?? [];

            // Read order balances directly from Supabase view
            final orderIds = orders.map((o) => o.id).toList();
            final orderBalancesAsync = ref.watch(customerOrderBalancesProvider(orderIds));
            final orderBalancesMap = orderBalancesAsync.value ?? {};

            // Calculate aggregates from order_balances (falling back to order fields if view is syncing)
            double totalBusiness = 0;
            double totalPaid = 0;
            double totalOutstanding = 0;

            for (final order in orders) {
              final b = orderBalancesMap[order.id];
              if (b != null) {
                totalBusiness += (b.totalAmount - b.discount);
                totalPaid += b.paidAmount;
                totalOutstanding += b.remainingAmount;
              } else {
                totalBusiness += (order.totalAmount - order.discount);
                totalPaid += order.paidAmount;
                totalOutstanding += order.remainingAmount;
              }
            }

            final shopName = license.shopName.isNotEmpty ? license.shopName : 'Darzi Pro';

            return FadeTransition(
              opacity: _fadeAnimation,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= 880;

                  return ListView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 24 : 14,
                      vertical: isDesktop ? 20 : 12,
                    ),
                    children: [
                      // ── 1. FULL-WIDTH HERO BANNER (MATCHING IMAGE 2) ─────
                      _buildHeroHeader(currentCustomer, isDesktop),
                      const SizedBox(height: 14),

                      // ── 2. QUICK ACTION BAR (+ New Order, Message, Print, ...) ─
                      _buildActionBar(currentCustomer, orders.length, totalOutstanding, isDesktop),
                      const SizedBox(height: 14),

                      // ── 3. 4 FINANCIAL & WORK KPI CARDS ─────────────────
                      _buildKpiCards(orders, measurements, totalPaid, totalOutstanding, isDesktop),
                      const SizedBox(height: 16),

                      // ── 4. NAVBAR TABS (Profile, Naap, Orders, Khata/Ledger) ─
                      _buildNavbar(measurements.length, orders.length, totalOutstanding),
                      const SizedBox(height: 16),

                      // ── 5. ACTIVE TAB CONTENT ROUTER ─────────────────────
                      _buildActiveTabContent(
                        customer: currentCustomer,
                        orders: orders,
                        measurements: measurements,
                        orderBalancesMap: orderBalancesMap,
                        totalBusiness: totalBusiness,
                        totalPaid: totalPaid,
                        totalOutstanding: totalOutstanding,
                        shopName: shopName,
                        isDesktop: isDesktop,
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  // ── 1. HERO HEADER (IMAGE 2 MATCHING LUXURY NAVY BANNER) ───────────────────
  Widget _buildHeroHeader(CustomerModel customer, bool isDesktop) {
    final shortId = customer.id.length >= 6
        ? 'DK-${customer.id.substring(0, 5).toUpperCase()}'
        : customer.id.toUpperCase();

    return RepaintBoundary(
      child: Container(
        padding: EdgeInsets.all(isDesktop ? 22 : 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x33F59E0B), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Back Button
                InkWell(
                  onTap: () => context.pop(),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0x1AFFFFFF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x26FFFFFF)),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 14),

                // Avatar
                Container(
                  width: isDesktop ? 60 : 50,
                  height: isDesktop ? 60 : 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_Tokens.gold2, _Tokens.gold],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x40E9A227),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    customer.initials,
                    style: GoogleFonts.outfit(
                      fontSize: isDesktop ? 24 : 20,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF241605),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Name & Badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              customer.name,
                              style: GoogleFonts.outfit(
                                fontSize: isDesktop ? 22 : 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0x2610B981),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0x4D10B981)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'ACTIVE',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF34D399),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Meta Chips Row
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // ID Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0x26FFFFFF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              shortId,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFCBD5E1),
                              ),
                            ),
                          ),
                          // Gender Tag
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0x26F59E0B),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              customer.gender.label,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFFBBF24),
                              ),
                            ),
                          ),
                          // Phone
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.phone_outlined, size: 12, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 4),
                              Text(
                                customer.phone,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFFE2E8F0),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          if (customer.address.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Text(
                                  customer.address,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── 2. QUICK ACTION BAR (+ New Order, Message, Call, Print, Edit, More) ─────
  Widget _buildActionBar(
    CustomerModel customer,
    int orderCount,
    double totalOutstanding,
    bool isDesktop,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _Tokens.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Tokens.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08111827),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Primary: + New Order
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _Tokens.gold,
              foregroundColor: const Color(0xFF211500),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              NewOrderModal.show(context, preSelectedCustomer: customer);
            },
            icon: const Icon(Icons.add_rounded, size: 17, color: Color(0xFF211500)),
            label: Text(
              'New Order',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF211500),
              ),
            ),
          ),

          // Action Buttons Group
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // WhatsApp
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF059669),
                  side: const BorderSide(color: Color(0x3310B981)),
                  backgroundColor: const Color(0x0D10B981),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _openWhatsApp(customer.phone, context),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15, color: Color(0xFF059669)),
                label: Text(
                  'WhatsApp',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),

              // Call
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _Tokens.ink,
                  side: const BorderSide(color: _Tokens.line),
                  backgroundColor: _Tokens.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _makePhoneCall(customer.phone, context),
                icon: const Icon(Icons.phone_outlined, size: 15, color: _Tokens.muted),
                label: Text(
                  'Call',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),

              // Print Card
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _Tokens.ink,
                  side: const BorderSide(color: _Tokens.line),
                  backgroundColor: _Tokens.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _handlePrintFromHeader(customer),
                icon: const Icon(Icons.print_outlined, size: 15, color: _Tokens.muted),
                label: Text(
                  'Print Card',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),

              // Edit Profile
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _Tokens.ink,
                  side: const BorderSide(color: _Tokens.line),
                  backgroundColor: _Tokens.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => EditCustomerModal.show(context, customer: customer),
                icon: const Icon(Icons.edit_outlined, size: 15, color: _Tokens.muted),
                label: Text(
                  'Edit Profile',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),

              // Overflow Popup
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 18, color: _Tokens.muted),
                tooltip: 'More options',
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (val) {
                  if (val == 'delete') {
                    _confirmDeleteCustomer(customer, orderCount, totalOutstanding);
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline_rounded, size: 16, color: _Tokens.rose),
                        const SizedBox(width: 8),
                        Text('Archive / Delete', style: GoogleFonts.inter(fontSize: 12, color: _Tokens.rose, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 3. 4 FINANCIAL & WORK KPI CARDS (IMAGE 2 MATCHING) ──────────────────────
  Widget _buildKpiCards(
    List<OrderModel> orders,
    List<MeasurementModel> measurements,
    double totalPaid,
    double totalOutstanding,
    bool isDesktop,
  ) {
    final cards = [
      _buildDetailKpiCard(
        title: 'TOTAL ORDERS',
        value: '${orders.length}',
        subtext: orders.isNotEmpty ? '${orders.length} orders on file' : 'No orders yet',
        icon: Icons.shopping_bag_outlined,
        iconColor: const Color(0xFFD97706),
        iconBg: const Color(0xFFFEF3C7),
      ),
      _buildDetailKpiCard(
        title: 'NAAP RECORDS',
        value: '${measurements.length}',
        subtext: measurements.isNotEmpty ? measurements.first.profileName : 'No naap profile',
        icon: Icons.straighten_rounded,
        iconColor: const Color(0xFF0284C7),
        iconBg: const Color(0xFFE0F2FE),
      ),
      _buildDetailKpiCard(
        title: 'TOTAL PAID',
        value: 'Rs ${_formatK(totalPaid)}',
        subtext: 'Payments collected',
        icon: Icons.check_circle_outline_rounded,
        iconColor: const Color(0xFF059669),
        iconBg: const Color(0xFFD1FAE5),
      ),
      _buildDetailKpiCard(
        title: 'OUTSTANDING',
        value: 'Rs ${_formatK(totalOutstanding)}',
        subtext: totalOutstanding > 0 ? 'Payment due' : 'All clear',
        icon: Icons.account_balance_wallet_outlined,
        iconColor: totalOutstanding > 0 ? const Color(0xFFE11D48) : const Color(0xFF059669),
        iconBg: totalOutstanding > 0 ? const Color(0xFFFFE4E6) : const Color(0xFFD1FAE5),
      ),
    ];

    if (isDesktop) {
      return Row(
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 8),
            Expanded(child: cards[1]),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: cards[2]),
            const SizedBox(width: 8),
            Expanded(child: cards[3]),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailKpiCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _Tokens.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Tokens.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06111827),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _Tokens.muted,
                  letterSpacing: 0.6,
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 16, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _Tokens.ink,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: _Tokens.muted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── 4. NAVBAR TABS ──────────────────────────────────────────────────────────
  Widget _buildNavbar(int naapCount, int ordersCount, double outstanding) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: _Tokens.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Tokens.line),
        boxShadow: const [
          BoxShadow(color: Color(0x08111827), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          _buildNavTab(label: 'Profile', icon: Icons.person_outline_rounded, index: 0),
          _buildNavTab(label: 'Naap', icon: Icons.straighten_rounded, index: 1, countBadge: '$naapCount'),
          _buildNavTab(label: 'Orders', icon: Icons.inventory_2_outlined, index: 2, countBadge: '$ordersCount'),
          _buildNavTab(
            label: 'Khata / Ledger',
            icon: Icons.menu_book_outlined,
            index: 3,
            countBadge: outstanding > 0 ? 'Rs ${_formatK(outstanding)}' : null,
            badgeColor: outstanding > 0 ? _Tokens.rose : null,
          ),
        ],
      ),
    );
  }

  Widget _buildNavTab({
    required String label,
    required IconData icon,
    required int index,
    String? countBadge,
    Color? badgeColor,
  }) {
    final isActive = _activeTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => _switchTab(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? _Tokens.gold : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive
                ? const [
                    BoxShadow(
                      color: Color(0x38E9A227),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isActive ? const Color(0xFF211500) : _Tokens.muted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    color: isActive ? const Color(0xFF211500) : _Tokens.muted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (countBadge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0x33000000)
                        : (badgeColor ?? _Tokens.paper2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    countBadge,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: isActive
                          ? const Color(0xFF211500)
                          : (badgeColor ?? _Tokens.muted),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── 5. TAB CONTENT ROUTER ───────────────────────────────────────────────────
  Widget _buildActiveTabContent({
    required CustomerModel customer,
    required List<OrderModel> orders,
    required List<MeasurementModel> measurements,
    required Map<String, OrderBalance> orderBalancesMap,
    required double totalBusiness,
    required double totalPaid,
    required double totalOutstanding,
    required String shopName,
    required bool isDesktop,
  }) {
    switch (_activeTab) {
      case 0:
        return _buildProfileTab(
          customer: customer,
          orders: orders,
          measurements: measurements,
          orderBalancesMap: orderBalancesMap,
          totalBusiness: totalBusiness,
          totalPaid: totalPaid,
          totalOutstanding: totalOutstanding,
          isDesktop: isDesktop,
        );
      case 1:
        return _buildNaapTab(customer, measurements, isDesktop);
      case 2:
        return _buildOrdersTab(customer, orders, orderBalancesMap, isDesktop);
      case 3:
      default:
        return _buildBillingTab(
          customer: customer,
          orders: orders,
          measurements: measurements,
          orderBalancesMap: orderBalancesMap,
          totalBusiness: totalBusiness,
          totalPaid: totalPaid,
          totalOutstanding: totalOutstanding,
          shopName: shopName,
          isDesktop: isDesktop,
        );
    }
  }

  // ── 6. TAB 1: PROFILE TAB (IMAGE 2 4-CARD DASHBOARD GRID) ───────────────────
  Widget _buildProfileTab({
    required CustomerModel customer,
    required List<OrderModel> orders,
    required List<MeasurementModel> measurements,
    required Map<String, OrderBalance> orderBalancesMap,
    required double totalBusiness,
    required double totalPaid,
    required double totalOutstanding,
    required bool isDesktop,
  }) {
    final personalInfoCard = _buildPersonalInfoCard(customer);
    final recentOrdersCard = _buildRecentOrdersCard(orders, orderBalancesMap);
    final latestNaapCard = _buildLatestMeasurementsCard(customer, measurements);
    final ledgerSummaryCard = _buildLedgerSummaryCard(
      totalBusiness: totalBusiness,
      totalPaid: totalPaid,
      totalOutstanding: totalOutstanding,
      customer: customer,
    );

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column: Personal Information + Recent Orders
          Expanded(
            child: Column(
              children: [
                personalInfoCard,
                const SizedBox(height: 14),
                recentOrdersCard,
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Right Column: Latest Measurements + Ledger Summary
          Expanded(
            child: Column(
              children: [
                latestNaapCard,
                const SizedBox(height: 14),
                ledgerSummaryCard,
              ],
            ),
          ),
        ],
      );
    }

    // Mobile Column: Stacks the 4 cards
    return Column(
      children: [
        personalInfoCard,
        const SizedBox(height: 12),
        recentOrdersCard,
        const SizedBox(height: 12),
        latestNaapCard,
        const SizedBox(height: 12),
        ledgerSummaryCard,
      ],
    );
  }

  // ── CARD 1: PERSONAL INFORMATION ───────────────────────────────────────────
  Widget _buildPersonalInfoCard(CustomerModel customer) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _Tokens.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Tokens.line),
        boxShadow: const [
          BoxShadow(color: Color(0x06111827), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _Tokens.goldBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_outline_rounded, size: 16, color: _Tokens.goldInk),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Personal Information',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _Tokens.ink,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 16, color: _Tokens.muted),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Edit Profile',
                onPressed: () => EditCustomerModal.show(context, customer: customer),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Key-Value Rows
          _buildInfoRow('Full Name', customer.name, 'Gender', customer.gender.label),
          const SizedBox(height: 10),
          _buildInfoRow('Phone', customer.phone, 'Customer ID', 'DK-${customer.id.length >= 6 ? customer.id.substring(0, 6).toUpperCase() : customer.id.toUpperCase()}'),
          const SizedBox(height: 10),
          _buildInfoRow('Address', customer.address.isNotEmpty ? customer.address : 'Lahore, Pakistan', 'Customer Since', DateFormat('dd MMM yyyy').format(customer.createdAt)),

          const SizedBox(height: 14),
          // Notes box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _Tokens.paper,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _Tokens.lineSoft),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.note_alt_outlined, size: 15, color: _Tokens.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    customer.notes?.isNotEmpty == true
                        ? customer.notes!
                        : 'Standard fitting profile · No custom tailoring notes recorded.',
                    style: GoogleFonts.inter(fontSize: 11, color: _Tokens.muted, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String k1, String v1, String k2, String v2) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(k1, style: GoogleFonts.inter(fontSize: 10.5, color: _Tokens.muted, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(v1, style: GoogleFonts.inter(fontSize: 12, color: _Tokens.ink, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(k2, style: GoogleFonts.inter(fontSize: 10.5, color: _Tokens.muted, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(v2, style: GoogleFonts.inter(fontSize: 12, color: _Tokens.ink, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  // ── CARD 2: RECENT ORDERS ───────────────────────────────────────────────────
  Widget _buildRecentOrdersCard(List<OrderModel> orders, Map<String, OrderBalance> balances) {
    final recent = orders.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _Tokens.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Tokens.line),
        boxShadow: const [
          BoxShadow(color: Color(0x06111827), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFFD97706)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Recent Orders',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _Tokens.ink,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _switchTab(2),
                child: Row(
                  children: [
                    Text(
                      'View All',
                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: _Tokens.goldInk),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 16, color: _Tokens.goldInk),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('No orders recorded yet.', style: GoogleFonts.inter(fontSize: 12, color: _Tokens.muted)),
              ),
            )
          else
            ...recent.map((order) {
              final b = balances[order.id];
              final total = b != null ? (b.totalAmount - b.discount) : (order.totalAmount - order.discount);
              final due = b != null ? b.remainingAmount : order.remainingAmount;

              return InkWell(
                onTap: () => context.push('/orders/${order.id}'),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _Tokens.paper,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _Tokens.lineSoft),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _Tokens.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _Tokens.line),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.checkroom_outlined, size: 17, color: _Tokens.ink),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  order.tokenNumber.isNotEmpty ? order.tokenNumber : '#${order.orderNumber}',
                                  style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: _Tokens.ink),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: order.status == OrderStatus.delivered
                                        ? const Color(0x2610B981)
                                        : const Color(0x26F59E0B),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    order.status.label,
                                    style: GoogleFonts.inter(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                      color: order.status == OrderStatus.delivered
                                          ? const Color(0xFF059669)
                                          : const Color(0xFFD97706),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              order.itemsSummary.isNotEmpty ? order.itemsSummary : 'Suit',
                              style: GoogleFonts.inter(fontSize: 10.5, color: _Tokens.muted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Rs ${total.toInt()}',
                            style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.w800, color: _Tokens.ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            due > 0 ? 'Rs ${due.toInt()} Due' : 'Paid ✓',
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: due > 0 ? _Tokens.rose : _Tokens.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── CARD 3: LATEST MEASUREMENTS ─────────────────────────────────────────────
  Widget _buildLatestMeasurementsCard(CustomerModel customer, List<MeasurementModel> measurements) {
    final latest = measurements.isNotEmpty ? measurements.first : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _Tokens.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Tokens.line),
        boxShadow: const [
          BoxShadow(color: Color(0x06111827), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.straighten_rounded, size: 16, color: Color(0xFF0284C7)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Latest Measurements',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _Tokens.ink,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _switchTab(1),
                child: Row(
                  children: [
                    Text(
                      'View All',
                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: _Tokens.goldInk),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 16, color: _Tokens.goldInk),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (latest == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Text('No measurement profile found.', style: GoogleFonts.inter(fontSize: 12, color: _Tokens.muted)),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _Tokens.line),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _switchTab(1),
                      icon: const Icon(Icons.add_rounded, size: 14, color: _Tokens.ink),
                      label: Text('Add Naap', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _Tokens.ink)),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Profile Name & Date
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: _Tokens.paper,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.accessibility_new_rounded, size: 16, color: _Tokens.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      latest.profileName,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: _Tokens.ink),
                    ),
                  ),
                  Text(
                    _timeAgo(latest.updatedAt),
                    style: GoogleFonts.inter(fontSize: 10.5, color: _Tokens.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Key Measurement Chips (Chaati, Lambai, Teera, Bazo, Kamar, Gala)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildNaapChip('Lambai', _findNaapVal(latest, ['lambai', 'length'])),
                _buildNaapChip('Chaati', _findNaapVal(latest, ['chaati', 'chhaati', 'chest'])),
                _buildNaapChip('Teera', _findNaapVal(latest, ['teera', 'teerwa', 'shoulder'])),
                _buildNaapChip('Bazo', _findNaapVal(latest, ['bazo', 'sleeve'])),
                _buildNaapChip('Kamar', _findNaapVal(latest, ['kamar', 'waist'])),
                _buildNaapChip('Gala', _findNaapVal(latest, ['gala', 'collar'])),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String? _findNaapVal(MeasurementModel? m, List<String> aliases) {
    if (m == null) return null;
    for (final section in m.sections) {
      for (final field in section.fields) {
        final k = field.key.trim().toLowerCase();
        final l = field.label.trim().toLowerCase();
        for (final a in aliases) {
          if (k == a || l.contains(a)) {
            if (field.value.trim().isNotEmpty) return field.value.trim();
          }
        }
      }
    }
    return null;
  }

  Widget _buildNaapChip(String label, dynamic val) {
    final strVal = (val != null && val.toString().trim().isNotEmpty) ? '$val"' : '-';
    return Container(
      width: 78,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: _Tokens.paper,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _Tokens.lineSoft),
      ),
      child: Column(
        children: [
          Text(strVal, style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.w800, color: _Tokens.ink)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.inter(fontSize: 8.5, color: _Tokens.muted, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── CARD 4: LEDGER SUMMARY ──────────────────────────────────────────────────
  Widget _buildLedgerSummaryCard({
    required double totalBusiness,
    required double totalPaid,
    required double totalOutstanding,
    required CustomerModel customer,
  }) {
    final paidPercent = totalBusiness > 0 ? (totalPaid / totalBusiness).clamp(0.0, 1.0) : 1.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _Tokens.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Tokens.line),
        boxShadow: const [
          BoxShadow(color: Color(0x06111827), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.menu_book_outlined, size: 16, color: Color(0xFF059669)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Ledger Summary',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _Tokens.ink,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _switchTab(3),
                child: Row(
                  children: [
                    Text(
                      'View All',
                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: _Tokens.goldInk),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 16, color: _Tokens.goldInk),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Total Billed vs Paid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Billed', style: GoogleFonts.inter(fontSize: 10.5, color: _Tokens.muted)),
                  const SizedBox(height: 2),
                  Text('Rs ${_formatK(totalBusiness)}', style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w800, color: _Tokens.ink)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Total Paid', style: GoogleFonts.inter(fontSize: 10.5, color: _Tokens.muted)),
                  const SizedBox(height: 2),
                  Text('Rs ${_formatK(totalPaid)}', style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF059669))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: paidPercent,
              backgroundColor: const Color(0xFFFFE4E6),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 14),

          // Outstanding Due Highlight Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: totalOutstanding > 0 ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: totalOutstanding > 0 ? const Color(0xFFFFCCD3) : const Color(0xFFBBF7D0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      totalOutstanding > 0 ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                      size: 16,
                      color: totalOutstanding > 0 ? _Tokens.rose : const Color(0xFF059669),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      totalOutstanding > 0 ? 'Pending Balance' : 'Zero Balance Due',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: totalOutstanding > 0 ? _Tokens.rose : const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Rs ${_formatK(totalOutstanding)}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: totalOutstanding > 0 ? _Tokens.rose : const Color(0xFF059669),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 7. TAB 2: NAAP TAB ──────────────────────────────────────────────────────
  Widget _buildNaapTab(CustomerModel customer, List<MeasurementModel> measurements, bool isDesktop) {
    // ── DEDUPLICATION: same naam ke multiple profiles mein sirf latest rakho ──
    final Map<String, MeasurementModel> latestByName = {};
    final List<String> duplicateIds = []; // clean-up ke liye

    for (final m in measurements) {
      final key = m.profileName.trim().toLowerCase();
      if (!latestByName.containsKey(key)) {
        latestByName[key] = m;
      } else {
        // Latest raho, purana duplicate mein daalo
        final existing = latestByName[key]!;
        if (m.updatedAt.isAfter(existing.updatedAt)) {
          duplicateIds.add(existing.id); // purana duplicate
          latestByName[key] = m;
        } else {
          duplicateIds.add(m.id); // yeh duplicate hai
        }
      }
    }

    final uniqueProfiles = latestByName.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Naap profiles',
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: _Tokens.ink)),
                const SizedBox(height: 2),
                Text('${uniqueProfiles.length} garment${uniqueProfiles.length == 1 ? '' : 's'} · ${customer.name}',
                    style: GoogleFonts.inter(fontSize: 11, color: _Tokens.muted)),
              ],
            ),
            Row(
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _Tokens.ink,
                    side: const BorderSide(color: _Tokens.line),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _handlePrintFromHeader(customer),
                  icon: const Icon(Icons.print_outlined, size: 15, color: _Tokens.muted),
                  label: Text('Print Naap', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _Tokens.gold,
                    foregroundColor: const Color(0xFF211500),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _showAddProfileModal(customer),
                  icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF211500)),
                  label: Text('Add Naap', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── DUPLICATE WARNING BANNER ─────────────────────────────────────────
        if (duplicateIds.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _Tokens.roseBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _Tokens.roseLine),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 18, color: _Tokens.rose),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${duplicateIds.length} duplicate profile${duplicateIds.length == 1 ? '' : 's'} found',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: _Tokens.rose),
                      ),
                      Text(
                        'Same naam ke duplicate naap profiles database mein hain. Clean Up karo — sirf latest rakhega.',
                        style: GoogleFonts.inter(fontSize: 10.5, color: _Tokens.rose2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: _Tokens.rose,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _cleanUpDuplicates(duplicateIds),
                  child: Text('Clean Up', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (uniqueProfiles.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
            decoration: BoxDecoration(
              color: _Tokens.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _Tokens.line),
            ),
            child: Column(
              children: [
                const Icon(Icons.straighten_rounded, size: 40, color: _Tokens.faint),
                const SizedBox(height: 10),
                Text('No Naap Profiles Yet',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: _Tokens.ink)),
                const SizedBox(height: 4),
                Text('Create a reusable measurement set for this customer.',
                    style: GoogleFonts.inter(fontSize: 11, color: _Tokens.muted)),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _Tokens.gold,
                    foregroundColor: const Color(0xFF211500),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _showAddProfileModal(customer),
                  child: Text('+ Add First Naap Profile',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          )
        else
          // RepaintBoundary: har card independently repaint hoga
          ...uniqueProfiles.map((m) => RepaintBoundary(
            key: ValueKey(m.id),
            child: _buildNaapProfileCard(customer, m),
          )),
      ],
    );
  }

  /// Duplicate naap profiles ko database se delete karo
  Future<void> _cleanUpDuplicates(List<String> ids) async {
    if (ids.isEmpty) return;
    HapticFeedback.mediumImpact();
    try {
      for (final id in ids) {
        await ref.read(measurementsProvider.notifier).deleteMeasurement(id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('${ids.length} duplicate${ids.length == 1 ? '' : 's'} delete ho gaye ✓',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
            backgroundColor: _Tokens.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: _Tokens.rose,
          ),
        );
      }
    }
  }

  Widget _buildNaapProfileCard(CustomerModel customer, MeasurementModel m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _Tokens.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _Tokens.line),
        boxShadow: const [
          BoxShadow(color: Color(0x06111827), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _Tokens.goldBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.straighten_rounded, color: _Tokens.gold, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.profileName,
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: _Tokens.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Updated ${DateFormat('dd MMM yyyy').format(m.updatedAt)}',
                      style: GoogleFonts.inter(fontSize: 10, color: _Tokens.muted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _Tokens.paper,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  m.category.label.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: _Tokens.muted),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(color: _Tokens.lineSoft, height: 1),
          const SizedBox(height: 12),

          // Actions: Edit, Copy, Print PDF
          Row(
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _Tokens.ink,
                  side: const BorderSide(color: _Tokens.line),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.push(
                    '/measurements/${customer.id}/${Uri.encodeComponent(customer.name)}'
                    '?measurementId=${m.id}'
                    '&profileName=${Uri.encodeComponent(m.profileName)}'
                    '&category=${m.category.name}',
                  );
                },
                icon: const Icon(Icons.edit_outlined, size: 13),
                label: Text('Edit', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _Tokens.blue,
                  backgroundColor: _Tokens.blueBg,
                  side: const BorderSide(color: _Tokens.blueLine),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _copyNaapToClipboard(m),
                icon: const Icon(Icons.copy_rounded, size: 13, color: _Tokens.blue),
                label: Text('Copy', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: _Tokens.blue)),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _Tokens.blue,
                  backgroundColor: _Tokens.blueBg,
                  side: const BorderSide(color: _Tokens.blueLine),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _printNaapCardPdf(customer, m),
                icon: const Icon(Icons.print_outlined, size: 13, color: _Tokens.blue),
                label: Text('Print PDF (A5)', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: _Tokens.blue)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _copyNaapToClipboard(MeasurementModel m) {
    final buffer = StringBuffer('Naap · ${m.profileName}\n');
    for (final s in m.sections) {
      for (final f in s.fields) {
        if (f.value.trim().isNotEmpty) {
          final label = _kNaapBilingualKeys[f.key.toLowerCase()] ?? f.label;
          buffer.writeln('$label: ${f.value} ${f.unit}');
        }
      }
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Naap copied to clipboard ✓'),
        backgroundColor: _Tokens.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _printNaapCardPdf(CustomerModel customer, MeasurementModel m) async {
    PrintProgressController? progressDialog;
    try {
      progressDialog = await showPrintProgressModal(
        context,
        title: 'Printing Naap Card',
        initialStep: 'Step 1/4: Preparing customer profile...',
      );

      final customerOrders = ref.read(ordersProvider).valueOrNull
          ?.where((o) => o.customerId == customer.id)
          .toList() ?? [];
      if (customerOrders.isNotEmpty) {
        customerOrders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
      }
      final latestOrder = customerOrders.firstOrNull;

      final effectiveOrder = latestOrder ?? OrderModel(
        id: 'naap_${DateTime.now().millisecondsSinceEpoch}',
        customerId: customer.id,
        customerName: customer.name,
        tokenNumber: 'NAAP',
        orderNumber: 1,
        orderDate: DateTime.now(),
        status: OrderStatus.pending,
        totalAmount: 0,
        items: const [],
        payments: const [],
      );

      progressDialog.update(
        step: 'Step 2/4: Rendering tailor pattern shapes...',
        progress: 0.55,
      );

      if (!mounted) return;

      final pngBytes = await CardImageCapturer.captureOnDemand(
        context,
        cardWidget: NaapCardWidget(
          order: effectiveOrder,
          customer: customer,
          measurement: m,
        ),
        pixelRatio: 1.0,
      );

      progressDialog.update(
        step: 'Step 3/4: Compiling A5 print PDF document...',
        progress: 0.85,
      );

      final pdfBytes = await DarziPdfBuilder.buildPdfFromImageBytes(
        pngBytes,
        pageFormat: PdfPageFormat.a5,
      );

      progressDialog.update(
        step: 'Step 4/4: Opening system print preview...',
        progress: 1.0,
      );

      await Future.delayed(const Duration(milliseconds: 150));
      progressDialog.dismiss();
      progressDialog = null;

      await Printing.layoutPdf(
        name: 'Naap_${customer.name}_${m.profileName}.pdf',
        onLayout: (_) async => Uint8List.fromList(pdfBytes),
      );
    } catch (e) {
      progressDialog?.dismiss();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to print naap card: $e'), backgroundColor: _Tokens.rose),
        );
      }
    }
  }

  void _handlePrintFromHeader(CustomerModel customer) {
    HapticFeedback.lightImpact();
    final allMeasurements = ref.read(measurementsProvider).valueOrNull ?? [];
    final customerMeasurements = allMeasurements
        .where((m) => m.customerId == customer.id)
        .toList();

    // Deduplicate profiles by name
    final Map<String, MeasurementModel> latestByName = {};
    for (final m in customerMeasurements) {
      final key = m.profileName.trim().toLowerCase();
      if (!latestByName.containsKey(key) || m.updatedAt.isAfter(latestByName[key]!.updatedAt)) {
        latestByName[key] = m;
      }
    }
    final uniqueProfiles = latestByName.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    if (uniqueProfiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Is customer ka koi naap profile record nahi hai.'),
          backgroundColor: _Tokens.rose,
        ),
      );
      return;
    }

    if (uniqueProfiles.length == 1) {
      _printNaapCardPdf(customer, uniqueProfiles.first);
      return;
    }

    _showPrintProfileSelector(customer, uniqueProfiles);
  }

  void _showPrintProfileSelector(CustomerModel customer, List<MeasurementModel> profiles) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF181D27) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: isDark ? const Color(0xFF333946) : _Tokens.line),
          ),
          padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(ctx).padding.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _Tokens.goldBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _Tokens.goldLine),
                    ),
                    child: const Center(child: Icon(Icons.print_rounded, color: _Tokens.gold, size: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'کونسا ناپ پروفائل پرنٹ کرنا ہے؟',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : _Tokens.ink,
                          ),
                        ),
                        Text(
                          'Select naap profile to print for ${customer.name}',
                          style: GoogleFonts.dmSans(fontSize: 11.5, color: _Tokens.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : _Tokens.muted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: profiles.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final m = profiles[i];
                  final catEmoji = m.category == MeasurementCategory.women
                      ? '👗'
                      : (m.category == MeasurementCategory.children ? '👕' : '👔');
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        _printNaapCardPdf(customer, m);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1D222D) : _Tokens.paper,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? const Color(0xFF333946) : _Tokens.line),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _Tokens.goldBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(child: Text(catEmoji, style: const TextStyle(fontSize: 18))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.profileName,
                                    style: GoogleFonts.manrope(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : _Tokens.ink,
                                    ),
                                  ),
                                  Text(
                                    '${m.category.name.toUpperCase()} · ${m.sections.expand((s) => s.fields).where((f) => f.value.trim().isNotEmpty).length} fields filled',
                                    style: GoogleFonts.dmSans(fontSize: 11, color: _Tokens.muted),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [_Tokens.gold2, _Tokens.gold]),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.print_outlined, size: 12, color: Color(0xFF211500)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Print',
                                    style: GoogleFonts.manrope(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF211500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddProfileModal(CustomerModel customer) async {
    // Current naap profiles for duplicate check
    final existingMeasurements = ref.read(measurementsProvider).valueOrNull ?? [];
    final customerProfiles = existingMeasurements
        .where((m) => m.customerId == customer.id)
        .toList();

    final profileCtrl = TextEditingController(text: 'شلوار قمیض');
    MeasurementCategory chosenCategory = customer.gender == CustomerGender.female
        ? MeasurementCategory.women
        : MeasurementCategory.men;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) {
          // Live duplicate check as user types
          final typedName = profileCtrl.text.trim().toLowerCase();
          final existingMatch = customerProfiles.where(
            (m) => m.profileName.trim().toLowerCase() == typedName,
          ).firstOrNull;

          return Container(
            decoration: const BoxDecoration(
              color: _Tokens.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(22, 20, 22, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Naap Profile',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: _Tokens.ink)),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: _Tokens.muted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),

                // ── Info: Har garment ka sirf 1 profile ──────────────────
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: _Tokens.goldBg,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: _Tokens.goldLine),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 15, color: _Tokens.goldInk),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Har garment ka sirf ek profile hoga. Agar profile pehle se maujood hai to woh update ho ga.',
                          style: GoogleFonts.inter(fontSize: 10.5, color: _Tokens.goldInk),
                        ),
                      ),
                    ],
                  ),
                ),

                Text('CATEGORY',
                    style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w900, color: _Tokens.muted)),
                const SizedBox(height: 6),
                DropdownButtonFormField<MeasurementCategory>(
                  initialValue: chosenCategory,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _Tokens.line)),
                  ),
                  items: MeasurementCategory.values.map((c) {
                    return DropdownMenuItem(value: c, child: Text(c.label));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setMState(() => chosenCategory = val);
                  },
                ),
                const SizedBox(height: 14),
                Text('GARMENT / PROFILE NAME',
                    style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w900, color: _Tokens.muted)),
                const SizedBox(height: 6),
                TextField(
                  controller: profileCtrl,
                  onChanged: (_) => setMState(() {}), // live duplicate check trigger
                  decoration: InputDecoration(
                    hintText: 'e.g. شلوار قمیض, واسکٹ, شیروانی',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _Tokens.line)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: existingMatch != null ? _Tokens.gold : _Tokens.gold,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),

                // ── Duplicate badge: agar pehle se exist karta hai ─────
                if (existingMatch != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _Tokens.blueBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _Tokens.blueLine),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_outlined, size: 14, color: _Tokens.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '"${existingMatch.profileName}" profile pehle se maujood hai — Continue se edit hoga.',
                            style: GoogleFonts.inter(fontSize: 10.5, color: _Tokens.blue, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _Tokens.gold,
                      foregroundColor: const Color(0xFF211500),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      final name = profileCtrl.text.trim();
                      if (name.isEmpty) return;
                      Navigator.pop(ctx);

                      // ── UNIQUENESS CHECK: agar same profile exist kare to edit karo ──
                      if (existingMatch != null) {
                        // Existing profile edit screen pe bhejo
                        context.push(
                          '/measurements/${customer.id}/${Uri.encodeComponent(customer.name)}'
                          '?measurementId=${existingMatch.id}'
                          '&profileName=${Uri.encodeComponent(existingMatch.profileName)}'
                          '&category=${existingMatch.category.name}',
                        );
                      } else {
                        // Nayi profile banao
                        context.push(
                          '/measurements/${customer.id}/${Uri.encodeComponent(customer.name)}'
                          '?profileName=${Uri.encodeComponent(name)}'
                          '&category=${chosenCategory.name}',
                        );
                      }
                    },
                    child: Text(
                      existingMatch != null ? 'Edit Existing Profile →' : 'Continue to Measurements →',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    profileCtrl.dispose();
  }

  // ── 8. TAB 3: ORDERS TAB ────────────────────────────────────────────────────
  Widget _buildOrdersTab(
    CustomerModel customer,
    List<OrderModel> orders,
    Map<String, OrderBalance> balances,
    bool isDesktop,
  ) {
    final query = _orderSearchCtrl.text.trim().toLowerCase();

    // Filter list
    final filtered = orders.where((o) {
      final matchesQuery = query.isEmpty ||
          o.tokenNumber.toLowerCase().contains(query) ||
          o.itemsSummary.toLowerCase().contains(query);

      final matchesStatus = _selectedStatusFilter == null || o.status == _selectedStatusFilter;

      bool matchesQuick = true;
      if (_quickFilter == 'unpaid') {
        final b = balances[o.id];
        final due = b != null ? b.remainingAmount : o.remainingAmount;
        matchesQuick = due > 0;
      } else if (_quickFilter == 'due-soon') {
        matchesQuick = o.isUrgent || o.status == OrderStatus.stitching;
      } else if (_quickFilter == 'this-month') {
        final now = DateTime.now();
        matchesQuick = o.orderDate.year == now.year && o.orderDate.month == now.month;
      }

      return matchesQuery && matchesStatus && matchesQuick;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Orders',
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: _Tokens.ink)),
                const SizedBox(height: 2),
                Text('Complete order history for this client.',
                    style: GoogleFonts.inter(fontSize: 11, color: _Tokens.muted)),
              ],
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _Tokens.gold,
                foregroundColor: const Color(0xFF211500),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                NewOrderModal.show(context, preSelectedCustomer: customer);
              },
              icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF211500)),
              label: Text('New Order', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Search + Status Filter Toolbar
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 42,
                child: TextField(
                  controller: _orderSearchCtrl,
                  focusNode: _orderSearchFocus,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _Tokens.faint),
                    hintText: 'Search by token, garment…',
                    hintStyle: GoogleFonts.inter(fontSize: 12, color: _Tokens.faint),
                    filled: true,
                    fillColor: _Tokens.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _Tokens.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _Tokens.gold),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _Tokens.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _Tokens.line),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<OrderStatus?>(
                  value: _selectedStatusFilter,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: _Tokens.muted),
                  hint: Text('All statuses', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _Tokens.ink)),
                  items: [
                    DropdownMenuItem<OrderStatus?>(
                      value: null,
                      child: Text('All statuses', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                    ...OrderStatus.values.map((s) => DropdownMenuItem<OrderStatus?>(
                          value: s,
                          child: Text(s.label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
                        )),
                  ],
                  onChanged: (s) => setState(() => _selectedStatusFilter = s),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Quick Filter Chips
        Wrap(
          spacing: 6,
          children: [
            _buildFilterChip('all', 'All', orders.length),
            _buildFilterChip('unpaid', 'Unpaid', orders.where((o) => (balances[o.id]?.remainingAmount ?? o.remainingAmount) > 0).length),
            _buildFilterChip('due-soon', 'Due soon', orders.where((o) => o.isUrgent || o.status == OrderStatus.stitching).length),
            _buildFilterChip('this-month', 'This month', orders.where((o) {
              final now = DateTime.now();
              return o.orderDate.year == now.year && o.orderDate.month == now.month;
            }).length),
          ],
        ),
        const SizedBox(height: 12),

        // Orders Table
        Container(
          decoration: BoxDecoration(
            color: _Tokens.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _Tokens.line),
          ),
          child: filtered.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.search_off_rounded, size: 36, color: _Tokens.faint),
                        const SizedBox(height: 8),
                        Text('No orders found',
                            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: _Tokens.ink)),
                        Text('Try clearing the search or status filter.',
                            style: GoogleFonts.inter(fontSize: 11, color: _Tokens.muted)),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: filtered.map((order) {
                    final b = balances[order.id];
                    final total = b != null ? (b.totalAmount - b.discount) : (order.totalAmount - order.discount);
                    final due = b != null ? b.remainingAmount : order.remainingAmount;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: _Tokens.lineSoft)),
                      ),
                      child: Row(
                        children: [
                          // Token
                          InkWell(
                            onTap: () => context.push('/orders/${order.id}'),
                            child: Container(
                              width: 52,
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              decoration: BoxDecoration(
                                color: _Tokens.goldBg,
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(color: _Tokens.goldLine),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                order.tokenNumber.isNotEmpty ? order.tokenNumber : '#${order.orderNumber}',
                                style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w800, color: _Tokens.goldInk),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Garment Info
                          Expanded(
                            child: InkWell(
                              onTap: () => context.push('/orders/${order.id}'),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    order.itemsSummary.isNotEmpty ? order.itemsSummary : 'Garment',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: _Tokens.ink),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    DateFormat('dd MMM yyyy').format(order.orderDate),
                                    style: GoogleFonts.inter(fontSize: 9.5, color: _Tokens.muted),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Status Control Dropdown (Wired to orders table in Supabase)
                          Container(
                            height: 30,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: _Tokens.paper,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _Tokens.line),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<OrderStatus>(
                                value: order.status,
                                isDense: true,
                                style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: _Tokens.ink),
                                items: OrderStatus.values.map((s) {
                                  return DropdownMenuItem(
                                    value: s,
                                    child: Text(s.label),
                                  );
                                }).toList(),
                                onChanged: (newStatus) {
                                  if (newStatus != null && newStatus != order.status) {
                                    _changeOrderStatus(order, newStatus);
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Price / Due from order_balances
                          InkWell(
                            onTap: () => context.push('/orders/${order.id}'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Rs ${total.toInt()}',
                                    style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.w800, color: _Tokens.ink)),
                                Text(
                                  due > 0 ? 'Due ${due.toInt()}' : 'Paid ✓',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: due > 0 ? _Tokens.rose : _Tokens.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label, int count) {
    final isActive = _quickFilter == key;
    return InkWell(
      onTap: () => setState(() => _quickFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? _Tokens.ink : _Tokens.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? _Tokens.ink : _Tokens.line),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: isActive ? _Tokens.paper : _Tokens.muted,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '$count',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: isActive ? _Tokens.paper.withValues(alpha: 0.8) : _Tokens.faint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeOrderStatus(OrderModel order, OrderStatus newStatus) async {
    try {
      HapticFeedback.lightImpact();
      await ref.read(ordersProvider.notifier).updateOrderStatus(order.id, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order #${order.tokenNumber} → ${newStatus.label} ✓'),
            backgroundColor: _Tokens.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: _Tokens.rose),
        );
      }
    }
  }

  // ── 9. TAB 4: BILLING TAB (RENAMED FROM LEDGER) ─────────────────────────────
  Widget _buildBillingTab({
    required CustomerModel customer,
    required List<OrderModel> orders,
    required List<MeasurementModel> measurements,
    required Map<String, OrderBalance> orderBalancesMap,
    required double totalBusiness,
    required double totalPaid,
    required double totalOutstanding,
    required String shopName,
    required bool isDesktop,
  }) {
    final unpaidOrders = orders.where((o) {
      final b = orderBalancesMap[o.id];
      final rem = b != null ? b.remainingAmount : o.remainingAmount;
      return rem > 0;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Customer billing',
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: _Tokens.ink)),
                const SizedBox(height: 2),
                Text('Payments and order value across this client.',
                    style: GoogleFonts.inter(fontSize: 11, color: _Tokens.muted)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: totalOutstanding > 0 ? _Tokens.roseBg : _Tokens.greenBg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                totalOutstanding > 0
                    ? 'Rs ${totalOutstanding.toInt()} outstanding'
                    : 'Fully paid ✓',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: totalOutstanding > 0 ? _Tokens.rose : _Tokens.green,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 3 Summary Balances Row (Total business, Total paid, Outstanding)
        Row(
          children: [
            Expanded(
              child: _buildBalanceCard(
                label: 'TOTAL BUSINESS',
                value: 'Rs ${totalBusiness.toInt()}',
                bg: _Tokens.goldBg,
                line: _Tokens.goldLine,
                numColor: _Tokens.goldInk,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildBalanceCard(
                label: 'TOTAL PAID',
                value: 'Rs ${totalPaid.toInt()}',
                bg: _Tokens.greenBg,
                line: _Tokens.greenLine,
                numColor: _Tokens.greenInk,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildBalanceCard(
                label: 'OUTSTANDING',
                value: 'Rs ${totalOutstanding.toInt()}',
                bg: _Tokens.roseBg,
                line: _Tokens.roseLine,
                numColor: _Tokens.rose2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Monthly Mini Chart Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _Tokens.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _Tokens.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardTitle('Monthly Order Value'),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildChartBar(0.38, 'Sep'),
                    _buildChartBar(0.52, 'Oct'),
                    _buildChartBar(0.44, 'Nov'),
                    _buildChartBar(0.70, 'Dec'),
                    _buildChartBar(0.82, 'Jan'),
                    _buildChartBar(0.96, 'Feb'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Actions & Transactions Grid
        if (isDesktop) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Actions & Recent Transactions
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _Tokens.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _Tokens.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCardTitle('Payment Action'),
                      const SizedBox(height: 12),
                      _buildPaymentActionButtons(customer, unpaidOrders, totalOutstanding, shopName),
                      const SizedBox(height: 18),
                      _buildCardTitle('Recent Transactions'),
                      const SizedBox(height: 10),
                      _buildRecentActivityTimeline(orders),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Right: All Orders Table with Statement Button
              Expanded(
                flex: 6,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _Tokens.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _Tokens.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildCardTitle('All Orders · ${orders.length}'),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _Tokens.blueBg,
                              foregroundColor: _Tokens.blue,
                              elevation: 0,
                              side: const BorderSide(color: _Tokens.blueLine),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _exportStatementPdf(
                              customer: customer,
                              orders: orders,
                              measurements: measurements,
                              orderBalancesMap: orderBalancesMap,
                              shopName: shopName,
                            ),
                            icon: const Icon(Icons.print_outlined, size: 14, color: _Tokens.blue),
                            label: Text('Statement (A4)',
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: _Tokens.blue)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildAllOrdersBillingList(orders, orderBalancesMap),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _Tokens.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _Tokens.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardTitle('Payment Action'),
                const SizedBox(height: 10),
                _buildPaymentActionButtons(customer, unpaidOrders, totalOutstanding, shopName),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCardTitle('Orders Statement'),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _Tokens.blueBg,
                        foregroundColor: _Tokens.blue,
                        elevation: 0,
                        side: const BorderSide(color: _Tokens.blueLine),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _exportStatementPdf(
                        customer: customer,
                        orders: orders,
                        measurements: measurements,
                        orderBalancesMap: orderBalancesMap,
                        shopName: shopName,
                      ),
                      icon: const Icon(Icons.print_outlined, size: 14, color: _Tokens.blue),
                      label: Text('Print Statement',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: _Tokens.blue)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildAllOrdersBillingList(orders, orderBalancesMap),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCardTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: _Tokens.ink,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildRecentActivityTimeline(List<OrderModel> orders) {
    if (orders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No activity recorded yet',
          style: GoogleFonts.inter(fontSize: 11, color: _Tokens.muted),
        ),
      );
    }
    final recent = orders.take(4).toList();
    return Column(
      children: recent.map((order) {
        final dateStr = DateFormat('dd MMM yyyy').format(order.orderDate);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: _Tokens.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '#${order.orderNumber}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: _Tokens.ink,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dateStr,
                    style: GoogleFonts.inter(fontSize: 10, color: _Tokens.muted),
                  ),
                ],
              ),
              Text(
                'Rs ${_formatK(order.totalAmount)}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: _Tokens.ink,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBalanceCard({
    required String label,
    required String value,
    required Color bg,
    required Color line,
    required Color numColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w900, color: _Tokens.muted, letterSpacing: 0.7)),
          const SizedBox(height: 12),
          Text(value,
              style: GoogleFonts.jetBrainsMono(fontSize: 17, fontWeight: FontWeight.w800, color: numColor, letterSpacing: -0.6)),
        ],
      ),
    );
  }

  Widget _buildChartBar(double fraction, String monthLabel) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              height: 32 * fraction,
              decoration: BoxDecoration(
                color: _Tokens.gold,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ),
            const SizedBox(height: 4),
            Text(monthLabel, style: GoogleFonts.inter(fontSize: 8, color: _Tokens.muted, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentActionButtons(
    CustomerModel customer,
    List<OrderModel> unpaidOrders,
    double totalOutstanding,
    String shopName,
  ) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _Tokens.green,
              foregroundColor: _Tokens.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
            ),
            onPressed: () => _handleRecordPayment(unpaidOrders),
            icon: const Icon(Icons.add_rounded, size: 16, color: _Tokens.white),
            label: Text('Record Payment',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: _Tokens.white)),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 40,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              backgroundColor: _Tokens.greenBg,
              foregroundColor: _Tokens.greenInk,
              side: const BorderSide(color: _Tokens.greenLine),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
            ),
            onPressed: () => _sendDueReminder(customer, totalOutstanding, shopName),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15, color: _Tokens.greenInk),
            label: Text(
              totalOutstanding > 0
                  ? 'Send Rs ${totalOutstanding.toInt()} due reminder'
                  : 'Send WhatsApp message',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: _Tokens.greenInk),
            ),
          ),
        ),
      ],
    );
  }

  void _handleRecordPayment(List<OrderModel> unpaidOrders) {
    HapticFeedback.lightImpact();
    if (unpaidOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All orders are already fully paid ✓'),
          backgroundColor: _Tokens.green,
        ),
      );
      return;
    }

    if (unpaidOrders.length == 1) {
      AddPaymentModal.show(context, order: unpaidOrders.first);
    } else {
      showModalBottomSheet<OrderModel>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          decoration: const BoxDecoration(
            color: _Tokens.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select Order for Payment',
                  style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w800, color: _Tokens.ink)),
              const SizedBox(height: 4),
              Text('Choose which order to record payment against:',
                  style: GoogleFonts.inter(fontSize: 11, color: _Tokens.muted)),
              const SizedBox(height: 14),
              ...unpaidOrders.map((o) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${o.tokenNumber} · ${o.itemsSummary}',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                    subtitle: Text('Remaining: Rs ${o.remainingAmount.toInt()}',
                        style: GoogleFonts.inter(fontSize: 10, color: _Tokens.rose, fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: _Tokens.muted),
                    onTap: () {
                      Navigator.pop(ctx);
                      AddPaymentModal.show(context, order: o);
                    },
                  )),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildAllOrdersBillingList(List<OrderModel> orders, Map<String, OrderBalance> balances) {
    if (orders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text('No orders recorded yet.', style: GoogleFonts.inter(fontSize: 12, color: _Tokens.muted)),
      );
    }

    return Column(
      children: orders.map((order) {
        final b = balances[order.id];
        final total = b != null ? (b.totalAmount - b.discount) : (order.totalAmount - order.discount);
        final due = b != null ? b.remainingAmount : order.remainingAmount;

        return InkWell(
          onTap: () => context.push('/orders/${order.id}'),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _Tokens.lineSoft)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: _Tokens.goldBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    order.tokenNumber.isNotEmpty ? order.tokenNumber : '#${order.orderNumber}',
                    style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.w800, color: _Tokens.goldInk),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.itemsSummary.isNotEmpty ? order.itemsSummary : 'Order',
                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w800, color: _Tokens.ink),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text('${DateFormat('dd MMM yy').format(order.orderDate)} · ${order.status.label}',
                          style: GoogleFonts.inter(fontSize: 9.5, color: _Tokens.muted)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Rs ${total.toInt()}',
                        style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w800, color: _Tokens.ink)),
                    Text(
                      due > 0 ? 'Due ${due.toInt()}' : 'Paid ✓',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: due > 0 ? _Tokens.rose : _Tokens.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── 10. DIALOGS & ACTIONS ───────────────────────────────────────────────────
  Future<void> _sendDueReminder(CustomerModel customer, double dueAmount, String shopName) async {
    var phone = customer.phone.replaceAll(RegExp(r'\D'), '');
    if (phone.startsWith('0')) {
      phone = '92${phone.substring(1)}';
    }
    final sName = shopName.isNotEmpty ? shopName : 'Darzi Pro';
    final message =
        "Assalam-o-Alaikum ${customer.name},\n"
        "This is a gentle reminder from $sName regarding your outstanding balance of Rs ${dueAmount.toInt()}.\n"
        "JazakAllah!";
    final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp')),
      );
    }
  }

  Future<void> _makePhoneCall(String phone, BuildContext context) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not dial $phone')),
      );
    }
  }

  Future<void> _openWhatsApp(String phone, BuildContext context) async {
    var cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '92${cleanPhone.substring(1)}';
    }
    final uri = Uri.parse('https://wa.me/$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp')),
      );
    }
  }

  Future<void> _exportStatementPdf({
    required CustomerModel customer,
    required List<OrderModel> orders,
    required List<MeasurementModel> measurements,
    required Map<String, OrderBalance> orderBalancesMap,
    required String shopName,
  }) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating Customer Statement PDF (A4)…'), duration: Duration(seconds: 1)),
      );
      final bytes = await DarziPdfBuilder.buildCustomerStatementA4(
        customer: customer,
        orders: orders,
        measurements: measurements,
        orderBalances: orderBalancesMap,
        shopName: shopName,
      );
      await Printing.layoutPdf(
        name: 'Statement_${customer.name}.pdf',
        onLayout: (_) async => Uint8List.fromList(bytes),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate statement: $e'), backgroundColor: _Tokens.rose),
        );
      }
    }
  }

  Future<void> _confirmDeleteCustomer(CustomerModel customer, int orderCount, double dueAmount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _Tokens.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: _Tokens.roseBg, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.delete_outline_rounded, color: _Tokens.rose, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Delete ${customer.name}?',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: _Tokens.ink)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${customer.name} has $orderCount order(s) and Rs ${dueAmount.toInt()} outstanding.',
              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: _Tokens.ink),
            ),
            const SizedBox(height: 8),
            Text(
              'Deleting will soft-archive this customer and hide them from the client list. Their complete order history and naap profiles will stay safely on record for bookkeeping and past audits.',
              style: GoogleFonts.inter(fontSize: 11.5, color: _Tokens.muted, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _Tokens.muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _Tokens.rose,
              foregroundColor: _Tokens.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Archive Customer', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _Tokens.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(customersProvider.notifier).deleteCustomer(customer.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${customer.name} archived successfully'),
              backgroundColor: _Tokens.green,
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete customer: $e'), backgroundColor: _Tokens.rose),
          );
        }
      }
    }
  }
}
