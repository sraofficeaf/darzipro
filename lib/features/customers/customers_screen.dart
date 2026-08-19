import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_enums.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_providers.dart';
import 'add_customer_modal.dart';
import 'package:url_launcher/url_launcher.dart';
import '../orders/new_order_modal.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isLoading = false;
  Timer? _debounceTimer;

  late AnimationController _listFadeController;
  late Animation<double> _listFadeAnimation;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() => setState(() {}));
    _listFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _listFadeAnimation = CurvedAnimation(
      parent: _listFadeController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _listFadeController.dispose();
    super.dispose();
  }

  void _onSearch(String val) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    setState(() => _isLoading = true);
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(customerSearchProvider.notifier).state = val;
      if (mounted) setState(() => _isLoading = false);
    });
  }

  void _onFilter(CustomerGender? gender) {
    setState(() => _isLoading = true);
    final current = ref.read(customerGenderFilterProvider);
    ref.read(customerGenderFilterProvider.notifier).state = current == gender
        ? null
        : gender;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  void _triggerListFadeIn() {
    if (!_listFadeController.isAnimating) {
      _listFadeController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(filteredCustomersProvider);
    final genderFilter = ref.watch(customerGenderFilterProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final text1 = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0A0F1C);
    final text3 = isDark ? const Color(0xFF3D5470) : const Color(0xFF94A3B8);
    final accent = isDark ? const Color(0xFFF5A623) : const Color(0xFFD97706);
    final accentBg = isDark ? const Color(0x1AF5A623) : const Color(0xFFFFF8EE);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [Color(0xFF0A1428), Color(0xFF070D1A)]
              : const [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(customersProvider);
          },
          color: accent,
          backgroundColor: isDark ? const Color(0xFF0B1525) : const Color(0xFFFFFFFF),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // ── Header Section ──────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "SHOP CLIENTS",
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: text3,
                          letterSpacing: 1.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Clients",
                        style: GoogleFonts.outfit(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: text1,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: accentBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: accent.withValues(alpha: 0.3), width: 1),
                        ),
                        child: Text(
                          "📋 ${customersAsync.valueOrNull?.length ?? 0} total",
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      AddCustomerModal.show(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent, isDark ? const Color(0xFFD97706) : const Color(0xFFB45309)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isDark
                            ? const [
                                BoxShadow(
                                  color: Color(0x59F5A623),
                                  blurRadius: 20,
                                  offset: Offset(0, 6),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: const Color(0x26D97706),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.add_rounded,
                            color: Color(0xFF1A0A00),
                            size: 16,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            "Add Client",
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
                ],
              ),
              const SizedBox(height: 28),

              // ── Search Bar ──────────────────────────────────────
              _buildSearchBar(),
              const SizedBox(height: 16),

              // ── Filter Chips ────────────────────────────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ModernFilterChip(
                      label: 'All',
                      isActive: genderFilter == null,
                      onTap: () => _onFilter(null),
                    ),
                    const SizedBox(width: 8),
                    _ModernFilterChip(
                      label: '👔 Men',
                      isActive: genderFilter == CustomerGender.male,
                      onTap: () => _onFilter(CustomerGender.male),
                    ),
                    const SizedBox(width: 8),
                    _ModernFilterChip(
                      label: '👗 Women',
                      isActive: genderFilter == CustomerGender.female,
                      onTap: () => _onFilter(CustomerGender.female),
                    ),
                    const SizedBox(width: 8),
                    _ModernFilterChip(
                      label: '👕 Child',
                      isActive: genderFilter == CustomerGender.child,
                      onTap: () => _onFilter(CustomerGender.child),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Client List Content ──────────────────────────────
              customersAsync.when(
                data: (list) {
                  if (_isLoading) return const _ClientListSkeleton(count: 3);
                  if (list.isEmpty) {
                    return _EmptyClientList(
                      onAdd: () => AddCustomerModal.show(context),
                      isDark: isDark,
                    );
                  }
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _triggerListFadeIn(),
                  );
                  return FadeTransition(
                    opacity: _listFadeAnimation,
                    child: Column(
                      children: List.generate(list.length, (index) {
                        return _AnimatedClientCard(
                          index: index,
                          child: _ClientCard(customer: list[index]),
                        );
                      }),
                    ),
                  );
                },
                loading: () => const _ClientListSkeleton(count: 3),
                error: (err, _) => _ClientListError(
                  message: err.toString(),
                  onRetry: () => ref.invalidate(filteredCustomersProvider),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFocused = _searchFocusNode.hasFocus;
    
    final bg = isDark ? const Color(0x0AFFFFFF) : const Color(0xFFFFFFFF);
    final borderCol = isFocused
        ? const Color(0xFFD97706)
        : (isDark ? const Color(0x12FFFFFF) : const Color(0x1A000000));
    final textCol = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0A0F1C);
    final hintCol = isDark ? const Color(0xFF1E3050) : const Color(0xFF94A3B8);
    final prefixCol = isDark ? const Color(0xFF2D4060) : const Color(0xFF94A3B8);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderCol,
          width: 1,
        ),
        boxShadow: isFocused
            ? const [
                BoxShadow(
                  color: Color(0x14D97706),
                  blurRadius: 12,
                  spreadRadius: 1,
                )
              ]
            : (isDark ? null : const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))]),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: prefixCol,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _onSearch,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: textCol,
              ),
              decoration: InputDecoration(
                hintText: "Search by name or phone...",
                hintStyle: GoogleFonts.inter(color: hintCol),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _searchController.clear();
                _onSearch('');
              },
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: prefixCol,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Modern Filter Chip ──────────────────────────────────────────────
class _ModernFilterChip extends StatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ModernFilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_ModernFilterChip> createState() => _ModernFilterChipState();
}

class _ModernFilterChipState extends State<_ModernFilterChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color bg = isDark ? const Color(0x08FFFFFF) : const Color(0xFFFFFFFF);
    Color border = isDark ? const Color(0x12FFFFFF) : const Color(0x1A000000);
    Color color = isDark ? const Color(0xFF5A7090) : const Color(0xFF4A5568);
    FontWeight weight = FontWeight.w600;

    if (widget.isActive) {
      bg = isDark ? const Color(0x1AF5A623) : const Color(0xFFFFF8EE);
      border = isDark ? const Color(0x59F5A623) : const Color(0xFFD97706).withValues(alpha: 0.3);
      color = isDark ? const Color(0xFFF5A623) : const Color(0xFFD97706);
      weight = FontWeight.w700;
    } else if (_isHovered) {
      border = isDark ? const Color(0x4DF5A623) : const Color(0xFFD97706).withValues(alpha: 0.2);
      color = isDark ? const Color(0xFF8AA0B8) : const Color(0xFF0A0F1C);
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
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: 1),
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: weight,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Client Card with Hover Animation ────────────────────────────────
class _ClientCard extends ConsumerStatefulWidget {
  final CustomerModel customer;
  const _ClientCard({required this.customer});

  @override
  ConsumerState<_ClientCard> createState() => _ClientCardState();
}

class _ClientCardState extends ConsumerState<_ClientCard> {
  bool _isHovered = false;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  Widget _buildWhatsAppIcon(double size, Color bubbleColor) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.chat_bubble_rounded, size: size, color: Colors.white),
          Positioned(
            left: size * 0.05,
            top: size * 0.02,
            child: Transform.rotate(
              angle: 0.4,
              child: Icon(
                Icons.phone_rounded,
                size: size * 0.55,
                color: bubbleColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    IconData? icon,
    Widget? customIcon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: isDark ? 0.1 : 0.08),
            border: Border.all(color: color.withValues(alpha: isDark ? 0.2 : 0.15)),
          ),
          alignment: Alignment.center,
          child: customIcon ?? Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final naapSets = widget.customer.totalOrders == 0
        ? 1
        : (widget.customer.totalOrders > 5 ? 3 : 2);

    final statusText = widget.customer.totalOrders == 0 ? 'New' : 'Active';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark 
        ? (_isHovered ? const Color(0x12FFFFFF) : const Color(0x09FFFFFF)) 
        : const Color(0xFFFFFFFF);
    final border = isDark 
        ? (_isHovered ? const Color(0x33FFFFFF) : const Color(0x12FFFFFF)) 
        : (_isHovered ? const Color(0xFFD97706).withValues(alpha: 0.2) : const Color(0x1A000000));
    final textCol = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0A0F1C);
    final subTextCol = isDark ? const Color(0xFF4A6080) : const Color(0xFF4A5568);
    final List<BoxShadow> shadow = isDark
        ? const <BoxShadow>[]
        : [
            BoxShadow(
              color: const Color(0x0A000000),
              blurRadius: _isHovered ? 12 : 6,
              offset: const Offset(0, 2),
            )
          ];

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/customers/${widget.customer.id}');
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(_isHovered ? 3.0 : 0.0, 0, 0),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: border,
              width: 1,
            ),
            boxShadow: shadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                // Left accent bar
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 3,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _isHovered ? 1.0 : 0.0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark 
                              ? const [Color(0xFFF5A623), Color(0xFFD97706)]
                              : const [Color(0xFFD97706), Color(0xFFD97706)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: isDark
                              ? const [
                                  BoxShadow(
                                    color: Color(0x4D000000),
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ]
                              : const [],
                        ),
                        child: CustomerAvatar(
                          name: widget.customer.name,
                          size: 48,
                          borderRadius: 14,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.customer.name,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: textCol,
                                letterSpacing: 0.1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.customer.phone,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                color: subTextCol,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Tags row
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _buildTag(
                                  label: _timeAgo(widget.customer.createdAt),
                                  bg: isDark ? const Color(0x1A5B72F5) : const Color(0xFFEFF6FF),
                                  color: isDark ? const Color(0xFF5B72F5) : const Color(0xFF2563EB),
                                  border: isDark 
                                      ? const Color(0x335B72F5) 
                                      : const Color(0xFF2563EB).withValues(alpha: 0.3),
                                ),
                                _buildTag(
                                  label: '$naapSets Naap Set${naapSets == 1 ? '' : 's'}',
                                  bg: isDark ? const Color(0x1A10CBA0) : const Color(0xFFECFDF5),
                                  color: isDark ? const Color(0xFF10CBA0) : const Color(0xFF059669),
                                  border: isDark 
                                      ? const Color(0x3310CBA0) 
                                      : const Color(0xFF059669).withValues(alpha: 0.3),
                                ),
                                _buildTag(
                                  label: statusText,
                                  bg: statusText == 'New'
                                      ? (isDark ? const Color(0x1AF5A623) : const Color(0xFFFFF8EE))
                                      : (isDark ? const Color(0x1A10CBA0) : const Color(0xFFECFDF5)),
                                  color: statusText == 'New'
                                      ? (isDark ? const Color(0xFFF5A623) : const Color(0xFFD97706))
                                      : (isDark ? const Color(0xFF10CBA0) : const Color(0xFF059669)),
                                  border: statusText == 'New'
                                      ? (isDark ? const Color(0x33F5A623) : const Color(0xFFD97706).withValues(alpha: 0.3))
                                      : (isDark ? const Color(0x3310CBA0) : const Color(0xFF059669).withValues(alpha: 0.3)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildActionButton(
                            customIcon: _buildWhatsAppIcon(22, const Color(0xFF25D366)),
                            tooltip: 'WhatsApp',
                            color: const Color(0xFF25D366),
                            onTap: () async {
                              var phone = widget.customer.phone.replaceAll(RegExp(r'\D'), '');
                              if (phone.startsWith('0')) {
                                phone = '92${phone.substring(1)}';
                              }
                              final uri = Uri.parse('https://wa.me/$phone');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildActionButton(
                            icon: Icons.straighten_rounded,
                            tooltip: 'Naap (Measurements)',
                            color: const Color(0xFF9B5CF5),
                            onTap: () {
                              ref.read(selectedMeasurementCustomerIdProvider.notifier).state = widget.customer.id;
                              context.go('/measurements/${widget.customer.id}/${Uri.encodeComponent(widget.customer.name)}');
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildActionButton(
                            icon: Icons.add_circle_outline_rounded,
                            tooltip: 'New Order',
                            color: const Color(0xFFF5A623),
                            onTap: () {
                              NewOrderModal.show(context, preSelectedCustomer: widget.customer);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // Chevron
                      Icon(
                        Icons.chevron_right_rounded,
                        color: isDark ? const Color(0xFF1E3050) : const Color(0xFF94A3B8),
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTag({
    required String label,
    required Color bg,
    required Color color,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 1),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Animated Wrapper for cards ──────────────────────────────────────
class _AnimatedClientCard extends StatefulWidget {
  final int index;
  final Widget child;
  const _AnimatedClientCard({required this.index, required this.child});

  @override
  _AnimatedClientCardState createState() => _AnimatedClientCardState();
}

class _AnimatedClientCardState extends State<_AnimatedClientCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6)),
    );

    Future.delayed(Duration(milliseconds: 50 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offsetAnimation,
      child: FadeTransition(opacity: _opacityAnimation, child: widget.child),
    );
  }
}

// ── Empty State Widget ──────────────────────────────────────────────
class _EmptyClientList extends StatelessWidget {
  final VoidCallback onAdd;
  final bool isDark;
  const _EmptyClientList({required this.onAdd, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '👥',
              style: TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 16),
            Text(
              'No clients yet',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFEDF4FF) : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first client to start managing orders',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF4A6080),
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onAdd();
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
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x59F5A623),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.add_rounded,
                      color: Color(0xFF1A0A00),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Add Client',
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
          ],
        ),
      ),
    );
  }
}

// ── Skeleton Loader ──────────────────────────────────────────────────
class _ClientListSkeleton extends StatelessWidget {
  final int count;
  const _ClientListSkeleton({required this.count});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (index) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0x05FFFFFF),
            border: Border.all(color: const Color(0x12FFFFFF), width: 1),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              _ShimmerBox(
                width: 48,
                height: 48,
                borderRadius: 14,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerBox(width: 120, height: 14),
                    const SizedBox(height: 6),
                    _ShimmerBox(width: 80, height: 11),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _ShimmerBox(width: 50, height: 16, borderRadius: 6),
                        const SizedBox(width: 6),
                        _ShimmerBox(width: 70, height: 16, borderRadius: 6),
                      ],
                    )
                  ],
                ),
              ),
              const _ShimmerBox(width: 16, height: 16, borderRadius: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  const _ShimmerBox({
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const baseColor = Colors.white10;
    const highlightColor = Colors.white24;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          gradient: LinearGradient(
            colors: const [baseColor, highlightColor, baseColor],
            stops: const [0.0, 0.5, 1.0],
            begin: Alignment(-2.0 + _controller.value * 4.0, -0.3),
            end: Alignment(-1.0 + _controller.value * 4.0, 0.3),
          ),
        ),
      ),
    );
  }
}

// ── Error State Widget ──────────────────────────────────────────────
class _ClientListError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ClientListError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0x0AFFFFFF),
            border: Border.all(color: const Color(0x12FFFFFF), width: 1),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 48,
                color: Color(0xFF3D5470),
              ),
              const SizedBox(height: 16),
              Text(
                'Could not load clients',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFEDF4FF),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message.replaceAll('Exception: ', ''),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF4A6080),
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
    );
  }
}
