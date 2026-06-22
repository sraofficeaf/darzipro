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

class AddPaymentScreen extends ConsumerStatefulWidget {
  final String orderId;
  const AddPaymentScreen({super.key, required this.orderId});

  @override
  ConsumerState<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends ConsumerState<AddPaymentScreen> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;
  bool _isSaving = false;

  OrderModel? get _order {
    try {
      final ordersAsync = ref.watch(ordersProvider);
      return ordersAsync.value?.firstWhere((o) => o.id == widget.orderId);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sahi amount enter karein',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final order = _order;
    if (order != null && amount > order.remainingAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Amount baqi raqam se zyada nahi ho sakti!',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final payment = PaymentModel(
      id: const Uuid().v4(),
      amount: amount,
      method: _method,
      paidAt: DateTime.now(),
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );

    try {
      await ref.read(ordersProvider.notifier).addPayment(widget.orderId, payment);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ ${formatMoney(amount)} payment recorded!',
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
          SnackBar(content: Text('Failed to save payment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final order = _order;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final surf = isDark ? AppColors.surfDark : AppColors.surfLight;
    final surf2 = isDark ? AppColors.surf2Dark : AppColors.surf2Light;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final t3 = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        }
      },
      child: Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surf,
        leading: IconButton(
          icon: const Text('←', style: TextStyle(fontSize: 20)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Add Payment',
          style: GoogleFonts.inter(
              fontSize: 18, fontWeight: FontWeight.w800, color: t1),
        ),
      ),
      body: order == null
          ? const EmptyState(emoji: '🔍', title: 'Order Not Found')
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Balance Summary Card
                AppCard(
                  gradientColors: const [Color(0xFF0D1525), Color(0xFF1A2540)],
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text('📋', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.tokenNumber,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.accent,
                                  ),
                                ),
                                Text(
                                  order.customerName,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusPill(status: order.status),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.07)),
                      const SizedBox(height: 14),
                      _BalRow('Total Amount',
                          formatMoney(order.totalAmount), Colors.white),
                      if (order.discount > 0)
                        _BalRow('Discount',
                            '- ${formatMoney(order.discount)}', AppColors.teal),
                      _BalRow('Already Paid', formatMoney(order.paidAmount),
                          Colors.white.withValues(alpha: 0.7)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: order.isFullyPaid
                              ? AppColors.tealS
                              : AppColors.accentS,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: order.isFullyPaid
                                ? AppColors.teal.withValues(alpha: 0.4)
                                : AppColors.accent.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              order.isFullyPaid
                                  ? '✅ Fully Paid'
                                  : '⚡ Remaining Balance',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: order.isFullyPaid
                                      ? AppColors.teal
                                      : AppColors.accent),
                            ),
                            Text(
                              order.isFullyPaid
                                  ? 'CLEAR'
                                  : formatMoney(order.remainingAmount),
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: order.isFullyPaid ? 14 : 22,
                                fontWeight: FontWeight.w900,
                                color: order.isFullyPaid
                                    ? AppColors.teal
                                    : AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Quick amount buttons
                if (!order.isFullyPaid) ...[
                  Text(
                    'QUICK AMOUNT',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: t2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _QuickBtn(
                        label: 'Full\n${formatMoneyShort(order.remainingAmount)}',
                        onTap: () => _amountCtrl.text =
                            order.remainingAmount.toStringAsFixed(0),
                        isHighlight: true,
                      ),
                      const SizedBox(width: 8),
                      _QuickBtn(
                        label: 'Half\n${formatMoneyShort(order.remainingAmount / 2)}',
                        onTap: () => _amountCtrl.text =
                            (order.remainingAmount / 2).toStringAsFixed(0),
                      ),
                      const SizedBox(width: 8),
                      _QuickBtn(label: '₨ 1000', onTap: () => _amountCtrl.text = '1000'),
                      const SizedBox(width: 8),
                      _QuickBtn(label: '₨ 2000', onTap: () => _amountCtrl.text = '2000'),
                      const SizedBox(width: 8),
                      _QuickBtn(label: '₨ 5000', onTap: () => _amountCtrl.text = '5000'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  AppTextField(
                    label: 'PAYMENT AMOUNT',
                    prefix: Text(
                      '₨ ',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    hint: '0',
                  ),

                  // Payment method
                  Text(
                    'PAYMENT METHOD',
                    style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: t2),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: PaymentMethod.values.map((m) {
                      final isActive = _method == m;
                      final data = {
                        PaymentMethod.cash: ('💵', 'Cash'),
                        PaymentMethod.card: ('💳', 'Card'),
                        PaymentMethod.online: ('📱', 'Online'),
                      }[m]!;
                      final activeColor = isDark ? AppColors.accent : AppColors.accentL;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _method = m),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isActive ? AppColors.accentS : surf2,
                              border: Border.all(
                                color: isActive ? activeColor : border,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                Text(data.$1,
                                    style: const TextStyle(fontSize: 22)),
                                const SizedBox(height: 4),
                                Text(
                                  data.$2,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: isActive ? activeColor : t2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  AppTextField(
                    label: 'NOTE (OPTIONAL)',
                    controller: _noteCtrl,
                    maxLines: 2,
                    hint: 'e.g. Final payment on delivery',
                  ),
                  const SizedBox(height: 24),

                  // Save button
                  GoldButton(
                    height: 46,
                    borderRadius: 16,
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Color(0xFF1A0F00), strokeWidth: 2.5),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text('💳  ', style: TextStyle(fontSize: 16)),
                              Text(
                                'Record Payment',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),
                ],

                // Payment History
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text(
                      'PAYMENT HISTORY',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: t2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Divider(
                            color: border, thickness: 1)),
                  ],
                ),
                const SizedBox(height: 10),
                if (order.payments.isEmpty)
                  const EmptyState(
                      emoji: '💰', title: 'No Payments Yet')
                else
                  ...order.payments.asMap().entries.map((e) {
                    final idx = e.key;
                    final p = e.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.tealS,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  '${idx + 1}',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.teal,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    formatDate(p.paidAt),
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: t1),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        _methodEmoji(p.method),
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _methodLabel(p.method),
                                        style: GoogleFonts.inter(
                                            fontSize: 11.5, color: t2),
                                      ),
                                      if (p.note != null) ...[
                                        Text(' · ',
                                            style: GoogleFonts.inter(
                                                fontSize: 11.5, color: t3)),
                                        Text(p.note!,
                                            style: GoogleFonts.inter(
                                                fontSize: 11.5, color: t2)),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              formatMoney(p.amount),
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: AppColors.teal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 30),
              ],
            ),
    ));
  }

  String _methodEmoji(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.cash:
        return '💵';
      case PaymentMethod.card:
        return '💳';
      case PaymentMethod.online:
        return '📱';
    }
  }

  String _methodLabel(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.online:
        return 'Online';
    }
  }
}

// ── Helpers ────────────────────────────────────────────────────────────
class _BalRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _BalRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.5))),
          Text(value,
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isHighlight;

  const _QuickBtn(
      {required this.label, required this.onTap, this.isHighlight = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf2 = isDark ? AppColors.surf2Dark : AppColors.surf2Light;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final activeColor = isDark ? AppColors.accent : AppColors.accentL;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isHighlight ? AppColors.accentS : surf2,
            border: Border.all(
              color: isHighlight ? activeColor : border,
              width: isHighlight ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: isHighlight
                    ? activeColor
                    : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
                height: 1.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
