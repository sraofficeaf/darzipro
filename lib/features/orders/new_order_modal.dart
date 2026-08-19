import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_enums.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/app_modal.dart';
import '../../core/widgets/modal_footer.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/step_indicator.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_providers.dart';
import '../customers/add_customer_modal.dart';
import '../printing/pdf_builder.dart';
import '../../core/utils/share_helper.dart';

class NewOrderModal extends ConsumerStatefulWidget {
  final CustomerModel? preSelectedCustomer;

  const NewOrderModal({super.key, this.preSelectedCustomer});

  static Future<OrderModel?> show(BuildContext context, {CustomerModel? preSelectedCustomer}) {
    return AppModal(
      title: 'New Order',
      width: 840,
      child: NewOrderModal(preSelectedCustomer: preSelectedCustomer),
    ).show<OrderModel>(context);
  }

  @override
  ConsumerState<NewOrderModal> createState() => _NewOrderModalState();
}

class _NewOrderModalState extends ConsumerState<NewOrderModal> {
  int _currentStep = 1; // 1, 2, 3, 4
  bool _isSaving = false;
  OrderModel? _savedOrder;

  CustomerModel? _selectedCustomer;
  final List<Map<String, dynamic>> _items = [];
  PaymentMethod _paymentMethod = PaymentMethod.cash;

  // Controllers
  final _searchCtrl = TextEditingController();
  final _dressTypeCtrl = TextEditingController();
  final _clothCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _advanceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Dates
  DateTime _orderDate = DateTime.now();
  DateTime? _deliveryDate;

  // Stepper quantity
  int _qty = 1;

  // Search state
  String _searchQuery = '';
  Timer? _debounce;

  // Shake key for validation
  final GlobalKey<ShakeWidgetState> _shakeKey = GlobalKey<ShakeWidgetState>();

  // Error state
  String? _step1Error;
  String? _step2Error;
  String? _step3Error;
  String? _step4Error;

  @override
  void initState() {
    super.initState();
    if (widget.preSelectedCustomer != null) {
      _selectedCustomer = widget.preSelectedCustomer;
      _currentStep = 2;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _dressTypeCtrl.dispose();
    _clothCtrl.dispose();
    _priceCtrl.dispose();
    _advanceCtrl.dispose();
    _notesCtrl.dispose();
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

  double get _itemsTotal {
    double total = 0;
    for (var item in _items) {
      total += (item['price'] as double) * (item['qty'] as int);
    }
    return total;
  }

  double get _advanceAmount {
    return double.tryParse(_advanceCtrl.text.replaceAll(',', '')) ?? 0.0;
  }

  double get _remainingAmount {
    final remaining = _itemsTotal - _advanceAmount;
    return remaining < 0 ? 0 : remaining;
  }

  bool _validateStep1() {
    setState(() => _step1Error = null);
    if (_selectedCustomer == null) {
      setState(() => _step1Error = 'Please select a client to proceed.');
      _shakeKey.currentState?.shake();
      HapticFeedback.vibrate();
      return false;
    }
    return true;
  }

  bool _validateStep2() {
    setState(() => _step2Error = null);
    if (_items.isEmpty) {
      setState(() => _step2Error = 'Please add at least one item to the order.');
      _shakeKey.currentState?.shake();
      HapticFeedback.vibrate();
      return false;
    }
    return true;
  }

  bool _validateStep3() {
    setState(() => _step3Error = null);
    final advance = _advanceAmount;
    final total = _itemsTotal;
    if (advance > total) {
      setState(() => _step3Error = 'Advance payment cannot exceed total amount (₨ ${total.toInt()}).');
      _shakeKey.currentState?.shake();
      HapticFeedback.vibrate();
      return false;
    }
    return true;
  }

  bool _validateStep4() {
    setState(() => _step4Error = null);
    if (_deliveryDate == null) {
      setState(() => _step4Error = 'Please select a delivery date.');
      _shakeKey.currentState?.shake();
      HapticFeedback.vibrate();
      return false;
    }
    // Check if delivery date is after order date
    final orderDay = DateUtils.dateOnly(_orderDate);
    final deliveryDay = DateUtils.dateOnly(_deliveryDate!);
    if (deliveryDay.isBefore(orderDay) || deliveryDay.isAtSameMomentAs(orderDay)) {
      setState(() => _step4Error = 'Delivery date must be after order date.');
      _shakeKey.currentState?.shake();
      HapticFeedback.vibrate();
      return false;
    }
    return true;
  }

  void _nextStep() {
    if (_currentStep == 1) {
      if (_validateStep1()) {
        setState(() => _currentStep = 2);
      }
    } else if (_currentStep == 2) {
      if (_validateStep2()) {
        setState(() => _currentStep = 3);
      }
    } else if (_currentStep == 3) {
      if (_validateStep3()) {
        setState(() => _currentStep = 4);
      }
    } else if (_currentStep == 4) {
      if (_validateStep4()) {
        _saveOrder();
      }
    }
  }

  void _prevStep() {
    if (_currentStep > 1) {
      if (_currentStep == 2 && widget.preSelectedCustomer != null) {
        // If customer was pre-selected, let them go back to step 1
        setState(() => _currentStep = 1);
      } else {
        setState(() => _currentStep--);
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isDelivery) async {
    final initialDate = isDelivery
        ? (_deliveryDate ?? DateTime.now().add(const Duration(days: 7)))
        : _orderDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: isDelivery ? DateTime.now() : DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Color(0xFFF5A623),
                    onPrimary: Color(0xFF1A0A00),
                    surface: Color(0xFF0F1C30),
                    onSurface: Color(0xFFEDF4FF),
                  ),
                  dialogTheme: const DialogThemeData(
                    backgroundColor: Color(0xFF0F1C30),
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFFD97706),
                    surface: Colors.white,
                    onSurface: Color(0xFF0F172A),
                  ),
                ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isDelivery) {
          _deliveryDate = picked;
        } else {
          _orderDate = picked;
        }
      });
    }
  }

  Future<void> _saveOrder() async {
    if (_selectedCustomer == null || _isSaving) return;

    setState(() => _isSaving = true);

    final total = _itemsTotal;
    final advance = _advanceAmount;
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
      String payNotes = 'Advance';
      if (_paymentMethod == PaymentMethod.online) {
        payNotes = 'Advance via Online';
      } else if (_paymentMethod == PaymentMethod.card) {
        payNotes = 'Advance via Card';
      }
      payments.add(PaymentModel(
        id: const Uuid().v4(),
        amount: advance,
        method: _paymentMethod,
        paidAt: DateTime.now(),
        note: payNotes,
      ));
    }

    final newOrder = OrderModel(
      id: orderId,
      customerId: _selectedCustomer!.id,
      customerName: _selectedCustomer!.name,
      tokenNumber: '',
      orderNumber: 0,
      orderDate: _orderDate,
      deliveryDate: _deliveryDate,
      status: OrderStatus.pending,
      totalAmount: total,
      items: orderItems,
      payments: payments,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    try {
      await ref.read(ordersProvider.notifier).addOrder(newOrder);
      final updatedOrders = ref.read(ordersProvider).valueOrNull ?? [];
      final savedOrder = updatedOrders.firstWhere(
        (o) => o.id == orderId,
        orElse: () => newOrder,
      );
      setState(() {
        _isSaving = false;
        _savedOrder = savedOrder;
      });
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Failed to save order: $e',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _sendWhatsApp(OrderModel order, CustomerModel? customer) async {
    try {
      final bytes = await DarziPdfBuilder.buildThermal(order, customer, isUrdu: false);
      final msg = '🧵 *Darzi Pro — Token ${order.tokenNumber}*\n\n'
          'Aapka order ready hone ka waqt:\n'
          '📅 Delivery: ${DateFormat('dd MMM yyyy').format(order.deliveryDate ?? DateTime.now())}\n'
          '💰 Baqi raqam: ₨ ${order.remainingAmount.toInt()}\n\n'
          'Shukriya! 🙏';
      if (mounted) {
        await DarziShareHelper.shareOrSavePdf(
          context,
          pdfBytes: Uint8List.fromList(bytes),
          fileName: 'Order_${order.tokenNumber}.pdf',
          text: msg,
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_savedOrder != null) {
      return _buildSuccessState();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        StepIndicator(
          totalSteps: 4,
          currentStep: _currentStep,
          labels: const ['Client', 'Items', 'Payment', 'Dates & Notes'],
        ),
        const SizedBox(height: 14),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ShakeWidget(
              key: _shakeKey,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: child,
                ),
                child: _buildStepContent(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        ModalFooter(
          currentStep: _currentStep,
          totalSteps: 4,
          onNext: _nextStep,
          onBack: _prevStep,
          nextLabel: _currentStep == 4 ? 'Save Order' : 'Next Step',
          isLoading: _isSaving,
        ),
      ],
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2();
      case 3:
        return _buildStep3();
      case 4:
        return _buildStep4();
      default:
        return const SizedBox.shrink();
    }
  }

  // STEP 1: SELECT CLIENT
  Widget _buildStep1() {
    final customersAsync = ref.watch(customersProvider);

    return Column(
      key: const ValueKey('step_1'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: 'Search Client',
          controller: _searchCtrl,
          hint: 'Search client by name or phone...',
          onChanged: _onSearchChanged,
          prefix: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF2D4060)),
        ),
        const SizedBox(height: 12),
        // Dashed Add New Client Button
        GestureDetector(
          onTap: () async {
            final newCustomer = await AddCustomerModal.show(context);
            if (newCustomer != null) {
              setState(() {
                _selectedCustomer = newCustomer;
                _currentStep = 2;
              });
            }
          },
          child: CustomPaint(
            painter: _DashedBorderPainter(
              color: const Color(0x4D10CBA0),
              strokeWidth: 1.5,
              borderRadius: 10,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0x0A10CBA0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '＋ Add New Client',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF10CBA0),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'CLIENTS LIST',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF5A7090),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        if (_step1Error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_step1Error!, style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
          ),
        customersAsync.when(
          data: (customers) {
            final filtered = customers.where((c) {
              final nameMatch = c.name.toLowerCase().contains(_searchQuery);
              final phoneMatch = c.phone.toLowerCase().contains(_searchQuery);
              return nameMatch || phoneMatch;
            }).toList();

            final displayList = _searchQuery.isEmpty ? filtered.take(10).toList() : filtered;

            if (displayList.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No Clients Found',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF5A7090)),
                  ),
                ),
              );
            }

            return Column(
              children: displayList.map((c) {
                final isSelected = _selectedCustomer?.id == c.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildClientListItem(c, isSelected),
                );
              }).toList(),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF5A623)),
            ),
          ),
          error: (err, _) => Text('Error: $err', style: const TextStyle(color: Colors.redAccent)),
        ),
      ],
    );
  }

  Widget _buildClientListItem(CustomerModel customer, bool isSelected) {
    final bg = isSelected ? const Color(0x0FF5A623) : (context.isDark ? Colors.white.withValues(alpha: 0.04) : context.surface2);
    final border = isSelected ? const Color(0x33F5A623) : (context.isDark ? Colors.white.withValues(alpha: 0.06) : context.border);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedCustomer = customer);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CustomerAvatar(name: customer.name, size: 36, borderRadius: 10),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.text1,
                    ),
                  ),
                  Text(
                    customer.phone,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: context.text2,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF5A623)),
                child: const Icon(Icons.check, size: 12, color: Colors.white),
              )
            else
              Icon(Icons.chevron_right_rounded, size: 20, color: context.isDark ? Colors.white.withValues(alpha: 0.15) : context.border),
          ],
        ),
      ),
    );
  }

  // STEP 2: ADD ITEMS
  Widget _buildStep2() {
    return Column(
      key: const ValueKey('step_2'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected Client Banner
        if (_selectedCustomer != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x0FF5A623),
              border: Border.all(color: const Color(0x33F5A623), width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CustomerAvatar(name: _selectedCustomer!.name, size: 36, borderRadius: 10),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedCustomer!.name,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: context.text1,
                        ),
                      ),
                      Text(
                        _selectedCustomer!.phone,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: context.text2,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _currentStep = 1);
                  },
                  child: Text(
                    'Change',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFF5A623),
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        Text(
          'ADDED ITEMS',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF5A7090),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        if (_step2Error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_step2Error!, style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
          ),
        // List of items
        if (_items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: context.isDark ? Colors.white.withValues(alpha: 0.02) : context.surface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.isDark ? Colors.white.withValues(alpha: 0.04) : context.border),
            ),
            child: Center(
              child: Text(
                'No items added yet.',
                style: GoogleFonts.inter(fontSize: 12, color: context.text3),
              ),
            ),
          )
        else
          Column(
            children: _items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0x0A10CBA0),
                  border: Border.all(color: const Color(0x3310CBA0), width: 1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Text('✅', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item['dressType']} × ${item['qty']}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: context.text1,
                            ),
                          ),
                          if (item['cloth'].toString().isNotEmpty)
                            Text(
                              item['cloth'],
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: context.text2,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '₨ ${(item['price'] * item['qty']).toInt()}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF10CBA0),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _items.removeAt(idx));
                      },
                      child: const Icon(Icons.close_rounded, size: 16, color: Colors.redAccent),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 18),
        // Add Item Form Box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.isDark ? const Color(0x06FFFFFF) : context.surface2,
            border: Border.all(color: context.isDark ? const Color(0x0FFFFFFF) : context.border, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '＋ Add Item',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFF5A623),
                ),
              ),
              const SizedBox(height: 10),
              AppTextField(
                label: 'Dress Type',
                controller: _dressTypeCtrl,
                hint: 'e.g. Sherwani, Shalwar Kameez',
                prefix: const Text('👗', style: TextStyle(fontSize: 14)),
              ),
              const SizedBox(height: 10),
              AppTextField(
                label: 'Cloth Details',
                controller: _clothCtrl,
                hint: 'Color, fabric, design',
                prefix: const Text('🎨', style: TextStyle(fontSize: 14)),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Price (Rs)',
                      controller: _priceCtrl,
                      hint: '0',
                      keyboardType: TextInputType.number,
                      prefix: const Text('💰', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Quantity picker
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QUANTITY',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF5A7090),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _qtyBtn('−', () => setState(() => _qty = _qty > 1 ? _qty - 1 : 1)),
                          Container(
                            constraints: const BoxConstraints(minWidth: 28),
                            alignment: Alignment.center,
                            child: Text(
                              '$_qty',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: context.text1,
                              ),
                            ),
                          ),
                          _qtyBtn('＋', () => setState(() => _qty++)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Teal button
              GestureDetector(
                onTap: () {
                  if (_dressTypeCtrl.text.trim().isEmpty) return;
                  HapticFeedback.lightImpact();
                  setState(() {
                    _items.add({
                      'dressType': _dressTypeCtrl.text.trim(),
                      'cloth': _clothCtrl.text.trim(),
                      'price': double.tryParse(_priceCtrl.text) ?? 0.0,
                      'qty': _qty,
                    });
                    _dressTypeCtrl.clear();
                    _clothCtrl.clear();
                    _priceCtrl.clear();
                    _qty = 1;
                    _step2Error = null;
                  });
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0x1A10CBA0),
                    border: Border.all(color: const Color(0x4010CBA0), width: 1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '＋ Add to Order',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF10CBA0),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _qtyBtn(String symbol, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: context.isDark ? const Color(0x0FFFFFFF) : context.surface2,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            symbol,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: context.text2,
            ),
          ),
        ),
      ),
    );
  }

  // STEP 3: PAYMENT
  Widget _buildStep3() {
    final total = _itemsTotal;
    final advance = _advanceAmount;
    final remaining = _remainingAmount;

    return Column(
      key: const ValueKey('step_3'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Total Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.isDark ? const Color(0xFF0A1428) : context.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.isDark ? Colors.white.withValues(alpha: 0.05) : context.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ORDER TOTAL:',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF5A7090),
                  letterSpacing: 1,
                ),
              ),
              Text(
                '₨ ${total.toInt()}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: context.text1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AppTextField(
          label: 'Advance Payment',
          controller: _advanceCtrl,
          hint: '0',
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          prefix: const Icon(Icons.payments_rounded, size: 16, color: Color(0xFF2D4060)),
        ),
        if (_step3Error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(_step3Error!, style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
          ),
        const SizedBox(height: 18),
        Text(
          'PAYMENT METHOD',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF5A7090),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildPayMethodOption(PaymentMethod.online, '📱', 'Easypaisa'),
            const SizedBox(width: 8),
            _buildPayMethodOption(PaymentMethod.card, '💳', 'JazzCash'),
            const SizedBox(width: 8),
            _buildPayMethodOption(PaymentMethod.cash, '💵', 'Cash'),
          ],
        ),
        const SizedBox(height: 20),
        // Live Summary Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.isDark ? Colors.white.withValues(alpha: 0.02) : context.surface2,
            border: Border.all(color: context.isDark ? Colors.white.withValues(alpha: 0.04) : context.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildSummaryRowItem('Total Amount', '₨ ${total.toInt()}'),
              const SizedBox(height: 6),
              _buildSummaryRowItem('Advance Paid', '₨ ${advance.toInt()}'),
              const Divider(color: Colors.white10, height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Remaining',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: context.text2),
                  ),
                  if (remaining == 0)
                    Text(
                      'Fully Paid ✓',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF10CBA0)),
                    )
                  else
                    Text(
                      '₨ ${remaining.toInt()}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFF5A623),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildSummaryRowItem(String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.text2),
        ),
        Text(
          val,
          style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: context.text1),
        ),
      ],
    );
  }

  Widget _buildPayMethodOption(PaymentMethod method, String iconStr, String label) {
    final isSelected = _paymentMethod == method;
    final bg = isSelected ? const Color(0x14F5A623) : (context.isDark ? Colors.white.withValues(alpha: 0.03) : context.surface2);
    final border = isSelected ? const Color(0xFFF5A623) : (context.isDark ? Colors.white.withValues(alpha: 0.05) : context.border);
    final color = isSelected ? const Color(0xFFF5A623) : context.text2;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _paymentMethod = method);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border, width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(iconStr, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // STEP 4: DATES & NOTES
  Widget _buildStep4() {
    return Column(
      key: const ValueKey('step_4'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_step4Error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_step4Error!, style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
          ),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _selectDate(context, false),
                child: AbsorbPointer(
                  child: AppTextField(
                    label: 'Order Date',
                    controller: TextEditingController(text: DateFormat('dd MMM yyyy').format(_orderDate)),
                    prefix: const Text('📅', style: TextStyle(fontSize: 14)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => _selectDate(context, true),
                child: AbsorbPointer(
                  child: AppTextField(
                    label: 'Delivery Date',
                    controller: TextEditingController(
                        text: _deliveryDate != null ? DateFormat('dd MMM yyyy').format(_deliveryDate!) : 'Select Date'),
                    prefix: const Text('📅', style: TextStyle(fontSize: 14)),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AppTextField(
          label: 'Order Notes (Optional)',
          controller: _notesCtrl,
          hint: 'Sleeve lamba karna, pocket inside...',
          maxLines: 3,
          prefix: const Icon(Icons.notes_rounded, size: 16, color: Color(0xFF2D4060)),
        ),
        const SizedBox(height: 18),
        // Final Summary Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0x0FF5A623),
            border: Border.all(color: const Color(0x26F5A623), width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FINAL DETAILS SUMMARY',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFF5A623),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              _buildSummaryRow('Client', _selectedCustomer?.name ?? ''),
              _buildSummaryRow('Items Count', '${_items.length} item(s)'),
              _buildSummaryRow('Total', '₨ ${_itemsTotal.toInt()}'),
              _buildSummaryRow('Advance Paid', '₨ ${_advanceAmount.toInt()}'),
              _buildSummaryRow('Delivery Date', _deliveryDate != null ? DateFormat('dd MMM yyyy').format(_deliveryDate!) : 'Not set'),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: context.text2),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: context.text1),
            ),
          ),
        ],
      ),
    );
  }

  // SUCCESS STATE
  Widget _buildSuccessState() {
    final order = _savedOrder!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✅', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            'Order Created!',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: context.text1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            order.customerName,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.text2,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0x14F5A623),
              border: Border.all(color: const Color(0x33F5A623), width: 1.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              order.tokenNumber,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFF5A623),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Action Buttons
          _buildActionButton(
            label: '🪪 Print Card',
            gradient: const LinearGradient(colors: [Color(0xFFF5A623), Color(0xFFD97706)]),
            onPressed: () {
              final router = GoRouter.of(context);
              Navigator.pop(context, order);
              router.push('/token-card/${order.id}');
            },
          ),
          const SizedBox(height: 10),
          _buildActionButton(
            label: '💬 WhatsApp',
            gradient: const LinearGradient(colors: [Color(0xFF10CBA0), Color(0xFF059669)]),
            onPressed: () => _sendWhatsApp(order, _selectedCustomer),
          ),
          const SizedBox(height: 10),
          _buildActionButton(
            label: '✕ Close',
            color: context.isDark ? Colors.white.withValues(alpha: 0.06) : context.surface2,
            border: Border.all(color: context.isDark ? Colors.white.withValues(alpha: 0.08) : context.border),
            onPressed: () => Navigator.pop(context, order),
            textColor: context.text2,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    LinearGradient? gradient,
    Color? color,
    BoxBorder? border,
    required VoidCallback onPressed,
    Color textColor = const Color(0xFF1A0A00),
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: gradient,
        color: color,
        border: border,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// Dashed border painter for Add Customer button
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double borderRadius;

  const _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.borderRadius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ));

    final dashPath = Path();
    double distance = 0.0;
    bool draw = true;
    const double dash = 5.0;
    const double gap = 3.0;

    for (final metric in path.computeMetrics()) {
      while (distance < metric.length) {
        final len = draw ? dash : gap;
        if (draw) {
          dashPath.addPath(
            metric.extractPath(distance, distance + len),
            Offset.zero,
          );
        }
        distance += len;
        draw = !draw;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.borderRadius != borderRadius;
}
