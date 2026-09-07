import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_providers.dart';
import '../orders/new_order_modal.dart';
import '../orders/widgets/add_payment_modal.dart';
import 'edit_customer_modal.dart';
import '../../core/widgets/confirm_delete_modal.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerDetailScreen> createState() =>
      _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen>
    with SingleTickerProviderStateMixin {
  int _activeTab = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _triggerFadeIn() {
    if (!_fadeController.isAnimating && _fadeController.value < 1.0) {
      _fadeController.forward(from: 0);
    }
  }

  String _timeAgoDetailed(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }



  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);
    final ordersAsync = ref.watch(ordersProvider);
    final measurementsAsync = ref.watch(measurementsProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? const Color(0xFF070D1A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF0D1628) : const Color(0xFFFFFFFF);
    final cardBorder = isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF5A7090) : const Color(0xFF64748B);

    return Container(
      color: bg,
      child: customersAsync.when(
        loading: () => const _DetailSkeleton(),
        error: (err, _) => _DetailError(
          message: err.toString(),
          onRetry: () => ref.invalidate(customersProvider),
        ),
        data: (customers) {
          CustomerModel? customerNullable;
          try {
            customerNullable = customers.firstWhere(
              (c) => c.id == widget.customerId,
            );
          } catch (_) {}

          if (customerNullable == null) {
            return Scaffold(
              backgroundColor: bg,
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _GlassBackButton(onTap: () => context.pop()),
                      const Expanded(
                        child: EmptyState(
                          emoji: '🔍',
                          title: 'Customer Not Found',
                          subtitle: 'The client you are looking for does not exist.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final customer = customerNullable;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _triggerFadeIn(),
          );

          final orders = ordersAsync.value
                  ?.where((o) => o.customerId == widget.customerId)
                  .toList() ??
              [];
          final measurements = measurementsAsync.value
                  ?.where((m) => m.customerId == widget.customerId)
                  .toList() ??
              [];

          final String statusText;
          final Color statusValColor;
          if (customer.totalOrders == 0) {
            statusText = "New";
            statusValColor = const Color(0xFFF5A623);
          } else if (customer.totalOrders <= 5) {
            statusText = "Active";
            statusValColor = const Color(0xFF10CBA0);
          } else {
            statusText = "Regular";
            statusValColor = const Color(0xFF9B5CF5);
          }

          return Scaffold(
            backgroundColor: bg,
            body: SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  children: [
                    // ── Top Bar ──────────────────────────────────────────
                    Row(
                      children: [
                        _GlassBackButton(onTap: () => context.pop()),
                        const SizedBox(width: 14),
                        Text(
                          "Client Details",
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: titleColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // ── Hero Section ──────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? const [Color(0x1AF5A623), Color(0x08F5A623)]
                              : const [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: isDark ? const Color(0x26F5A623) : const Color(0xFFFCD34D),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          Positioned(
                            top: -40,
                            right: -40,
                            width: 160,
                            height: 160,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: isDark
                                      ? const [Color(0x26F5A623), Colors.transparent]
                                      : const [Color(0x40F5A623), Colors.transparent],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -30,
                            left: -30,
                            width: 120,
                            height: 120,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: isDark
                                      ? const [Color(0x145B72F5), Colors.transparent]
                                      : const [Color(0x205B72F5), Colors.transparent],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                            child: Row(
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x33F5A623),
                                        blurRadius: 20,
                                        offset: Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: CustomerAvatar(
                                    name: customer.name,
                                    size: 72,
                                    borderRadius: 20,
                                    fontSize: 26,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customer.name,
                                        style: GoogleFonts.outfit(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: titleColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        customer.phone,
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 12,
                                          color: subtitleColor,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0x1AF5A623) : const Color(0xFFFFFBEB),
                                              borderRadius: BorderRadius.circular(7),
                                              border: Border.all(
                                                color: isDark ? const Color(0x40F5A623) : const Color(0xFFFCD34D),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              "${customer.gender.emoji} ${customer.gender.label}".toUpperCase(),
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFFD97706),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0x1A5B72F5) : const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(7),
                                              border: Border.all(
                                                color: isDark ? const Color(0x405B72F5) : const Color(0xFFBFDBFE),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              "⚡ $statusText Client".toUpperCase(),
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF2563EB),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Stats Row ────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            emoji: "📋",
                            value: "${orders.length}",
                            label: "Orders",
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            emoji: "📏",
                            value: "${measurements.length}",
                            label: "Naap Sets",
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            emoji: "⚡",
                            value: statusText,
                            label: "Status",
                            valueColor: statusValColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Tabs Container ───────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0x08FFFFFF) : const Color(0xFFF1F5F9),
                        border: Border.all(
                          color: isDark ? const Color(0x0FFFFFFF) : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          buildTab("Profile", 0, isDark: isDark),
                          buildTab("Naap", 1, isDark: isDark),
                          buildTab("Orders", 2, isDark: isDark),
                          buildTab("کھاتہ", 3, isDark: isDark),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Tab Content ──────────────────────────────────────
                    if (_activeTab == 0) ...[
                      // PROFILE TAB
                      Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          border: Border.all(color: cardBorder, width: 1),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isDark
                              ? null
                              : const [
                                  BoxShadow(
                                    color: Color(0x05000000),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  )
                                ],
                        ),
                        child: Column(
                          children: [
                            _buildProfileRow("👤", "Full Name", customer.name, isDark: isDark),
                            _buildProfileRow("📞", "Phone", customer.phone, isMono: true, isDark: isDark),
                            _buildProfileRow("📍", "Address", customer.address.isEmpty ? null : customer.address, isDark: isDark),
                            _buildProfileRow(customer.gender.emoji, "Gender", customer.gender.label, isDark: isDark),
                            _buildProfileRow("🕐", "Member Since", _timeAgoDetailed(customer.createdAt), isSecondaryVal: true, isDark: isDark),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Actions Grid
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                NewOrderModal.show(context, preSelectedCustomer: customer);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0x1A10CBA0),
                                  border: Border.all(color: const Color(0x4010CBA0), width: 1),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.add_rounded,
                                      color: Color(0xFF10CBA0),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "New Order",
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF10CBA0),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                EditCustomerModal.show(context, customer: customer);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFF5A623), Color(0xFFD97706)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(13),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x4DF5A623),
                                      blurRadius: 16,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.edit_rounded,
                                      color: Color(0xFF1A0A00),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Edit Profile",
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1A0A00),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                         onTap: () async {
                           HapticFeedback.lightImpact();
                           final confirmed = await ConfirmDeleteModal.show(
                             context,
                             title: 'Delete Customer',
                             itemName: customer.name,
                             description: 'All orders and measurements will also be deleted.',
                           );
                           if (confirmed == true) {
                             try {
                               await ref.read(customersProvider.notifier).deleteCustomer(customer.id);
                               if (context.mounted) {
                                 ScaffoldMessenger.of(context).showSnackBar(
                                   const SnackBar(
                                     content: Text('Customer deleted'),
                                     backgroundColor: Color(0xFF10CBA0),
                                   ),
                                 );
                                 context.pop();
                               }
                             } catch (e) {
                               if (context.mounted) {
                                 ScaffoldMessenger.of(context).showSnackBar(
                                   SnackBar(
                                     content: Text('Failed to delete customer: $e'),
                                     backgroundColor: const Color(0xFFFF3A58),
                                   ),
                                 );
                               }
                             }
                           }
                         },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0x0FFF3A58),
                            border: Border.all(color: const Color(0x26FF3A58), width: 1),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.delete_outline_rounded,
                                color: Color(0xFFFF3A58),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Delete Customer",
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFFF3A58),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else if (_activeTab == 1) ...[
                      // NAAP TAB — Multiple Profiles
                      if (measurements.isEmpty)
                        _buildEmptyTabState(
                          '📏',
                          'No Measurement Profiles Yet',
                          'Add a naap profile to save this client\'s measurements.',
                          '+ Add First Profile',
                          () => _showAddProfileDialog(context, customer, isDark: isDark),
                          isDark: isDark,
                        )
                      else ...[
                        ...measurements.map(
                          (m) => _MeasurementProfileCard(
                            measurement: m,
                            customerName: customer.name,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => _showAddProfileDialog(context, customer, isDark: isDark),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF5A623), Color(0xFFD97706)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(13),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33F5A623),
                                  blurRadius: 16,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.add_rounded,
                                  color: Color(0xFF1A0A00),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "+ ADD NEW PROFILE",
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1A0A00),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ]
                    ] else if (_activeTab == 2) ...[
                      // ORDERS TAB
                      if (orders.isEmpty)
                        _buildEmptyTabState(
                          '📋',
                          'No Orders Yet',
                          'Create the first order for this client.',
                          '+ New Order',
                          () {
                            HapticFeedback.lightImpact();
                            NewOrderModal.show(context, preSelectedCustomer: customer);
                          },
                          isDark: isDark,
                        )
                      else
                        ...orders.map((o) => _OrderMini(order: o)),
                    ] else ...[
                      // KHAATA TAB (کھاتہ)
                      _CustomerLedgerTab(
                        customer: customer,
                        orders: orders,
                      ),
                    ],
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildTab(String title, int index, {required bool isDark}) {
    final isActive = _activeTab == index;
    final subtitleColor = isDark ? const Color(0xFF5A7090) : const Color(0xFF64748B);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _activeTab = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? (isDark ? const Color(0x1AF5A623) : const Color(0xFFFFFFFF))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive
                  ? (isDark ? const Color(0x40F5A623) : const Color(0xFFF5A623))
                  : Colors.transparent,
              width: 1,
            ),
            boxShadow: isActive && !isDark
                ? const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    )
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              color: isActive ? const Color(0xFFD97706) : subtitleColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileRow(
    String emoji,
    String label,
    String? value, {
    bool isMono = false,
    bool isSecondaryVal = false,
    required bool isDark,
  }) {
    final rowValue = value ?? "Not provided";
    final isDefault = value == null;
    final titleColor = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF5A7090) : const Color(0xFF64748B);

    Color valColor = titleColor;
    if (isDefault) {
      valColor = subtitleColor;
    } else if (isSecondaryVal) {
      valColor = isDark ? const Color(0xFF4A6080) : const Color(0xFF475569);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0x08FFFFFF) : const Color(0xFFF1F5F9),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: subtitleColor,
                ),
              ),
            ],
          ),
          Text(
            rowValue,
            style: isMono
                ? GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: valColor,
                  )
                : GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: valColor,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTabState(
    String emoji,
    String title,
    String subtitle,
    String actionLabel,
    VoidCallback onAction, {
    required bool isDark,
  }) {
    final titleColor = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF5A7090) : const Color(0xFF64748B);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: subtitleColor,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF5A623), Color(0xFFD97706)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  actionLabel,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A0A00),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Add Profile Dialog ────────────────────────────────────────────────────
  Future<void> _showAddProfileDialog(
    BuildContext context,
    CustomerModel customer, {
    required bool isDark,
  }) async {
    HapticFeedback.lightImpact();
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddProfileNameDialog(isDark: isDark),
    );
    if (result != null && context.mounted) {
      final profileName = result['profileName'] ?? 'Naap';
      final categoryName = result['category'];
      String route = '/measurements/${customer.id}/${Uri.encodeComponent(customer.name)}'
          '?profileName=${Uri.encodeComponent(profileName)}';
      if (categoryName != null && categoryName.isNotEmpty) {
        route += '&category=$categoryName';
      }
      context.push(route);
    }
  }
}

// ── Glass Back Button with Hover ────────────────────────────────────
class _GlassBackButton extends StatefulWidget {
  final VoidCallback onTap;
  const _GlassBackButton({required this.onTap});

  @override
  State<_GlassBackButton> createState() => _GlassBackButtonState();
}

class _GlassBackButtonState extends State<_GlassBackButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color bg = isDark ? const Color(0x0DFFFFFF) : const Color(0xFFFFFFFF);
    Color border = isDark ? const Color(0x14FFFFFF) : const Color(0xFFE2E8F0);
    Color iconColor = isDark ? const Color(0xFF5A7090) : const Color(0xFF475569);

    if (_isHovered) {
      bg = const Color(0x1AF5A623);
      border = const Color(0x4DF5A623);
      iconColor = const Color(0xFFD97706);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: border, width: 1),
            boxShadow: isDark
                ? null
                : const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    )
                  ],
          ),
          child: Center(
            child: Icon(
              Icons.arrow_back_rounded,
              color: iconColor,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Stat Card with Hover Highlights ─────────────────────────────────
class _StatCard extends StatefulWidget {
  final String emoji;
  final String value;
  final String label;
  final Color? valueColor;

  const _StatCard({
    required this.emoji,
    required this.value,
    required this.label,
    this.valueColor,
  });

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF5A7090) : const Color(0xFF64748B);

    Color bg = isDark ? const Color(0x08FFFFFF) : const Color(0xFFFFFFFF);
    Color border = isDark ? const Color(0x0FFFFFFF) : const Color(0xFFE2E8F0);

    if (_isHovered) {
      bg = isDark ? const Color(0x0FFFFFFF) : const Color(0xFFF8FAFC);
      border = isDark ? const Color(0x1AFFFFFF) : const Color(0xFFCBD5E1);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border, width: 1),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x05000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  )
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            Text(
              widget.value,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: widget.valueColor ?? titleColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.label.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: subtitleColor,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Measurement Profile Card (Multi-Profile) ─────────────────────────
class _MeasurementProfileCard extends StatelessWidget {
  final MeasurementModel measurement;
  final String customerName;
  const _MeasurementProfileCard({
    required this.measurement,
    required this.customerName,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF0D1628) : const Color(0xFFFFFFFF);
    final cardBorder = isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF5A7090) : const Color(0xFF64748B);

    // Build field preview text (first 3 non-design fields with values)
    final previewFields = measurement.sections
        .where((s) => s.title == 'Measurements')
        .expand((s) => s.fields)
        .where((f) => f.value.isNotEmpty)
        .take(4)
        .toList();

    final dateStr = DateFormat('dd MMM yy').format(measurement.updatedAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border.all(color: cardBorder, width: 1),
        borderRadius: BorderRadius.circular(18),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x05000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                )
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            context.push(
              '/measurements/${measurement.customerId}/${Uri.encodeComponent(customerName)}'
              '?measurementId=${measurement.id}'
              '&profileName=${Uri.encodeComponent(measurement.profileName)}'
              '&category=${measurement.category.name}',
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0x1AF5A623) : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? const Color(0x33F5A623) : const Color(0xFFFCD34D),
                          width: 1,
                        ),
                      ),
                      child: const Center(
                        child: Text('📏', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            measurement.profileName,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: titleColor,
                            ),
                          ),
                          Text(
                            'Updated $dateStr',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0x1AF5A623) : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isDark ? const Color(0x33F5A623) : const Color(0xFFFCD34D), width: 1),
                      ),
                      child: Text(
                        measurement.category.label.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFD97706),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded, size: 18, color: subtitleColor),
                  ],
                ),
                if (previewFields.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(height: 1, color: isDark ? const Color(0x08FFFFFF) : const Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: previewFields.map((f) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0x0AFFFFFF) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? const Color(0x10FFFFFF) : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${f.label}: ${f.value}${f.unit.isNotEmpty ? ' ${f.unit}' : ''}',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Mini Order Card ──────────────────────────────────────────────────
class _OrderMini extends StatelessWidget {
  final OrderModel order;
  const _OrderMini({required this.order});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF0D1628) : const Color(0xFFFFFFFF);
    final cardBorder = isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF5A7090) : const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border.all(color: cardBorder, width: 1),
        borderRadius: BorderRadius.circular(18),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x05000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                )
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/orders/${order.id}');
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.tokenNumber,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFFF5A623) : const Color(0xFFD97706),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.itemsSummary,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                      if (order.deliveryDate != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '📅 ${formatDateShort(order.deliveryDate!)}',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatusPill(status: order.status),
                    const SizedBox(height: 6),
                    Text(
                      formatMoney(order.totalAmount),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Detail Skeleton Loader ───────────────────────────────────────────
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF070D1A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0x06FFFFFF) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  width: 140,
                  height: 24,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Container(
              height: 128,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: List.generate(
                3,
                (_) => Expanded(
                  child: Container(
                    height: 80,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(
              4,
              (_) => Container(
                height: 56,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Detail Error State ───────────────────────────────────────────────
class _DetailError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _DetailError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF070D1A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF0D1628) : const Color(0xFFFFFFFF);
    final cardBorder = isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF5A7090) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              border: Border.all(color: cardBorder, width: 1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  size: 48,
                  color: subtitleColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Could not load customer details',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message.replaceAll('Exception: ', ''),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: subtitleColor,
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onRetry();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF5A623), Color(0xFFD97706)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Try Again',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A0A00),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Add Profile Name Dialog ───────────────────────────────────────────────────
class _AddProfileNameDialog extends StatefulWidget {
  final bool isDark;
  const _AddProfileNameDialog({required this.isDark});

  @override
  State<_AddProfileNameDialog> createState() => _AddProfileNameDialogState();
}

class _AddProfileNameDialogState extends State<_AddProfileNameDialog> {
  static const _presets = [
    {'label': 'شلوار قمیض', 'value': 'شلوار قمیض', 'category': 'men'},
    {'label': 'واسکٹ', 'value': 'واسکٹ', 'category': 'men'},
    {'label': 'شیروانی', 'value': 'شیروانی', 'category': 'men'},
    {'label': 'کرتا پاجامہ', 'value': 'کرتا پاجامہ', 'category': 'men'},
    {'label': 'پینٹ کوٹ', 'value': 'پینٹ کوٹ', 'category': 'men'},
    {'label': 'سوٹ / قمیض', 'value': 'سوٹ / قمیض', 'category': 'women'},
    {'label': 'فراک', 'value': 'فراک', 'category': 'women'},
    {'label': 'Custom...', 'value': '__custom__', 'category': ''},
  ];

  String _selectedPreset = 'شلوار قمیض';
  String _selectedCategory = 'men';
  final _customCtrl = TextEditingController();
  bool _isCustom = false;

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? const Color(0xFF0D1628) : const Color(0xFFFFFFFF);
    final borderColor = isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF5A7090) : const Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: borderColor, width: 1),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0x30FFFFFF) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'نیا پروفائل بنائیں',
            style: GoogleFonts.outfit(
              fontSize: 20, fontWeight: FontWeight.w800, color: titleColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select a profile type or enter a custom name',
            style: GoogleFonts.inter(fontSize: 13, color: subtitleColor),
          ),
          const SizedBox(height: 20),
          // Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0x08FFFFFF) : const Color(0xFFF8FAFC),
              border: Border.all(color: borderColor, width: 1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPreset,
                isExpanded: true,
                dropdownColor: isDark ? const Color(0xFF0D1628) : Colors.white,
                style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w600, color: titleColor,
                ),
                items: _presets.map((p) => DropdownMenuItem<String>(
                  value: p['value'],
                  child: Text(
                    p['label']!,
                    style: GoogleFonts.inter(fontSize: 14, color: titleColor),
                  ),
                )).toList(),
                onChanged: (val) {
                  if (val == null) return;
                  final preset = _presets.firstWhere((p) => p['value'] == val);
                  setState(() {
                    _selectedPreset = val;
                    _isCustom = val == '__custom__';
                    _selectedCategory = preset['category']!;
                  });
                },
              ),
            ),
          ),
          if (_isCustom) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _customCtrl,
              autofocus: true,
              style: GoogleFonts.inter(fontSize: 14, color: titleColor),
              decoration: InputDecoration(
                hintText: 'Enter profile name...',
                hintStyle: GoogleFonts.inter(fontSize: 14, color: subtitleColor),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                filled: true,
                fillColor: isDark ? const Color(0x08FFFFFF) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFF5A623), width: 1.5),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      border: Border.all(color: borderColor, width: 1),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Center(
                      child: Text('Cancel',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: subtitleColor)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    final name = _isCustom
                        ? (_customCtrl.text.trim().isEmpty ? 'Naap' : _customCtrl.text.trim())
                        : _selectedPreset;
                    Navigator.pop(context, {
                      'profileName': name,
                      'category': _selectedCategory,
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF5A623), Color(0xFFD97706)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: const [
                        BoxShadow(color: Color(0x33F5A623), blurRadius: 12, offset: Offset(0, 4)),
                      ],
                    ),
                    child: Center(
                      child: Text('Create Profile →',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1A0A00))),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Customer Ledger Tab (کھاتہ) ───────────────────────────────────────────────
class _CustomerLedgerTab extends ConsumerWidget {
  final CustomerModel customer;
  final List<OrderModel> orders;
  const _CustomerLedgerTab({required this.customer, required this.orders});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF5A7090) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF0D1628) : const Color(0xFFFFFFFF);
    final cardBorder = isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8F0);

    // ── Aggregate Totals ──────────────────────────────────────────────
    final totalBusiness = orders.fold(0.0, (s, o) => s + o.totalAmount);
    final totalPaid = orders.fold(0.0, (s, o) => s + o.paidAmount);
    final totalOutstanding = orders.fold(0.0, (s, o) => s + (o.remainingAmount > 0 ? o.remainingAmount : 0));

    // ── Timeline Events ───────────────────────────────────────────────
    final List<Map<String, dynamic>> events = [];
    for (final order in orders) {
      events.add({
        'type': 'order',
        'date': order.orderDate,
        'order': order,
      });
      for (final payment in order.payments) {
        events.add({
          'type': 'payment',
          'date': payment.paidAt,
          'payment': payment,
          'order': order,
        });
      }
    }
    events.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    // ── Unpaid Orders ─────────────────────────────────────────────────
    final unpaidOrders = orders.where((o) => o.remainingAmount > 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Summary Cards Row ──────────────────────────────────────────
        Row(
          children: [
            Expanded(child: _LedgerSummaryCard(
              emoji: '💼',
              label: 'Total Business',
              value: 'Rs. ${totalBusiness.toInt()}',
              color: const Color(0xFF5B72F5),
              isDark: isDark,
            )),
            const SizedBox(width: 8),
            Expanded(child: _LedgerSummaryCard(
              emoji: '✅',
              label: 'Total Paid',
              value: 'Rs. ${totalPaid.toInt()}',
              color: const Color(0xFF10CBA0),
              isDark: isDark,
            )),
            const SizedBox(width: 8),
            Expanded(child: _LedgerSummaryCard(
              emoji: '⏳',
              label: 'Outstanding',
              value: 'Rs. ${totalOutstanding.toInt()}',
              color: totalOutstanding > 0 ? const Color(0xFFFF3A58) : const Color(0xFF10CBA0),
              isDark: isDark,
            )),
          ],
        ),
        const SizedBox(height: 20),

        // ── Add Payment Button ─────────────────────────────────────────
        if (unpaidOrders.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0x1A10CBA0),
              border: Border.all(color: const Color(0x4010CBA0), width: 1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10CBA0), size: 16),
                const SizedBox(width: 8),
                Text('Fully Paid Up ✓ — No Outstanding Balance',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF10CBA0))),
              ],
            ),
          )
        else
          GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              if (unpaidOrders.length == 1) {
                await AddPaymentModal.show(context, order: unpaidOrders.first);
              } else {
                if (!context.mounted) return;
                final chosen = await showModalBottomSheet<OrderModel>(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => _OrderSelectorSheet(unpaidOrders: unpaidOrders, isDark: isDark),
                );
                if (chosen != null && context.mounted) {
                  await AddPaymentModal.show(context, order: chosen);
                }
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10CBA0), Color(0xFF0EA88A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(13),
                boxShadow: const [
                  BoxShadow(color: Color(0x3310CBA0), blurRadius: 12, offset: Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    unpaidOrders.length == 1
                        ? '+ Add Payment  (Rs. ${unpaidOrders.first.remainingAmount.toInt()} due)'
                        : '+ Add Payment  (${unpaidOrders.length} orders unpaid)',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 20),

        // ── Timeline Header ────────────────────────────────────────────
        Text(
          'TIMELINE',
          style: GoogleFonts.inter(
            fontSize: 10, fontWeight: FontWeight.w800,
            color: subtitleColor, letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),

        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('No activity yet.',
                style: GoogleFonts.inter(fontSize: 13, color: subtitleColor)),
            ),
          )
        else
          ...events.map((e) => _LedgerTimelineItem(event: e, isDark: isDark)),

        const SizedBox(height: 20),

        // ── All Orders Table ───────────────────────────────────────────
        Text(
          'ALL ORDERS',
          style: GoogleFonts.inter(
            fontSize: 10, fontWeight: FontWeight.w800,
            color: subtitleColor, letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),

        if (orders.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('No orders yet.',
                style: GoogleFonts.inter(fontSize: 13, color: subtitleColor)),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              border: Border.all(color: cardBorder, width: 1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: orders.asMap().entries.map((entry) {
                final idx = entry.key;
                final order = entry.value;
                final isLast = idx == orders.length - 1;
                return InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/orders/${order.id}');
                  },
                  borderRadius: BorderRadius.only(
                    topLeft: idx == 0 ? const Radius.circular(13) : Radius.zero,
                    topRight: idx == 0 ? const Radius.circular(13) : Radius.zero,
                    bottomLeft: isLast ? const Radius.circular(13) : Radius.zero,
                    bottomRight: isLast ? const Radius.circular(13) : Radius.zero,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: isLast
                          ? null
                          : Border(bottom: BorderSide(color: cardBorder, width: 1)),
                    ),
                    child: Row(
                      children: [
                        // Token
                        SizedBox(
                          width: 52,
                          child: Text(
                            order.tokenNumber.isNotEmpty ? order.tokenNumber : '#${order.orderNumber}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10, fontWeight: FontWeight.w800,
                              color: const Color(0xFFF5A623),
                            ),
                          ),
                        ),
                        // Garment + date
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.itemsSummary.isNotEmpty ? order.itemsSummary : 'Order',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: titleColor),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                DateFormat('dd MMM yy').format(order.orderDate),
                                style: GoogleFonts.inter(fontSize: 10, color: subtitleColor),
                              ),
                            ],
                          ),
                        ),
                        // Paid / Remaining
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Rs. ${order.totalAmount.toInt()}',
                              style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: titleColor),
                            ),
                            if (order.remainingAmount > 0)
                              Text(
                                'Due: ${order.remainingAmount.toInt()}',
                                style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFFF3A58), fontWeight: FontWeight.w600),
                              )
                            else
                              Text(
                                'Paid ✓',
                                style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF10CBA0), fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        StatusPill(status: order.status),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

// ── Ledger Summary Card ───────────────────────────────────────────────────────
class _LedgerSummaryCard extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  const _LedgerSummaryCard({
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? color.withValues(alpha: 0.08) : color.withValues(alpha: 0.06),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12, fontWeight: FontWeight.w900, color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 8, fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.7), letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Ledger Timeline Item ──────────────────────────────────────────────────────
class _LedgerTimelineItem extends StatelessWidget {
  final Map<String, dynamic> event;
  final bool isDark;
  const _LedgerTimelineItem({required this.event, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isOrder = event['type'] == 'order';
    final date = event['date'] as DateTime;
    final titleColor = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF5A7090) : const Color(0xFF64748B);

    final Color dotColor = isOrder ? const Color(0xFF5B72F5) : const Color(0xFF10CBA0);
    final Color bgColor = isOrder
        ? (isDark ? const Color(0x0A5B72F5) : const Color(0xFFEFF6FF))
        : (isDark ? const Color(0x0A10CBA0) : const Color(0xFFECFDF5));
    final Color borderColor = isOrder
        ? (isDark ? const Color(0x205B72F5) : const Color(0xFFBFDBFE))
        : (isDark ? const Color(0x2010CBA0) : const Color(0xFFBBF7D0));

    String title;
    String subtitle;
    String emoji;

    if (isOrder) {
      final order = event['order'] as OrderModel;
      emoji = '📋';
      title = 'New Order — ${order.itemsSummary.isNotEmpty ? order.itemsSummary : 'Order'}';
      subtitle = 'Rs. ${order.totalAmount.toInt()}  ·  ${order.tokenNumber}  ·  ${order.status.label}';
    } else {
      final payment = event['payment'] as PaymentModel;
      final order = event['order'] as OrderModel;
      emoji = '💳';
      title = 'Payment Received — Rs. ${payment.amount.toInt()}';
      subtitle = 'via ${payment.method.name}  ·  Order ${order.tokenNumber}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: dotColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 14))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: titleColor)),
                Text(subtitle, style: GoogleFonts.inter(fontSize: 10, color: subtitleColor)),
              ],
            ),
          ),
          Text(
            DateFormat('dd MMM').format(date),
            style: GoogleFonts.inter(fontSize: 10, color: subtitleColor),
          ),
        ],
      ),
    );
  }
}

// ── Order Selector Sheet (for multi-unpaid case) ──────────────────────────────
class _OrderSelectorSheet extends StatelessWidget {
  final List<OrderModel> unpaidOrders;
  final bool isDark;
  const _OrderSelectorSheet({required this.unpaidOrders, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF0D1628) : const Color(0xFFFFFFFF);
    final borderColor = isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF5A7090) : const Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: borderColor, width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0x30FFFFFF) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Which order is this payment for?',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: titleColor),
          ),
          const SizedBox(height: 4),
          Text(
            'Select the order to apply this payment to.',
            style: GoogleFonts.inter(fontSize: 13, color: subtitleColor),
          ),
          const SizedBox(height: 16),
          ...unpaidOrders.map((order) => GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context, order);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0x08FFFFFF) : const Color(0xFFF8FAFC),
                border: Border.all(color: borderColor, width: 1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.tokenNumber.isNotEmpty ? order.tokenNumber : '#${order.orderNumber}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12, fontWeight: FontWeight.w800,
                            color: const Color(0xFFF5A623),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.itemsSummary.isNotEmpty ? order.itemsSummary : 'Order',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: titleColor),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Due',
                        style: GoogleFonts.inter(fontSize: 10, color: subtitleColor),
                      ),
                      Text(
                        'Rs. ${order.remainingAmount.toInt()}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 15, fontWeight: FontWeight.w900,
                          color: const Color(0xFFFF3A58),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, color: subtitleColor, size: 20),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}
