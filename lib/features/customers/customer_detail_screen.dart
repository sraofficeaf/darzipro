import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_providers.dart';
import '../orders/new_order_modal.dart';
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
                      // NAAP TAB
                      if (measurements.isEmpty)
                        _buildEmptyTabState(
                          '📏',
                          'No Measurements Yet',
                          'Add measurements to track this client\'s naap.',
                          '+ Add Naap',
                          () {
                            HapticFeedback.lightImpact();
                            context.push(
                              '/measurements/${customer.id}/${Uri.encodeComponent(customer.name)}',
                            );
                          },
                          isDark: isDark,
                        )
                      else ...[
                        ...measurements.map(
                          (m) => _MeasurementCard(
                            measurement: m,
                            customerName: customer.name,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            context.push(
                              '/measurements/${customer.id}/${Uri.encodeComponent(customer.name)}',
                            );
                          },
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
                                  "ADD NAAP CARD",
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
                    ] else ...[
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

// ── Measurement Card ────────────────────────────────────────────────
class _MeasurementCard extends StatelessWidget {
  final MeasurementModel measurement;
  final String customerName;
  const _MeasurementCard({
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
              '/measurements/${measurement.customerId}/${Uri.encodeComponent(customerName)}?category=${measurement.category.name}',
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('📏', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      measurement.title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0x1AF5A623) : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isDark ? const Color(0x33F5A623) : const Color(0xFFFCD34D), width: 1),
                      ),
                      child: Text(
                        measurement.category.name.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFD97706),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(height: 1, color: isDark ? const Color(0x08FFFFFF) : const Color(0xFFF1F5F9)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: measurement.sections
                      .expand((s) => s.fields)
                      .take(6)
                      .map((f) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                f.label,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: subtitleColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${f.value} ${f.unit}',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: titleColor,
                                ),
                              ),
                            ],
                          ))
                      .toList(),
                ),
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
