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
  static const Color gold3 = Color(0xFFD88A13);
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

  static const Color violet = Color(0xFF8764E8);
  static const Color violetBg = Color(0xFFF3F0FF);
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
  late String _nowFormatted; // initState mein set hoga — har build pe DateTime.now() nahi

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
    _nowFormatted = DateFormat('dd MMM · hh:mm a').format(DateTime.now());
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
                      horizontal: isDesktop ? 26 : 14,
                      vertical: isDesktop ? 22 : 12,
                    ),
                    children: [
                      // ── TOP HERO HEADER ─────────────────────────────────
                      _buildHeroHeader(currentCustomer, isDesktop),
                      const SizedBox(height: 18),

                      if (isDesktop) ...[
                        // ── DESKTOP 2-COLUMN LAYOUT ──────────────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Column (340px Sticky Profile Panel)
                            SizedBox(
                              width: 340,
                              child: _buildProfilePanel(
                                customer: currentCustomer,
                                orders: orders,
                                measurements: measurements,
                                totalBusiness: totalBusiness,
                                totalOutstanding: totalOutstanding,
                                shopName: shopName,
                              ),
                            ),
                            const SizedBox(width: 18),

                            // Right Column (Tabs + Views)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildNavbar(measurements.length, orders.length, totalOutstanding),
                                  const SizedBox(height: 18),
                                  _buildActiveTabContent(
                                    customer: currentCustomer,
                                    orders: orders,
                                    measurements: measurements,
                                    orderBalancesMap: orderBalancesMap,
                                    totalBusiness: totalBusiness,
                                    totalPaid: totalPaid,
                                    totalOutstanding: totalOutstanding,
                                    shopName: shopName,
                                    isDesktop: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        // ── MOBILE SINGLE-COLUMN STACKED LAYOUT ────────────
                        _buildMobileClientCard(
                          customer: currentCustomer,
                          ordersCount: orders.length,
                          naapCount: measurements.length,
                          totalBusiness: totalBusiness,
                          totalOutstanding: totalOutstanding,
                          shopName: shopName,
                        ),
                        const SizedBox(height: 14),
                        _buildNavbar(measurements.length, orders.length, totalOutstanding),
                        const SizedBox(height: 14),
                        _buildActiveTabContent(
                          customer: currentCustomer,
                          orders: orders,
                          measurements: measurements,
                          orderBalancesMap: orderBalancesMap,
                          totalBusiness: totalBusiness,
                          totalPaid: totalPaid,
                          totalOutstanding: totalOutstanding,
                          shopName: shopName,
                          isDesktop: false,
                        ),
                      ],
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

  // ── 1. HERO HEADER ──────────────────────────────────────────────────────────
  Widget _buildHeroHeader(CustomerModel customer, bool isDesktop) {
    // _nowFormatted initState mein set hota hai — har build pe DateTime.now() nahi

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _Tokens.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _Tokens.line, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A111827),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Brand Info
          Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.arrow_back_rounded, color: _Tokens.ink, size: 20),
                onPressed: () => context.pop(),
              ),
              const SizedBox(width: 12),
              // Brand mark
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_Tokens.gold2, _Tokens.gold],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x38E9A227),
                          blurRadius: 14,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'D',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF241605),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: _Tokens.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: _Tokens.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Darzi Pro',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _Tokens.ink,
                      letterSpacing: -0.4,
                    ),
                  ),
                  if (isDesktop)
                    Text(
                      'Client workspace · $_nowFormatted',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: _Tokens.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Actions
          Row(
            children: [
              // Search button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _Tokens.ink,
                  side: const BorderSide(color: _Tokens.line),
                  backgroundColor: _Tokens.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                onPressed: () {
                  _switchTab(2); // Jump to Orders tab
                  Future.delayed(const Duration(milliseconds: 100), () {
                    _orderSearchFocus.requestFocus();
                  });
                },
                icon: const Icon(Icons.search_rounded, size: 16, color: _Tokens.muted),
                label: Row(
                  children: [
                    if (isDesktop) ...[
                      Text('Search', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: _Tokens.paper,
                          border: Border.all(color: _Tokens.line),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '⌘K',
                          style: GoogleFonts.jetBrainsMono(fontSize: 9, color: _Tokens.muted, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // New Order button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _Tokens.gold,
                  foregroundColor: const Color(0xFF211500),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                  shadowColor: const Color(0x38E9A227),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  NewOrderModal.show(context, preSelectedCustomer: customer);
                },
                icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF211500)),
                label: Text(
                  'New Order',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF211500),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 2. DESKTOP PROFILE PANEL (STICKY SIDEBAR) ──────────────────────────────
  Widget _buildProfilePanel({
    required CustomerModel customer,
    required List<OrderModel> orders,
    required List<MeasurementModel> measurements,
    required double totalBusiness,
    required double totalOutstanding,
    required String shopName,
  }) {
    final statusText = customer.totalOrders == 0
        ? 'NEW'
        : (customer.totalOrders <= 5 ? 'ACTIVE' : 'REGULAR');
    final shortId = customer.id.length >= 6
        ? 'DK-${customer.id.substring(0, 5).toUpperCase()}'
        : customer.id;

    return Container(
      decoration: BoxDecoration(
        color: _Tokens.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _Tokens.line, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A111827),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Cover
          Container(
            height: 110,
            decoration: const BoxDecoration(
              color: _Tokens.goldBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(23)),
              gradient: RadialGradient(
                center: Alignment(0.7, -0.4),
                radius: 1.2,
                colors: [Color(0x38E9A227), Color(0x105478E8), _Tokens.paper2],
              ),
            ),
          ),

          // Profile Body
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar with Negative Offset
                Transform.translate(
                  offset: const Offset(0, -43),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 86,
                            height: 86,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_Tokens.gold2, _Tokens.gold3],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: _Tokens.white, width: 5),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x38D98A13),
                                  blurRadius: 20,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              customer.initials,
                              style: GoogleFonts.outfit(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: _Tokens.white,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: _Tokens.green,
                                shape: BoxShape.circle,
                                border: Border.all(color: _Tokens.white, width: 3),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _Tokens.violetBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: _Tokens.violet,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              statusText,
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: _Tokens.violet,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Name & Client ID (compensate for translation offset)
                Transform.translate(
                  offset: const Offset(0, -32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _Tokens.ink,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: _Tokens.faint,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            shortId,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10.5,
                              color: _Tokens.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Mini Sparkline Card
                Transform.translate(
                  offset: const Offset(0, -22),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _Tokens.paper,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _Tokens.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'LAST 6 MONTHS',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: _Tokens.muted,
                                letterSpacing: 0.7,
                              ),
                            ),
                            Text(
                              '+42%',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _Tokens.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 32,
                          width: double.infinity,
                          child: CustomPaint(painter: _SparklinePainter()),
                        ),
                      ],
                    ),
                  ),
                ),

                // Contact Details
                Transform.translate(
                  offset: const Offset(0, -14),
                  child: Column(
                    children: [
                      // Phone Row with Tap-to-Call + WhatsApp
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _makePhoneCall(customer.phone, context),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: _Tokens.paper,
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      child: const Icon(Icons.phone_outlined, size: 14, color: _Tokens.ink),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        customer.phone,
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: _Tokens.muted,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // WhatsApp Button
                          InkWell(
                            onTap: () => _openWhatsApp(customer.phone, context),
                            borderRadius: BorderRadius.circular(9),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: _Tokens.greenBg,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(color: _Tokens.greenLine),
                              ),
                              child: const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: _Tokens.green),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Address Row
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: _Tokens.paper,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(Icons.location_on_outlined, size: 14, color: _Tokens.ink),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              customer.address.isNotEmpty ? customer.address : 'Lahore, Pakistan',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: _Tokens.muted,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Member Since Row
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: _Tokens.paper,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(Icons.schedule_rounded, size: 14, color: _Tokens.ink),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Member since ${_timeAgo(customer.createdAt)}',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: _Tokens.muted,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      const Divider(color: _Tokens.line, height: 1),
                      const SizedBox(height: 16),

                      // 2x2 KPI Grid
                      Row(
                        children: [
                          Expanded(child: _buildPanelKpiBox('ORDERS', '${orders.length}', null)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildPanelKpiBox('NAAP', '${measurements.length}', null)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _buildPanelKpiBox('BUSINESS', 'Rs ${_formatK(totalBusiness)}', _Tokens.green)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildPanelKpiBox(
                              'DUE',
                              'Rs ${_formatK(totalOutstanding)}',
                              totalOutstanding > 0 ? _Tokens.rose : _Tokens.green,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Actions List
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _Tokens.gold,
                            foregroundColor: const Color(0xFF211500),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            NewOrderModal.show(context, preSelectedCustomer: customer);
                          },
                          icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF211500)),
                          label: Text('Create New Order',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF211500))),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _Tokens.white,
                            side: const BorderSide(color: _Tokens.line),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            EditCustomerModal.show(context, customer: customer);
                          },
                          icon: const Icon(Icons.edit_outlined, size: 15, color: _Tokens.ink),
                          label: Text('Edit Client',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _Tokens.ink)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            backgroundColor: _Tokens.roseBg,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                              side: const BorderSide(color: _Tokens.roseLine),
                            ),
                          ),
                          onPressed: () => _confirmDeleteCustomer(customer, orders.length, totalOutstanding),
                          icon: const Icon(Icons.delete_outline_rounded, size: 15, color: _Tokens.rose),
                          label: Text('Delete Customer',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: _Tokens.rose)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelKpiBox(String label, String value, Color? numColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: _Tokens.paper,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _Tokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: numColor ?? _Tokens.ink,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              color: _Tokens.muted,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. MOBILE CLIENT CARD ───────────────────────────────────────────────────
  Widget _buildMobileClientCard({
    required CustomerModel customer,
    required int ordersCount,
    required int naapCount,
    required double totalBusiness,
    required double totalOutstanding,
    required String shopName,
  }) {
    final statusText = customer.totalOrders == 0
        ? 'NEW CLIENT'
        : (customer.totalOrders <= 5 ? 'ACTIVE CLIENT' : 'REGULAR CLIENT');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Tokens.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _Tokens.line),
        boxShadow: const [
          BoxShadow(color: Color(0x08111827), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_Tokens.gold2, _Tokens.gold3]),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  customer.initials,
                  style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: _Tokens.white),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customer.name,
                        style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w800, color: _Tokens.ink)),
                    const SizedBox(height: 2),
                    Text(customer.phone,
                        style: GoogleFonts.jetBrainsMono(fontSize: 11, color: _Tokens.muted)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _Tokens.violetBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusText,
                        style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w800, color: _Tokens.violet),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.phone_outlined, size: 18, color: _Tokens.ink),
                    onPressed: () => _makePhoneCall(customer.phone, context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: _Tokens.green),
                    onPressed: () => _openWhatsApp(customer.phone, context),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4 Mobile Stats
          Row(
            children: [
              Expanded(child: _buildMiniStat('Orders', '$ordersCount', null)),
              const SizedBox(width: 6),
              Expanded(child: _buildMiniStat('Naap', '$naapCount', null)),
              const SizedBox(width: 6),
              Expanded(child: _buildMiniStat('Business', _formatK(totalBusiness), _Tokens.green)),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMiniStat(
                  'Due',
                  _formatK(totalOutstanding),
                  totalOutstanding > 0 ? _Tokens.rose : _Tokens.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color? color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: _Tokens.paper,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _Tokens.line),
      ),
      child: Column(
        children: [
          Text(value,
              style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.w800, color: color ?? _Tokens.ink)),
          const SizedBox(height: 2),
          Text(label.toUpperCase(),
              style: GoogleFonts.inter(fontSize: 7.5, fontWeight: FontWeight.w900, color: _Tokens.muted)),
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _Tokens.line),
        boxShadow: const [
          BoxShadow(color: Color(0x08111827), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          _buildNavTab(label: 'Profile', index: 0),
          _buildNavTab(label: 'Naap', index: 1, countBadge: '$naapCount'),
          _buildNavTab(label: 'Orders', index: 2, countBadge: '$ordersCount'),
          _buildNavTab(
            label: 'Billing',
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
            borderRadius: BorderRadius.circular(13),
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
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
                  color: isActive ? const Color(0xFF211500) : _Tokens.muted,
                ),
              ),
              if (countBadge != null) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0x26000000)
                        : (badgeColor?.withValues(alpha: 0.12) ?? const Color(0x14000000)),
                    borderRadius: BorderRadius.circular(6),
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

  // ── 6. TAB 1: PROFILE TAB ───────────────────────────────────────────────────
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
    final paidPercent = totalBusiness > 0
        ? ((totalPaid / totalBusiness) * 100).toStringAsFixed(1)
        : '100.0';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Client overview',
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: _Tokens.ink)),
                const SizedBox(height: 2),
                Text('Everything important about this customer, in one place.',
                    style: GoogleFonts.inter(fontSize: 11, color: _Tokens.muted)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _Tokens.greenBg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: _Tokens.green, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('Active client', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: _Tokens.green)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Bento Grid: Personal Info Card + 4 Metric Cards
        if (isDesktop) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Personal Info Card
              Expanded(
                flex: 5,
                child: _buildPersonalInfoCard(customer, measurements),
              ),
              const SizedBox(width: 12),
              // Right: 4 Metrics Cards (2x2)
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            icon: Icons.inventory_2_outlined,
                            iconColor: _Tokens.gold,
                            iconBg: _Tokens.goldBg,
                            value: '${orders.length}',
                            label: 'TOTAL ORDERS',
                            trend: orders.length > 1 ? 'Repeat customer' : 'New customer',
                            trendColor: _Tokens.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            icon: Icons.check_circle_outline_rounded,
                            iconColor: _Tokens.green,
                            iconBg: _Tokens.greenBg,
                            value: 'Rs ${_formatK(totalPaid)}',
                            label: 'PAID SO FAR',
                            trend: '$paidPercent% collected',
                            trendColor: _Tokens.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            icon: Icons.warning_amber_rounded,
                            iconColor: _Tokens.rose,
                            iconBg: _Tokens.roseBg,
                            value: 'Rs ${_formatK(totalOutstanding)}',
                            label: 'OUTSTANDING',
                            trend: totalOutstanding > 0 ? 'Payment due' : 'All clear',
                            trendColor: totalOutstanding > 0 ? _Tokens.rose : _Tokens.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            icon: Icons.straighten_rounded,
                            iconColor: _Tokens.blue,
                            iconBg: _Tokens.blueBg,
                            value: '${measurements.length}',
                            label: 'NAAP PROFILES',
                            trend: 'Updated recently',
                            trendColor: _Tokens.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ] else ...[
          _buildPersonalInfoCard(customer, measurements),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.inventory_2_outlined,
                  iconColor: _Tokens.gold,
                  iconBg: _Tokens.goldBg,
                  value: '${orders.length}',
                  label: 'TOTAL ORDERS',
                  trend: 'Repeat customer',
                  trendColor: _Tokens.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: _Tokens.green,
                  iconBg: _Tokens.greenBg,
                  value: 'Rs ${_formatK(totalPaid)}',
                  label: 'PAID SO FAR',
                  trend: '$paidPercent% paid',
                  trendColor: _Tokens.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.warning_amber_rounded,
                  iconColor: _Tokens.rose,
                  iconBg: _Tokens.roseBg,
                  value: 'Rs ${_formatK(totalOutstanding)}',
                  label: 'OUTSTANDING',
                  trend: totalOutstanding > 0 ? 'Due' : 'Clear',
                  trendColor: totalOutstanding > 0 ? _Tokens.rose : _Tokens.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.straighten_rounded,
                  iconColor: _Tokens.blue,
                  iconBg: _Tokens.blueBg,
                  value: '${measurements.length}',
                  label: 'NAAP PROFILES',
                  trend: 'Active',
                  trendColor: _Tokens.blue,
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 14),

        // Recent Activity & Latest Orders Section
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _Tokens.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _Tokens.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isDesktop) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timeline
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCardTitle('Recent Activity'),
                          const SizedBox(height: 12),
                          _buildRecentActivityTimeline(orders),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Latest Orders
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCardTitle('Latest Orders'),
                          const SizedBox(height: 12),
                          _buildLatestOrdersTable(orders, orderBalancesMap),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else ...[
                _buildCardTitle('Recent Activity'),
                const SizedBox(height: 10),
                _buildRecentActivityTimeline(orders),
                const SizedBox(height: 16),
                _buildCardTitle('Latest Orders'),
                const SizedBox(height: 10),
                _buildLatestOrdersTable(orders, orderBalancesMap),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: _Tokens.faint,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildPersonalInfoCard(CustomerModel customer, List<MeasurementModel> measurements) {
    final latestNaapDate = measurements.isNotEmpty
        ? DateFormat('dd MMM yyyy').format(measurements.first.updatedAt)
        : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _Tokens.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _Tokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle('Personal Information'),
          const SizedBox(height: 14),
          _buildInfoGridRow('Full name', customer.name, 'Gender', customer.gender.label),
          _buildInfoGridRow('Phone', customer.phone, 'Member since', _timeAgo(customer.createdAt)),
          _buildInfoGridRow('Address', customer.address.isNotEmpty ? customer.address : '-', 'City', 'Lahore'),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _Tokens.goldBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _Tokens.goldLine),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: _Tokens.goldInk),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    latestNaapDate != null
                        ? 'Customer profile is ready. Latest measurement update: $latestNaapDate.'
                        : 'Customer profile is active. Add a naap profile to start tailoring.',
                    style: GoogleFonts.inter(fontSize: 11, color: _Tokens.muted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoGridRow(String key1, String val1, String key2, String val2) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(key1, style: GoogleFonts.inter(fontSize: 9.5, color: _Tokens.muted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(val1, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: _Tokens.ink)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(key2, style: GoogleFonts.inter(fontSize: 9.5, color: _Tokens.muted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(val2, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: _Tokens.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String value,
    required String label,
    required String trend,
    required Color trendColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Tokens.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _Tokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _Tokens.ink,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              color: _Tokens.muted,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(width: 4, height: 4, decoration: BoxDecoration(color: trendColor, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(
                trend,
                style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w700, color: trendColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityTimeline(List<OrderModel> orders) {
    final List<Map<String, dynamic>> events = [];
    for (final order in orders) {
      events.add({
        'type': 'order',
        'date': order.orderDate,
        'title': 'New Order · ${order.itemsSummary.isNotEmpty ? order.itemsSummary : 'Suit'}',
        'subtitle': '${order.tokenNumber} · ${DateFormat('dd MMM').format(order.orderDate)}',
        'amount': '-Rs ${order.totalAmount.toInt()}',
        'isCredit': false,
      });
      for (final p in order.payments) {
        events.add({
          'type': 'payment',
          'date': p.paidAt,
          'title': 'Payment · ${p.method.name.toUpperCase()}',
          'subtitle': '${order.tokenNumber} · ${DateFormat('dd MMM').format(p.paidAt)}',
          'amount': '+Rs ${p.amount.toInt()}',
          'isCredit': true,
        });
      }
    }
    events.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    final displayEvents = events.take(4).toList();

    if (displayEvents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text('No activity recorded yet.', style: GoogleFonts.inter(fontSize: 12, color: _Tokens.muted)),
      );
    }

    return Column(
      children: displayEvents.map((e) {
        final isCredit = e['isCredit'] as bool;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: _Tokens.paper,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isCredit ? _Tokens.greenBg : _Tokens.blueBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isCredit ? Icons.arrow_downward_rounded : Icons.shopping_bag_outlined,
                  size: 15,
                  color: isCredit ? _Tokens.green : _Tokens.blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e['title'] as String,
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: _Tokens.ink),
                        overflow: TextOverflow.ellipsis),
                    Text(e['subtitle'] as String,
                        style: GoogleFonts.inter(fontSize: 9.5, color: _Tokens.muted)),
                  ],
                ),
              ),
              Text(
                e['amount'] as String,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isCredit ? _Tokens.green : _Tokens.rose,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLatestOrdersTable(List<OrderModel> orders, Map<String, OrderBalance> balances) {
    final recentOrders = orders.take(3).toList();

    if (recentOrders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text('No orders recorded yet.', style: GoogleFonts.inter(fontSize: 12, color: _Tokens.muted)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _Tokens.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Tokens.line),
      ),
      child: Column(
        children: recentOrders.map((order) {
          final b = balances[order.id];
          final total = b != null ? (b.totalAmount - b.discount) : (order.totalAmount - order.discount);
          final due = b != null ? b.remainingAmount : order.remainingAmount;

          return InkWell(
            onTap: () => context.push('/orders/${order.id}'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _Tokens.lineSoft)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: _Tokens.goldBg,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: _Tokens.goldLine),
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
                        Text('${DateFormat('dd MMM yyyy').format(order.orderDate)} · ${order.status.label}',
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
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rendering A5 Naap Card…'), duration: Duration(seconds: 1)),
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

      final pngBytes = await CardImageCapturer.captureOnDemand(
        context,
        cardWidget: NaapCardWidget(
          order: effectiveOrder,
          customer: customer,
          measurement: m,
        ),
        pixelRatio: 1.0,
      );

      final pdfBytes = await DarziPdfBuilder.buildPdfFromImageBytes(
        pngBytes,
        pageFormat: PdfPageFormat.a5,
      );

      await Printing.layoutPdf(
        name: 'Naap_${customer.name}_${m.profileName}.pdf',
        onLayout: (_) async => Uint8List.fromList(pdfBytes),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to print naap card: $e'), backgroundColor: _Tokens.rose),
        );
      }
    }
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

// ── CUSTOM SPARKLINE PAINTER ──────────────────────────────────────────────────
class _SparklinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = _Tokens.green
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x5918B887), Color(0x0018B887)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    path.moveTo(0, size.height * 0.8);
    path.lineTo(size.width * 0.16, size.height * 0.7);
    path.lineTo(size.width * 0.33, size.height * 0.6);
    path.lineTo(size.width * 0.50, size.height * 0.65);
    path.lineTo(size.width * 0.66, size.height * 0.45);
    path.lineTo(size.width * 0.83, size.height * 0.30);
    path.lineTo(size.width, size.height * 0.20);

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
