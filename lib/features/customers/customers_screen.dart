import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_enums.dart';
import '../../core/constants/app_translations.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_providers.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isLoading = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearch(String val) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    setState(() => _isLoading = true);
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        ref.read(customerSearchProvider.notifier).state = val;
        setState(() => _isLoading = false);
      }
    });
  }

  void _onFilter(CustomerGender? gender) {
    setState(() => _isLoading = true);
    ref.read(customerGenderFilterProvider.notifier).state = gender;
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(filteredCustomersProvider);
    final genderFilter = ref.watch(customerGenderFilterProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final t3 = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      floatingActionButton: SizedBox(
        width: 52,
        height: 52,
        child: GoldButton(
          borderRadius: 26,
          onPressed: () {
            HapticFeedback.lightImpact();
            context.push('/customers/add');
          },
          child: const Icon(
            Icons.add_rounded,
            size: 26,
            color: Color(0xFF1A0F00),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.translate('clients'),
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: t1,
                      ),
                    ),
                    Text(
                      customersAsync.when(
                        data: (list) => '${list.length} ${context.translate('clients_found')}',
                        loading: () => context.translate('loading_clients'),
                        error: (_, _) => context.translate('error_loading_clients'),
                      ),
                      style: GoogleFonts.inter(fontSize: 12, color: t2),
                    ),
                  ],
                ),
              ),
              GoldButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.push('/customers/add');
                },
                height: 46,
                borderRadius: 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, size: 18, color: Color(0xFF1A0F00)),
                    const SizedBox(width: 4),
                    Text(
                      context.translate('add_client'),
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
          ),
          const SizedBox(height: 16),

          // Search bar
          _buildSearchContainer(isDark, t1, t3),
          const SizedBox(height: 16),

          // Filter chips (All/Men/Women/Children)
          Row(
            children: [
              _buildFilterChip(
                label: context.translate('all'),
                isActive: genderFilter == null,
                onTap: () => _onFilter(null),
                isDark: isDark,
                text2: t2,
              ),
              _buildFilterChip(
                label: '👔 ${context.translate('men')}',
                isActive: genderFilter == CustomerGender.male,
                onTap: () => _onFilter(CustomerGender.male),
                isDark: isDark,
                text2: t2,
              ),
              _buildFilterChip(
                label: '👗 ${context.translate('women')}',
                isActive: genderFilter == CustomerGender.female,
                onTap: () => _onFilter(CustomerGender.female),
                isDark: isDark,
                text2: t2,
              ),
              _buildFilterChip(
                label: '👕 ${context.translate('child')}',
                isActive: genderFilter == CustomerGender.child,
                onTap: () => _onFilter(CustomerGender.child),
                isDark: isDark,
                text2: t2,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Customer cards
          customersAsync.when(
            data: (list) {
              if (_isLoading) return const ListSkeleton(count: 3);
              if (list.isEmpty) {
                return EmptyState(
                  emoji: '👥',
                  title: context.translate('no_clients'),
                  subtitle: context.translate('no_clients_sub'),
                );
              }
              return Column(
                children: list.map((c) => _ClientCard(customer: c)).toList(),
              );
            },
            loading: () => const ListSkeleton(count: 3),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text('Error: $err', style: const TextStyle(color: AppColors.red)),
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSearchContainer(bool isDark, Color t1, Color t3) {
    return AppTextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      onChanged: _onSearch,
      prefix: Icon(Icons.search_rounded, size: 18, color: t3),
      hint: context.translate('search_placeholder'),
      suffix: _searchController.text.isNotEmpty
          ? GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _searchController.clear();
                _onSearch('');
              },
              child: Icon(Icons.close_rounded, size: 18, color: t3),
            )
          : null,
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required bool isDark,
    required Color text2,
  }) {
    final activeGradient = const LinearGradient(
      colors: [Color(0xFFF5A623), Color(0xFFD4791A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final bg = isDark ? const Color(0x09FFFFFF) : const Color(0xFFFFFFFF);
    final borderCol = isDark ? const Color(0x12FFFFFF) : const Color(0x0D0F172A);

    Widget chipContent = Center(
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: isActive ? const Color(0xFF1A0F00) : text2,
        ),
      ),
    );

    Widget container = Container(
      decoration: BoxDecoration(
        color: isActive ? null : bg,
        gradient: isActive ? activeGradient : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? Colors.transparent : borderCol,
          width: 1,
        ),
        boxShadow: isActive
            ? const [
                BoxShadow(
                  color: Color(0x59F5A623),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                )
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: chipContent,
    );

    if (isDark && !isActive) {
      container = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: container,
        ),
      );
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: container,
        ),
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  final CustomerModel customer;

  const _ClientCard({required this.customer});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final t3 = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    final statusColor = customer.totalOrders == 0
        ? (isDark ? AppColors.accent : AppColors.accentL)
        : AppColors.teal;
    final statusText = customer.totalOrders == 0 ? 'Pending' : 'Active';

    final naapSets = customer.totalOrders == 0 ? 1 : (customer.totalOrders > 5 ? 3 : 2);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: AppCard(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/customers/${customer.id}');
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CustomerAvatar(name: customer.name, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: t1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        customer.phone,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          color: t2,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'ID: ${customer.id.toString().toUpperCase().substring(0, 4)}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.accent : AppColors.accentL,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _timeAgo(customer.createdAt),
                      style: GoogleFonts.inter(fontSize: 11, color: t3),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: border),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${customer.totalOrders} ORDERS',
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: t2,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 14,
                  width: 1,
                  color: border,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$naapSets NAAP SETS',
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: t2,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 14,
                  width: 1,
                  color: border,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        statusText.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                          letterSpacing: 0.6,
                        ),
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

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }
}
