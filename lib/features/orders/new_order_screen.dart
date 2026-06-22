import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_enums.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_providers.dart';

class NewOrderScreen extends ConsumerStatefulWidget {
  const NewOrderScreen({super.key});

  @override
  ConsumerState<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends ConsumerState<NewOrderScreen> {
  int _step = 0;
  CustomerModel? _selectedCustomer;
  final List<Map<String, dynamic>> _items = [];
  DateTime? _deliveryDate;
  final _totalCtrl = TextEditingController();
  final _advanceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Item form
  final _dressTypeCtrl = TextEditingController();
  final _clothCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  int _qty = 1;

  @override
  void dispose() {
    _totalCtrl.dispose();
    _advanceCtrl.dispose();
    _notesCtrl.dispose();
    _dressTypeCtrl.dispose();
    _clothCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final surf = isDark ? AppColors.surfDark : AppColors.surfLight;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_step > 0) {
          setState(() {
            _step--;
          });
        } else if (context.canPop()) {
          context.pop();
        }
      },
      child: Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surf,
        leading: IconButton(
          icon: const Text('←', style: TextStyle(fontSize: 20)),
          onPressed: () => _step == 0 ? context.pop() : setState(() => _step--),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New Order',
              style: GoogleFonts.inter(
                  fontSize: 18, fontWeight: FontWeight.w800, color: t1),
            ),
            Text(
              'Step ${_step + 1} of 3',
              style: GoogleFonts.inter(fontSize: 11, color: t2),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: (_step + 1) / 3,
            backgroundColor: AppColors.accentSS,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
            minHeight: 3,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildStep(),
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _Step1SelectCustomer(
          key: const ValueKey(0),
          selectedCustomer: _selectedCustomer,
          onSelect: (c) => setState(() {
            _selectedCustomer = c;
            _step = 1;
          }),
        );
      case 1:
        return _Step2AddItems(
          key: const ValueKey(1),
          items: _items,
          dressTypeCtrl: _dressTypeCtrl,
          clothCtrl: _clothCtrl,
          priceCtrl: _priceCtrl,
          qty: _qty,
          onQtyChanged: (q) => setState(() => _qty = q),
          onAddItem: () {
            if (_dressTypeCtrl.text.trim().isEmpty) return;
            setState(() {
              _items.add({
                'dressType': _dressTypeCtrl.text.trim(),
                'qty': _qty,
                'cloth': _clothCtrl.text.trim(),
                'price': double.tryParse(_priceCtrl.text) ?? 0,
              });
              _dressTypeCtrl.clear();
              _clothCtrl.clear();
              _priceCtrl.clear();
              _qty = 1;
            });
          },
          onNext: () => setState(() => _step = 2),
        );
      case 2:
        return _Step3PaymentAndDate(
          key: const ValueKey(2),
          deliveryDate: _deliveryDate,
          totalCtrl: _totalCtrl,
          advanceCtrl: _advanceCtrl,
          notesCtrl: _notesCtrl,
          onDatePick: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now().add(const Duration(days: 7)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              builder: (context, child) => Theme(
                data: ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(primary: AppColors.accent),
                ),
                child: child!,
              ),
            );
            if (picked != null) setState(() => _deliveryDate = picked);
          },
          onSave: _saveOrder,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _saveOrder() async {
    if (_selectedCustomer == null) return;
    
    final total = double.tryParse(_totalCtrl.text.replaceAll(',', '')) ?? 0.0;
    final advance = double.tryParse(_advanceCtrl.text.replaceAll(',', '')) ?? 0.0;

    final orderId = const Uuid().v4();

    final orderItems = _items.asMap().entries.map((entry) {
      final item = entry.value;
      return OrderItemModel(
        id: const Uuid().v4(),
        dressType: item['dressType'] as String,
        quantity: item['qty'] as int,
        clothDetails: item['cloth'] as String,
        unitPrice: item['price'] as double,
      );
    }).toList();

    final List<PaymentModel> payments = [];
    if (advance > 0) {
      payments.add(PaymentModel(
        id: const Uuid().v4(),
        amount: advance,
        method: PaymentMethod.cash,
        paidAt: DateTime.now(),
        note: 'Advance',
      ));
    }

    final newOrder = OrderModel(
      id: orderId,
      customerId: _selectedCustomer!.id,
      customerName: _selectedCustomer!.name,
      tokenNumber: '',
      orderNumber: 0,
      orderDate: DateTime.now(),
      deliveryDate: _deliveryDate,
      status: OrderStatus.pending,
      totalAmount: total,
      items: orderItems,
      payments: payments,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    try {
      await ref.read(ordersProvider.notifier).addOrder(newOrder);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Order created successfully!',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            backgroundColor: AppColors.teal,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to save order: $e',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }
}

class _Step1SelectCustomer extends ConsumerStatefulWidget {
  final CustomerModel? selectedCustomer;
  final ValueChanged<CustomerModel> onSelect;

  const _Step1SelectCustomer({
    super.key,
    required this.selectedCustomer,
    required this.onSelect,
  });

  @override
  ConsumerState<_Step1SelectCustomer> createState() => _Step1SelectCustomerState();
}

class _Step1SelectCustomerState extends ConsumerState<_Step1SelectCustomer> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = query.trim().toLowerCase();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '1. Select Client',
          style: GoogleFonts.inter(
              fontSize: 18, fontWeight: FontWeight.w900, color: t1),
        ),
        Text(
          'Who is this order for?',
          style: GoogleFonts.inter(fontSize: 13, color: t2),
        ),
        const SizedBox(height: 20),
        AppTextField(
          hint: 'Search client by name or phone...',
          prefixIcon: '🔍',
          controller: _searchCtrl,
          onChanged: _onSearchChanged,
        ),
        customersAsync.when(
          data: (customers) {
            final filtered = customers.where((c) {
              final nameMatch = c.name.toLowerCase().contains(_searchQuery);
              final phoneMatch = c.phone.toLowerCase().contains(_searchQuery);
              return nameMatch || phoneMatch;
            }).toList();

            if (filtered.isEmpty) {
              return const EmptyState(
                emoji: '🔍',
                title: 'No Matching Clients',
                subtitle: 'Try searching with a different name or phone.',
              );
            }
            return Column(
              children: filtered.map((c) {
                final isSelected = widget.selectedCustomer?.id == c.id;
                final activeBorderColor = isSelected
                    ? (isDark ? AppColors.accent : AppColors.accentL)
                    : (isDark ? AppColors.borderDark : AppColors.borderLight);
                final gradient = isSelected
                    ? (isDark
                        ? [AppColors.accent.withValues(alpha: 0.12), AppColors.accent.withValues(alpha: 0.04)]
                        : [AppColors.accentL.withValues(alpha: 0.08), AppColors.accentL.withValues(alpha: 0.02)])
                    : null;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    onTap: () => widget.onSelect(c),
                    borderColor: activeBorderColor,
                    gradientColors: gradient,
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CustomerAvatar(name: c.name, size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.name,
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: t1)),
                              Text(c.phone,
                                  style: GoogleFonts.jetBrainsMono(
                                      fontSize: 12, color: t2)),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Text('✅', style: TextStyle(fontSize: 20)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const ListSkeleton(count: 3),
          error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.red))),
        ),
      ],
    );
  }
}


class _Step2AddItems extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final TextEditingController dressTypeCtrl;
  final TextEditingController clothCtrl;
  final TextEditingController priceCtrl;
  final int qty;
  final ValueChanged<int> onQtyChanged;
  final VoidCallback onAddItem;
  final VoidCallback onNext;

  const _Step2AddItems({
    super.key,
    required this.items,
    required this.dressTypeCtrl,
    required this.clothCtrl,
    required this.priceCtrl,
    required this.qty,
    required this.onQtyChanged,
    required this.onAddItem,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf2 = isDark ? AppColors.surf2Dark : AppColors.surf2Light;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final t3 = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '2. Add Garment Items',
          style: GoogleFonts.inter(
              fontSize: 18, fontWeight: FontWeight.w900, color: t1),
        ),
        Text(
          'What needs to be stitched?',
          style: GoogleFonts.inter(fontSize: 13, color: t2),
        ),
        const SizedBox(height: 20),

        // Added items
        ...items.map((item) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.tealS,
                border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Text('✅ ', style: TextStyle(fontSize: 14)),
                  Expanded(
                    child: Text(
                      '${item['dressType']} × ${item['qty']}  —  ${item['cloth']}',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.teal),
                    ),
                  ),
                  Text(
                    formatMoney(item['price']),
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.teal),
                  ),
                ],
              ),
            )),

        if (items.isNotEmpty) const SizedBox(height: 12),

        // Add item form
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '+ Add Item',
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w800, color: t1),
              ),
              const SizedBox(height: 14),
              _miniField('DRESS TYPE', '👗', dressTypeCtrl, t1, t2, t3, surf2, border,
                  hint: 'e.g. Sherwani, Shalwar Kameez'),
              _miniField('CLOTH DETAILS', '🧵', clothCtrl, t1, t2, t3, surf2, border,
                  hint: 'Color, fabric, design'),

              // Quantity
              Row(
                children: [
                  Expanded(
                    child: _miniField(
                        'PRICE', '₨', priceCtrl, t1, t2, t3, surf2, border,
                        hint: '0',
                        keyboard: TextInputType.number),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('QTY',
                          style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: t2,
                              letterSpacing: 0.8)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _qtyBtn('-', () => onQtyChanged(qty > 1 ? qty - 1 : 1)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text('$qty',
                                style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: t1)),
                          ),
                          _qtyBtn('+', () => onQtyChanged(qty + 1)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton(
                  onPressed: onAddItem,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF10CBA0),
                    backgroundColor: isDark ? const Color(0x1F10CBA0) : const Color(0xFFCBEFF5),
                    side: BorderSide(color: const Color(0xFF10CBA0).withValues(alpha: 0.3), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    '＋ Add Item',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF10CBA0) : const Color(0xFF056475),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        GoldButton(
          height: 46,
          borderRadius: 16,
          onPressed: items.isEmpty ? null : onNext,
          child: const Text(
            'Next: Payment & Date →',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _qtyBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.accentS,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.accent)),
        ),
      ),
    );
  }

  Widget _miniField(
    String label,
    String icon,
    TextEditingController ctrl,
    Color t1,
    Color t2,
    Color t3,
    Color surf2,
    Color border, {
    String? hint,
    TextInputType? keyboard,
  }) {
    return AppTextField(
      label: label,
      prefixIcon: icon,
      controller: ctrl,
      hint: hint,
      keyboardType: keyboard,
    );
  }
}

class _Step3PaymentAndDate extends StatelessWidget {
  final DateTime? deliveryDate;
  final TextEditingController totalCtrl;
  final TextEditingController advanceCtrl;
  final TextEditingController notesCtrl;
  final VoidCallback onDatePick;
  final VoidCallback onSave;

  const _Step3PaymentAndDate({
    super.key,
    required this.deliveryDate,
    required this.totalCtrl,
    required this.advanceCtrl,
    required this.notesCtrl,
    required this.onDatePick,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf2 = isDark ? AppColors.surf2Dark : AppColors.surf2Light;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final t3 = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '3. Payment & Delivery',
          style: GoogleFonts.inter(
              fontSize: 18, fontWeight: FontWeight.w900, color: t1),
        ),
        Text(
          'Set amount and delivery date',
          style: GoogleFonts.inter(fontSize: 13, color: t2),
        ),
        const SizedBox(height: 20),

        // Delivery date picker
        AppCard(
          onTap: onDatePick,
          padding: const EdgeInsets.all(16),
          borderColor: deliveryDate != null ? (isDark ? AppColors.accent : AppColors.accentL) : border,
          gradientColors: deliveryDate != null
              ? (isDark
                  ? [AppColors.accent.withValues(alpha: 0.12), AppColors.accent.withValues(alpha: 0.04)]
                  : [AppColors.accentL.withValues(alpha: 0.08), AppColors.accentL.withValues(alpha: 0.02)])
              : null,
          child: Row(
            children: [
              const Text('📅', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Text(
                deliveryDate != null
                    ? 'Delivery: ${formatDate(deliveryDate!)}'
                    : 'Tap to select delivery date',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: deliveryDate != null ? t1 : t3,
                  fontWeight: deliveryDate != null
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        AppCard(
          child: Column(
            children: [
              _amtField('TOTAL AMOUNT', '₨', totalCtrl, t1, t2, t3, surf2, border,
                  hint: '0'),
              _amtField('ADVANCE PAID', '₨', advanceCtrl, t1, t2, t3, surf2, border,
                  hint: '0'),
              _amtField('NOTES / INSTRUCTIONS', '📌', notesCtrl, t1, t2, t3,
                  surf2, border,
                  hint: 'Sleeve lamba karna…',
                  maxLines: 3),
            ],
          ),
        ),
        const SizedBox(height: 20),

        GoldButton(
          height: 46,
          borderRadius: 16,
          onPressed: onSave,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('✅  ', style: TextStyle(fontSize: 16)),
              Text(
                'Create Order',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _amtField(
    String label,
    String icon,
    TextEditingController ctrl,
    Color t1,
    Color t2,
    Color t3,
    Color surf2,
    Color border, {
    String? hint,
    int maxLines = 1,
  }) {
    return AppTextField(
      label: label,
      prefixIcon: icon,
      controller: ctrl,
      hint: hint,
      maxLines: maxLines,
    );
  }
}
