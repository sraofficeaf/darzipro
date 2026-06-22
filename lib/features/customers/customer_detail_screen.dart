import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_providers.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final String customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerDetailScreen> createState() =>
      _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  int _activeTab = 0; // 0: Profile, 1: Naap, 2: Orders

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);
    final ordersAsync = ref.watch(ordersProvider);
    final measurementsAsync = ref.watch(measurementsProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final accentCol = isDark ? AppColors.accent : AppColors.accentL;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        }
      },
      child: customersAsync.when(
      loading: () => Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: t1),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: t1),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.red))),
      ),
      data: (customers) {
        CustomerModel? customerNullable;
        try {
          customerNullable = customers.firstWhere((c) => c.id == widget.customerId);
        } catch (_) {}

        if (customerNullable == null) {
          return Scaffold(
            backgroundColor: bg,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: t1),
                onPressed: () => context.pop(),
              ),
            ),
            body: const EmptyState(emoji: '🔍', title: 'Customer Not Found'),
          );
        }
        final customer = customerNullable;

        final orders = ordersAsync.value?.where((o) => o.customerId == widget.customerId).toList() ?? [];
        final measurements = measurementsAsync.value?.where((m) => m.customerId == widget.customerId).toList() ?? [];

        final statusColor = customer.totalOrders == 0
            ? (isDark ? AppColors.accent : AppColors.accentL)
            : AppColors.teal;
        final statusText = customer.totalOrders == 0 ? 'Pending' : 'Active';
        final naapSets = customer.totalOrders == 0 ? 1 : (customer.totalOrders > 5 ? 3 : 2);

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: t1),
              onPressed: () => context.pop(),
            ),
            title: Text(
              'Client Details',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: t1,
              ),
            ),
            centerTitle: true,
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            children: [
              // Hero Section: AppCard with blue gradient bg, centered avatar 76x76 radius 22, animated pulsing ring
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                gradientColors: const [Color(0x26294299), Color(0x154F46E5)],
                child: Column(
                  children: [
                    AnimatedAvatarRing(
                      child: CustomerAvatar(
                        name: customer.name,
                        size: 76,
                        fontSize: 28,
                        borderRadius: 22,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      customer.name,
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: t1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      customer.phone,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: t2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Stats row: 3 AppCard items (Orders, Naap Sets, Status) same KPI style as dashboard
              Row(
                children: [
                  Expanded(
                    child: KpiCard(
                      emoji: '📋',
                      value: '${customer.totalOrders}',
                      label: 'Orders',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: KpiCard(
                      emoji: '📏',
                      value: '$naapSets',
                      label: 'Naap Sets',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: KpiCard(
                      emoji: '⚡',
                      value: statusText,
                      label: 'Status',
                      valueColor: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tabs (Profile/Orders/Naap): AppCard wrapper, active tab bg 0x14FFFFFF border + bottom accent 2.5px gold line
              AppCard(
                padding: const EdgeInsets.all(5),
                child: Row(
                  children: [
                    _buildTabBtn('Profile', 0, isDark, accentCol, t2),
                    _buildTabBtn('Naap', 1, isDark, accentCol, t2),
                    _buildTabBtn('Orders', 2, isDark, accentCol, t2),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Active Tab Content
              if (_activeTab == 0) ...[
                // Profile Info
                _ProfileTabContent(customer: customer),
                const SizedBox(height: 20),
                
                // Edit Profile Button
                GoldButton(
                  height: 46,
                  borderRadius: 16,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                  },
                  child: Text(
                    'EDIT PROFILE',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A0F00),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Delete Customer button
                SizedBox(
                  height: 46,
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
                          title: Text('Delete Customer?', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: t1)),
                          content: Text(
                            'Are you sure you want to delete ${customer.name}? This will also delete all their orders and measurements.',
                            style: GoogleFonts.inter(color: t2),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.inter(
                                  color: t2,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.red,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Delete',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        try {
                          await ref.read(customersProvider.notifier).deleteCustomer(customer.id);
                          if (context.mounted) {
                            context.pop();
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to delete customer: $e')),
                            );
                          }
                        }
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.red,
                      backgroundColor: isDark
                          ? AppColors.red.withValues(alpha: 0.12)
                          : AppColors.red.withValues(alpha: 0.06),
                      side: BorderSide(color: AppColors.red.withValues(alpha: 0.3), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'DELETE CUSTOMER',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.red,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // New Order CTA: full width GoldButton
                GoldButton(
                  height: 46,
                  borderRadius: 16,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    context.push('/orders/new');
                  },
                  child: Text(
                    'NEW ORDER',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: const Color(0xFF1A0F00),
                    ),
                  ),
                ),
              ] else if (_activeTab == 1) ...[
                // Measurements Tab Content
                if (measurements.isEmpty)
                  EmptyState(
                    emoji: '📏',
                    title: 'No Measurements Yet',
                    subtitle: 'Add measurements to track this client\'s naap.',
                    actionLabel: '+ Add Naap',
                    onAction: () {
                      HapticFeedback.lightImpact();
                      context.push('/measurements/${customer.id}/${customer.name}');
                    },
                  )
                else ...[
                  ...measurements.map((m) => _MeasurementCard(
                        measurement: m,
                        customerName: customer.name,
                      )),
                  const SizedBox(height: 16),
                  GoldButton(
                    height: 46,
                    borderRadius: 16,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.push('/measurements/${customer.id}/${customer.name}');
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_rounded, size: 18, color: Color(0xFF1A0F00)),
                        const SizedBox(width: 6),
                        Text(
                          'ADD NAAP CARD',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1A0F00),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ] else ...[
                // Orders Tab Content
                if (orders.isEmpty)
                  EmptyState(
                    emoji: '📋',
                    title: 'No Orders Yet',
                    actionLabel: '+ New Order',
                    onAction: () {
                      HapticFeedback.lightImpact();
                      context.push('/orders/new');
                    },
                  )
                else
                  ...orders.map((o) => _OrderMini(order: o)),
              ],
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    ));
  }

  Widget _buildTabBtn(String label, int index, bool isDark, Color accentColor, Color text2Color) {
    final isActive = _activeTab == index;
    final activeBg = isDark ? const Color(0x14FFFFFF) : const Color(0x0D0F172A);
    final borderCol = isDark ? const Color(0x2EFFFFFF) : const Color(0x240F172A);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _activeTab = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? borderCol : Colors.transparent,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isActive ? accentColor : text2Color,
                ),
              ),
              if (isActive) ...[
                const SizedBox(height: 4),
                Container(
                  width: 20,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5A623),
                    borderRadius: BorderRadius.circular(1.25),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AnimatedAvatarRing extends StatefulWidget {
  final Widget child;

  const AnimatedAvatarRing({super.key, required this.child});

  @override
  State<AnimatedAvatarRing> createState() => _AnimatedAvatarRingState();
}

class _AnimatedAvatarRingState extends State<AnimatedAvatarRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1.0 + _controller.value * 0.15;
        final opacity = 1.0 - _controller.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFF5A623).withValues(alpha: 0.45),
                      width: 2.5,
                    ),
                  ),
                ),
              ),
            ),
            widget.child,
          ],
        );
      },
    );
  }
}

class _ProfileTabContent extends StatelessWidget {
  final CustomerModel customer;

  const _ProfileTabContent({required this.customer});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final dividerCol = isDark ? const Color(0x12FFFFFF) : const Color(0x0D0F172A);

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          _buildInfoRow('Name', customer.name, t1, t2),
          Divider(height: 1, color: dividerCol),
          _buildInfoRow('Phone', customer.phone, t1, t2, isMono: true),
          Divider(height: 1, color: dividerCol),
          _buildInfoRow('Address', customer.address, t1, t2),
          Divider(height: 1, color: dividerCol),
          _buildInfoRow('Gender', customer.gender.label, t1, t2),
          if (customer.notes != null && customer.notes!.isNotEmpty) ...[
            Divider(height: 1, color: dividerCol),
            _buildInfoRow('Notes', customer.notes!, t1, t2),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color t1, Color t2, {bool isMono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: t2,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: isMono
                  ? GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: t1,
                    )
                  : GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: t1,
                    ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

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
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/measurements/${measurement.customerId}/$customerName?category=${measurement.category.name}');
        },
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('📏', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    measurement.title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: t1,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accentS,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      measurement.category.name.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: border),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: measurement.sections
                    .expand((s) => s.fields)
                    .take(6)
                    .map((f) => _MeasField(field: f))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeasField extends StatelessWidget {
  final dynamic field;

  const _MeasField({required this.field});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.label,
          style: GoogleFonts.inter(fontSize: 11, color: t2),
        ),
        Text(
          '${field.value} ${field.unit}',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: t1,
          ),
        ),
      ],
    );
  }
}

class _OrderMini extends StatelessWidget {
  final OrderModel order;

  const _OrderMini({required this.order});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/orders/${order.id}');
        },
        padding: const EdgeInsets.all(14),
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
                      color: AppColors.accent,
                    ),
                  ),
                  Text(
                    order.itemsSummary,
                    style:
                        GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: t1),
                  ),
                  if (order.deliveryDate != null)
                    Text(
                      '📅 ${formatDateShort(order.deliveryDate!)}',
                      style: GoogleFonts.inter(fontSize: 11.5, color: t2),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusPill(status: order.status),
                const SizedBox(height: 6),
                Text(
                  formatMoney(order.totalAmount),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: t1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
