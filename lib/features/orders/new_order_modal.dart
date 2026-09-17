import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_enums.dart';
import '../../core/widgets/app_modal.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_providers.dart';
import '../customers/add_customer_modal.dart';
import '../printing/pdf_builder.dart';
import '../../core/utils/share_helper.dart';

// ── COLOR CONSTANTS (CACHED) ────────────────────────────────────────────────
class _ModalColors {
  static const ink = Color(0xFF111827);
  static const muted = Color(0xFF7B8494);
  static const faint = Color(0xFFAAB2BF);
  static const line = Color(0xFFE8EAF0);
  static const paper = Color(0xFFF5F6F8);

  static const dark = Color(0xFF151922);
  static const darkCard = Color(0xFF181D27);
  static const darkLine = Color(0xFF333946);

  static const gold = Color(0xFFE9A227);
  static const gold2 = Color(0xFFFFC65A);
  static const goldBg = Color(0xFFFFF6E5);
  static const goldLine = Color(0xFFF3DDA8);

  static const green = Color(0xFF18B887);
  static const greenBg = Color(0xFFEAFBF5);
  static const greenLine = Color(0xFFCFEFE3);

  static const rose = Color(0xFFEF5261);
  static const roseBg = Color(0xFFFFF0F2);
}

// ── TYPOGRAPHY CONSTANTS (CACHED) ───────────────────────────────────────────
class _ModalStyles {

  static final stepTitle = GoogleFonts.manrope(
    fontSize: 11,
    fontWeight: FontWeight.w800,
  );

  static final stepNum = GoogleFonts.manrope(
    fontSize: 11,
    fontWeight: FontWeight.w800,
  );

  static final fieldLabel = GoogleFonts.dmSans(
    fontSize: 10,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.7,
    color: _ModalColors.muted,
  );

  static final summaryTitle = GoogleFonts.dmSans(
    fontSize: 10,
    fontWeight: FontWeight.w900,
    color: const Color(0xFF8B6C22),
    letterSpacing: 1.2,
  );

  static final summaryKey = GoogleFonts.dmSans(
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
    color: const Color(0xFF8B6C22),
  );

  static final summaryVal = GoogleFonts.ibmPlexMono(
    fontSize: 12,
    fontWeight: FontWeight.w800,
  );
}

// ── NEW ORDER MODAL ─────────────────────────────────────────────────────────
class NewOrderModal extends ConsumerStatefulWidget {
  final CustomerModel? preSelectedCustomer;

  const NewOrderModal({super.key, this.preSelectedCustomer});

  static Future<OrderModel?> show(BuildContext context, {CustomerModel? preSelectedCustomer}) {
    return AppModal(
      title: 'New Order',
      width: 800,
      child: NewOrderModal(preSelectedCustomer: preSelectedCustomer),
    ).show<OrderModel>(context);
  }

  @override
  ConsumerState<NewOrderModal> createState() => _NewOrderModalState();
}

class _NewOrderModalState extends ConsumerState<NewOrderModal> {
  int _currentStep = 1; // 1: Client, 2: Items, 3: Payment, 4: Dates
  bool _isSaving = false;
  OrderModel? _savedOrder;

  CustomerModel? _selectedCustomer;
  final List<Map<String, dynamic>> _items = [];
  PaymentMethod _paymentMethod = PaymentMethod.cash;

  // Form Controllers
  final _searchCtrl = TextEditingController();
  final _dressTypeCtrl = TextEditingController();
  final _clothCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _advanceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Dates
  DateTime _orderDate = DateTime.now();
  DateTime? _deliveryDate;

  // Quantity for item being added
  int _qty = 1;

  // Selected measurement profile
  String? _selectedMeasurementProfileId;

  // Search state & debounce
  String _searchQuery = '';
  Timer? _debounceTimer;

  // Validation errors
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
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    _dressTypeCtrl.dispose();
    _clothCtrl.dispose();
    _priceCtrl.dispose();
    _advanceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() => _searchQuery = val.trim().toLowerCase());
      }
    });
  }

  double get _itemsTotal {
    double total = 0;
    for (final it in _items) {
      total += (it['price'] as double) * (it['qty'] as int);
    }
    return total;
  }

  double get _advanceAmount {
    return double.tryParse(_advanceCtrl.text.replaceAll(',', '')) ?? 0.0;
  }

  double get _remainingAmount {
    final rem = _itemsTotal - _advanceAmount;
    return rem < 0 ? 0 : rem;
  }

  bool _validateStep1() {
    setState(() => _step1Error = null);
    if (_selectedCustomer == null) {
      setState(() => _step1Error = 'Please select a client to proceed.');
      HapticFeedback.vibrate();
      return false;
    }
    return true;
  }

  bool _validateStep2() {
    setState(() => _step2Error = null);
    if (_items.isEmpty) {
      setState(() => _step2Error = 'Please add at least one item to proceed.');
      HapticFeedback.vibrate();
      return false;
    }
    return true;
  }

  bool _validateStep3() {
    setState(() => _step3Error = null);
    if (_advanceAmount > _itemsTotal) {
      setState(() => _step3Error = 'Advance cannot exceed total amount.');
      HapticFeedback.vibrate();
      return false;
    }
    return true;
  }

  bool _validateStep4() {
    setState(() => _step4Error = null);
    if (_deliveryDate == null) {
      setState(() => _step4Error = 'Please select a delivery date.');
      HapticFeedback.vibrate();
      return false;
    }
    return true;
  }

  void _nextStep() {
    if (_currentStep == 1) {
      if (_validateStep1()) setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      if (_validateStep2()) setState(() => _currentStep = 3);
    } else if (_currentStep == 3) {
      if (_validateStep3()) setState(() => _currentStep = 4);
    } else if (_currentStep == 4) {
      if (_validateStep4()) _saveOrder();
    }
  }

  void _prevStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _selectDate(BuildContext context, bool isDelivery) async {
    final initial = isDelivery
        ? (_deliveryDate ?? DateTime.now().add(const Duration(days: 7)))
        : _orderDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: isDelivery ? DateTime.now() : DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: _ModalColors.gold,
                    onPrimary: Color(0xFF211500),
                    surface: _ModalColors.darkCard,
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: _ModalColors.gold,
                    surface: Colors.white,
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

    final orderItems = _items.map((it) {
      return OrderItemModel(
        id: const Uuid().v4(),
        dressType: it['dressType'] as String,
        quantity: it['qty'] as int,
        clothDetails: it['cloth'] as String,
        unitPrice: it['price'] as double,
        measurementProfileId: it['measurementProfileId'] as String?,
      );
    }).toList();

    final List<PaymentModel> payments = [];
    if (advance > 0) {
      payments.add(PaymentModel(
        id: const Uuid().v4(),
        amount: advance,
        method: _paymentMethod,
        paidAt: DateTime.now(),
        note: 'Advance via ${_paymentMethod.name}',
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
      final saved = updatedOrders.firstWhere(
        (o) => o.id == orderId,
        orElse: () => newOrder,
      );
      if (mounted) {
        setState(() {
          _isSaving = false;
          _savedOrder = saved;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save order: $e'), backgroundColor: _ModalColors.rose),
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
          '💰 Baqi raqam: Rs ${order.remainingAmount.toInt()}\n\n'
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. STEPPER BAR (MATCHING MOCKUP)
        _buildStepper(isDark),

        // 2. STEP CONTENT (SCROLLABLE & LIGHTWEIGHT)
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
            child: _buildStepContent(isDark),
          ),
        ),

        // 3. MODAL FOOTER ACTIONS
        _buildFooter(isDark),
      ],
    );
  }

  // ── STEPPER BAR ───────────────────────────────────────────────────────────
  Widget _buildStepper(bool isDark) {
    final steps = ['Client', 'Items', 'Payment', 'Dates'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? _ModalColors.darkCard : const Color(0xFFFAFAFB),
        border: Border(
          bottom: BorderSide(
            color: isDark ? _ModalColors.darkLine : _ModalColors.line,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            final stepIdx = (index ~/ 2) + 1;
            final isDone = stepIdx < _currentStep;
            return Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: isDone
                      ? _ModalColors.green
                      : (isDark ? _ModalColors.darkLine : _ModalColors.line),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            );
          }

          final stepNum = (index ~/ 2) + 1;
          final isDone = stepNum < _currentStep;
          final isActive = stepNum == _currentStep;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isDone
                      ? _ModalColors.green
                      : (isActive
                          ? (isDark ? _ModalColors.gold : _ModalColors.dark)
                          : (isDark ? _ModalColors.darkCard : Colors.white)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDone
                        ? _ModalColors.green
                        : (isActive
                            ? Colors.transparent
                            : (isDark ? _ModalColors.darkLine : _ModalColors.line)),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    isDone ? '✓' : '$stepNum',
                    style: _ModalStyles.stepNum.copyWith(
                      color: isDone || isActive
                          ? (isActive && isDark ? const Color(0xFF211500) : Colors.white)
                          : _ModalColors.muted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                steps[stepNum - 1],
                style: _ModalStyles.stepTitle.copyWith(
                  color: isActive || isDone
                      ? (isDark ? Colors.white : _ModalColors.ink)
                      : _ModalColors.muted,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ── STEP CONTENT ROUTER ───────────────────────────────────────────────────
  Widget _buildStepContent(bool isDark) {
    switch (_currentStep) {
      case 1:
        return _buildStep1(isDark);
      case 2:
        return _buildStep2(isDark);
      case 3:
        return _buildStep3(isDark);
      case 4:
        return _buildStep4(isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  // ── STEP 1: CLIENT SELECTION ──────────────────────────────────────────────
  Widget _buildStep1(bool isDark) {
    final customersAsync = ref.watch(customersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_step1Error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _step1Error!,
              style: const TextStyle(color: _ModalColors.rose, fontSize: 11),
            ),
          ),

        // Search Field
        Text('SEARCH CLIENT', style: _ModalStyles.fieldLabel),
        const SizedBox(height: 6),
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: isDark ? _ModalColors.darkCard : const Color(0xFFFAFAFB),
            border: Border.all(
              color: isDark ? _ModalColors.darkLine : _ModalColors.line,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, size: 18, color: _ModalColors.muted),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: isDark ? Colors.white : _ModalColors.ink,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by name or phone...',
                    hintStyle: GoogleFonts.dmSans(fontSize: 13, color: _ModalColors.faint),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Add Customer Link
        InkWell(
          onTap: () async {
            final newCust = await AddCustomerModal.show(context);
            if (newCust != null) {
              setState(() {
                _selectedCustomer = newCust;
                _currentStep = 2;
              });
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isDark ? const Color(0x14E9A227) : _ModalColors.goldBg,
              border: Border.all(color: _ModalColors.goldLine, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('＋', style: TextStyle(fontSize: 15, color: _ModalColors.gold)),
                const SizedBox(width: 6),
                Text(
                  'Add New Client',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Text('CLIENTS LIST', style: _ModalStyles.fieldLabel),
        const SizedBox(height: 6),

        // Virtualized Client Picker
        customersAsync.when(
          data: (allCustomers) {
            final filtered = _searchQuery.isEmpty
                ? allCustomers
                : allCustomers.where((c) {
                    final q = _searchQuery;
                    return c.name.toLowerCase().contains(q) || c.phone.contains(q);
                  }).toList();

            if (filtered.isEmpty) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 30),
                alignment: Alignment.center,
                child: Text(
                  'No clients found',
                  style: GoogleFonts.dmSans(fontSize: 12, color: _ModalColors.muted),
                ),
              );
            }

            return SizedBox(
              height: 250,
              child: ListView.builder(
                itemCount: filtered.length,
                cacheExtent: 200,
                itemBuilder: (context, index) {
                  final c = filtered[index];
                  final isSelected = _selectedCustomer?.id == c.id;

                  return RepaintBoundary(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: isSelected
                            ? (isDark ? const Color(0x28E9A227) : _ModalColors.goldBg)
                            : (isDark ? _ModalColors.darkCard : const Color(0xFFFAFAFB)),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _selectedCustomer = c);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isSelected
                                    ? _ModalColors.gold
                                    : (isDark ? _ModalColors.darkLine : _ModalColors.line),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                // Avatar Initial
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [_ModalColors.gold2, Color(0xFFD88A13)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                                      style: GoogleFonts.manrope(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.name,
                                        style: GoogleFonts.manrope(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white : _ModalColors.ink,
                                        ),
                                      ),
                                      Text(
                                        c.phone,
                                        style: GoogleFonts.ibmPlexMono(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: _ModalColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Checkmark
                                if (isSelected)
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _ModalColors.gold,
                                    ),
                                    child: const Icon(Icons.check, size: 13, color: Colors.white),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(strokeWidth: 2, color: _ModalColors.gold),
            ),
          ),
          error: (err, _) => Text('Error: $err', style: const TextStyle(color: _ModalColors.rose)),
        ),
      ],
    );
  }

  // ── STEP 2: ITEMS SELECTION ───────────────────────────────────────────────
  Widget _buildStep2(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_step2Error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _step2Error!,
              style: const TextStyle(color: _ModalColors.rose, fontSize: 11),
            ),
          ),

        // Added Items List
        Text('ADDED ITEMS', style: _ModalStyles.fieldLabel),
        const SizedBox(height: 6),
        if (_items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: isDark ? _ModalColors.darkCard : const Color(0xFFFAFAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? _ModalColors.darkLine : _ModalColors.line,
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                'No items added yet.',
                style: GoogleFonts.dmSans(fontSize: 12, color: _ModalColors.muted),
              ),
            ),
          )
        else
          Column(
            children: _items.asMap().entries.map((entry) {
              final idx = entry.key;
              final it = entry.value;
              final lineTotal = (it['price'] as double) * (it['qty'] as int);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0x1418B887) : _ModalColors.greenBg,
                  border: Border.all(
                    color: isDark ? const Color(0x3318B887) : _ModalColors.greenLine,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Text('✅', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${it['dressType']} × ${it['qty']}',
                            style: GoogleFonts.manrope(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : _ModalColors.ink,
                            ),
                          ),
                          if (it['cloth'].toString().isNotEmpty)
                            Text(
                              it['cloth'].toString(),
                              style: GoogleFonts.dmSans(
                                fontSize: 10.5,
                                color: _ModalColors.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      'Rs ${lineTotal.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _ModalColors.green,
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _items.removeAt(idx));
                      },
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _ModalColors.roseBg,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Center(
                          child: Text('✕', style: TextStyle(fontSize: 11, color: _ModalColors.rose)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 16),

        // Add Item Form Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? _ModalColors.darkCard : const Color(0xFFFAFAFB),
            border: Border.all(
              color: isDark ? _ModalColors.darkLine : _ModalColors.line,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '＋ ADD ITEM',
                style: GoogleFonts.dmSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: _ModalColors.gold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),

              // Dress Type
              Text('DRESS TYPE', style: _ModalStyles.fieldLabel),
              const SizedBox(height: 5),
              _buildTextInput(
                controller: _dressTypeCtrl,
                hint: 'e.g. Shalwar Kameez, Sherwani',
                prefixIcon: const Text('👗', style: TextStyle(fontSize: 14)),
                isDark: isDark,
              ),
              const SizedBox(height: 10),

              // Cloth Details
              Text('CLOTH DETAILS', style: _ModalStyles.fieldLabel),
              const SizedBox(height: 5),
              _buildTextInput(
                controller: _clothCtrl,
                hint: 'Color, fabric, design',
                prefixIcon: const Text('🎨', style: TextStyle(fontSize: 14)),
                isDark: isDark,
              ),
              const SizedBox(height: 10),

              // Measurement Profile Picker
              if (_selectedCustomer != null) _buildMeasurementPicker(isDark),

              // Price & Quantity Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PRICE (RS)', style: _ModalStyles.fieldLabel),
                        const SizedBox(height: 5),
                        _buildTextInput(
                          controller: _priceCtrl,
                          hint: '0',
                          keyboardType: TextInputType.number,
                          prefixIcon: const Text('💰', style: TextStyle(fontSize: 14)),
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('QUANTITY', style: _ModalStyles.fieldLabel),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          _qtyButton('−', () {
                            if (_qty > 1) setState(() => _qty--);
                          }, isDark),
                          Container(
                            constraints: const BoxConstraints(minWidth: 32),
                            alignment: Alignment.center,
                            child: Text(
                              '$_qty',
                              style: GoogleFonts.ibmPlexMono(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : _ModalColors.ink,
                              ),
                            ),
                          ),
                          _qtyButton('＋', () => setState(() => _qty++), isDark),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Add to Order Button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0x2418B887) : _ModalColors.greenBg,
                  border: Border.all(color: _ModalColors.green, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      final dress = _dressTypeCtrl.text.trim();
                      if (dress.isEmpty) return;
                      HapticFeedback.lightImpact();
                      setState(() {
                        _items.add({
                          'dressType': dress,
                          'cloth': _clothCtrl.text.trim(),
                          'price': double.tryParse(_priceCtrl.text) ?? 0.0,
                          'qty': _qty,
                          'measurementProfileId': _selectedMeasurementProfileId,
                        });
                        _dressTypeCtrl.clear();
                        _clothCtrl.clear();
                        _priceCtrl.clear();
                        _qty = 1;
                        _selectedMeasurementProfileId = null;
                        _step2Error = null;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Center(
                        child: Text(
                          '＋ Add to Order',
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: _ModalColors.green,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMeasurementPicker(bool isDark) {
    final allMeasurements = ref.watch(customerMeasurementsProvider).valueOrNull ?? [];
    final profiles =
        allMeasurements.where((m) => m.customerId == _selectedCustomer?.id).toList();

    if (profiles.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MEASUREMENT PROFILE (OPTIONAL)', style: _ModalStyles.fieldLabel),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? _ModalColors.darkCard : Colors.white,
              border: Border.all(
                color: isDark ? _ModalColors.darkLine : _ModalColors.line,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedMeasurementProfileId,
                isExpanded: true,
                dropdownColor: isDark ? _ModalColors.darkCard : Colors.white,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: isDark ? Colors.white : _ModalColors.ink,
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('None — no profile linked'),
                  ),
                  ...profiles.map((p) => DropdownMenuItem<String?>(
                        value: p.id,
                        child: Text('📏 ${p.profileName}'),
                      )),
                ],
                onChanged: (val) => setState(() => _selectedMeasurementProfileId = val),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyButton(String label, VoidCallback onTap, bool isDark) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isDark ? _ModalColors.darkCard : Colors.white,
        border: Border.all(
          color: isDark ? _ModalColors.darkLine : _ModalColors.line,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : _ModalColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── STEP 3: PAYMENT ───────────────────────────────────────────────────────
  Widget _buildStep3(bool isDark) {
    final total = _itemsTotal;
    final advance = _advanceAmount;
    final remaining = _remainingAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_step3Error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _step3Error!,
              style: const TextStyle(color: _ModalColors.rose, fontSize: 11),
            ),
          ),

        // Total Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? _ModalColors.darkCard : _ModalColors.paper,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? _ModalColors.darkLine : _ModalColors.line,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ORDER TOTAL:',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: _ModalColors.muted,
                ),
              ),
              Text(
                'Rs ${total.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  color: isDark ? Colors.white : _ModalColors.ink,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Advance Input
        Text('ADVANCE PAYMENT', style: _ModalStyles.fieldLabel),
        const SizedBox(height: 5),
        _buildTextInput(
          controller: _advanceCtrl,
          hint: '0',
          keyboardType: TextInputType.number,
          prefixIcon: const Text('💵', style: TextStyle(fontSize: 14)),
          onChanged: (_) => setState(() {}),
          isDark: isDark,
        ),
        const SizedBox(height: 16),

        // Payment Method Options
        Text('PAYMENT METHOD', style: _ModalStyles.fieldLabel),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildPayMethodCard(PaymentMethod.online, '📱', 'Easypaisa', isDark),
            const SizedBox(width: 8),
            _buildPayMethodCard(PaymentMethod.card, '💳', 'JazzCash', isDark),
            const SizedBox(width: 8),
            _buildPayMethodCard(PaymentMethod.cash, '💵', 'Cash', isDark),
          ],
        ),
        const SizedBox(height: 18),

        // Live Summary Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _ModalColors.goldBg,
            border: Border.all(color: _ModalColors.goldLine, width: 1.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LIVE SUMMARY', style: _ModalStyles.summaryTitle),
              const SizedBox(height: 10),
              _buildSummaryLine('Total:', 'Rs ${total.toInt()}'),
              _buildSummaryLine('Advance:', 'Rs ${advance.toInt()}'),
              const Divider(color: _ModalColors.goldLine, height: 16),
              _buildSummaryLine(
                'Remaining:',
                'Rs ${remaining.toInt()}',
                valueColor: const Color(0xFFB45309),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPayMethodCard(PaymentMethod method, String icon, String label, bool isDark) {
    final isSelected = _paymentMethod == method;

    return Expanded(
      child: Material(
        color: isSelected
            ? (isDark ? const Color(0x28E9A227) : _ModalColors.goldBg)
            : (isDark ? _ModalColors.darkCard : const Color(0xFFFAFAFB)),
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _paymentMethod = method);
          },
          borderRadius: BorderRadius.circular(13),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected
                    ? _ModalColors.gold
                    : (isDark ? _ModalColors.darkLine : _ModalColors.line),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Column(
              children: [
                Text(icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isSelected
                        ? const Color(0xFFB45309)
                        : (isDark ? Colors.white70 : _ModalColors.muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── STEP 4: DATES & NOTES ─────────────────────────────────────────────────
  Widget _buildStep4(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_step4Error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _step4Error!,
              style: const TextStyle(color: _ModalColors.rose, fontSize: 11),
            ),
          ),

        // Date Pickers Row
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ORDER DATE', style: _ModalStyles.fieldLabel),
                  const SizedBox(height: 5),
                  InkWell(
                    onTap: () => _selectDate(context, false),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isDark ? _ModalColors.darkCard : const Color(0xFFFAFAFB),
                        border: Border.all(
                          color: isDark ? _ModalColors.darkLine : _ModalColors.line,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Text('📅', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat('dd MMM yyyy').format(_orderDate),
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : _ModalColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DELIVERY DATE *', style: _ModalStyles.fieldLabel),
                  const SizedBox(height: 5),
                  InkWell(
                    onTap: () => _selectDate(context, true),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isDark ? _ModalColors.darkCard : const Color(0xFFFAFAFB),
                        border: Border.all(
                          color: isDark ? _ModalColors.darkLine : _ModalColors.line,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Text('📅', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 10),
                          Text(
                            _deliveryDate != null
                                ? DateFormat('dd MMM yyyy').format(_deliveryDate!)
                                : 'Select Date',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _deliveryDate != null
                                  ? (isDark ? Colors.white : _ModalColors.ink)
                                  : _ModalColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Order Notes
        Text('ORDER NOTES (OPTIONAL)', style: _ModalStyles.fieldLabel),
        const SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: isDark ? _ModalColors.darkCard : const Color(0xFFFAFAFB),
            border: Border.all(
              color: isDark ? _ModalColors.darkLine : _ModalColors.line,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text('📝', style: TextStyle(fontSize: 15)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: isDark ? Colors.white : _ModalColors.ink,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Sleeve lamba karna, collar slim fit...',
                    hintStyle: GoogleFonts.dmSans(fontSize: 13, color: _ModalColors.faint),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Final Summary Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _ModalColors.goldBg,
            border: Border.all(color: _ModalColors.goldLine, width: 1.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('FINAL SUMMARY', style: _ModalStyles.summaryTitle),
              const SizedBox(height: 10),
              _buildSummaryLine('Client:', _selectedCustomer?.name ?? '—'),
              _buildSummaryLine('Items:', '${_items.length} item(s)'),
              _buildSummaryLine('Total:', 'Rs ${_itemsTotal.toInt()}'),
              _buildSummaryLine('Advance:', 'Rs ${_advanceAmount.toInt()}'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryLine(String k, String v, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: _ModalStyles.summaryKey),
          Text(
            v,
            style: _ModalStyles.summaryVal.copyWith(
              color: valueColor ?? const Color(0xFF211500),
            ),
          ),
        ],
      ),
    );
  }

  // ── MODAL FOOTER ──────────────────────────────────────────────────────────
  Widget _buildFooter(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
      decoration: BoxDecoration(
        color: isDark ? _ModalColors.darkCard : const Color(0xFFFAFAFB),
        border: Border(
          top: BorderSide(
            color: isDark ? _ModalColors.darkLine : _ModalColors.line,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Cancel / Back Button
          OutlinedButton(
            onPressed: () {
              if (_currentStep > 1) {
                _prevStep();
              } else {
                Navigator.pop(context);
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.white : _ModalColors.ink,
              backgroundColor: isDark ? _ModalColors.darkCard : Colors.white,
              side: BorderSide(
                color: isDark ? _ModalColors.darkLine : _ModalColors.line,
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Text(
              _currentStep > 1 ? '← Back' : 'Cancel',
              style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w800),
            ),
          ),

          // Next Step / Save Button
          Container(
            decoration: BoxDecoration(
              gradient: _currentStep == 4
                  ? const LinearGradient(colors: [_ModalColors.gold2, _ModalColors.gold])
                  : null,
              color: _currentStep == 4
                  ? null
                  : (isDark ? Colors.white : _ModalColors.dark),
              borderRadius: BorderRadius.circular(12),
              boxShadow: _currentStep == 4
                  ? const [
                      BoxShadow(
                        color: Color(0x38E9A227),
                        blurRadius: 14,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isSaving ? null : _nextStep,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _currentStep == 4 ? '✓ Save Order' : 'Next Step →',
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: _currentStep == 4
                                ? const Color(0xFF211500)
                                : (isDark ? _ModalColors.dark : Colors.white),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── SUCCESS STATE ─────────────────────────────────────────────────────────
  Widget _buildSuccessState() {
    final order = _savedOrder!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 54)),
          const SizedBox(height: 14),
          Text(
            'Order Created!',
            style: GoogleFonts.manrope(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : _ModalColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            order.customerName,
            style: GoogleFonts.dmSans(fontSize: 14, color: _ModalColors.muted),
          ),
          const SizedBox(height: 18),

          // Token Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: _ModalColors.goldBg,
              border: Border.all(color: _ModalColors.goldLine, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              order.tokenNumber,
              style: GoogleFonts.ibmPlexMono(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFB45309),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final router = GoRouter.of(context);
                    Navigator.pop(context, order);
                    router.push('/token-card/${order.id}');
                  },
                  icon: const Text('🪪'),
                  label: const Text('Print Card'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _sendWhatsApp(order, _selectedCustomer),
                  icon: const Text('💬'),
                  label: const Text('WhatsApp'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context, order),
            child: Text(
              '✕ Close',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _ModalColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── HELPER TEXT INPUT ─────────────────────────────────────────────────────
  Widget _buildTextInput({
    required TextEditingController controller,
    required String hint,
    required Widget prefixIcon,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
    required bool isDark,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? _ModalColors.darkCard : const Color(0xFFFAFAFB),
        border: Border.all(
          color: isDark ? _ModalColors.darkLine : _ModalColors.line,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(13),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          prefixIcon,
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              onChanged: onChanged,
              style: GoogleFonts.dmSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : _ModalColors.ink,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.dmSans(fontSize: 13, color: _ModalColors.faint),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
