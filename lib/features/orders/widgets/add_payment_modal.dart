import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_enums.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/providers/app_providers.dart';


class AddPaymentModal extends ConsumerStatefulWidget {
  final OrderModel order;

  const AddPaymentModal({
    super.key,
    required this.order,
  });

  static Future<void> show(BuildContext context, {required OrderModel order}) {
    return showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      barrierDismissible: false,
      barrierLabel: 'AddPaymentModal',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(20),
            child: AddPaymentModal(order: order),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: child,
          ),
        );
      },
    );
  }

  @override
  ConsumerState<AddPaymentModal> createState() => _AddPaymentModalState();
}

class _AddPaymentModalState extends ConsumerState<AddPaymentModal> {
  final _amountCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  
  PaymentMethod _method = PaymentMethod.cash;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Auto-fill with remaining balance
    _amountCtrl.text = widget.order.remainingAmount.toStringAsFixed(0);
    _dateCtrl.text = DateFormat('dd MMM, yyyy').format(_selectedDate);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _dateCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
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
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFFD97706),
                    surface: Colors.white,
                  ),
                ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateCtrl.text = DateFormat('dd MMM, yyyy').format(picked);
      });
    }
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ Please enter a valid amount',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    if (amount > widget.order.remainingAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ Amount exceeds outstanding balance',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
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
      paidAt: _selectedDate,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );

    try {
      await ref.read(ordersProvider.notifier).addPayment(widget.order.id, payment);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Payment recorded ✓',
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
            content: Text('❌ Error recording payment: $e'),
            backgroundColor: AppColors.red,
          ),
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
    const double width = 600.0;
    return AppModal(
      title: 'Add Payment',
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Content Scroll
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order Info Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.isDark ? Colors.white.withValues(alpha: 0.03) : context.surface2,
                      border: Border.all(color: context.isDark ? Colors.white.withValues(alpha: 0.05) : context.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.order.tokenNumber,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: context.accent,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.order.customerName,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: context.text1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'REMAINING',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: context.text3,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Rs. ${widget.order.remainingAmount.toStringAsFixed(0)}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: context.accent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Amount Field
                  AppTextField(
                    label: 'Amount (Required)',
                    hint: 'Enter amount',
                    controller: _amountCtrl,
                    prefix: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.payments_rounded, size: 18, color: context.text3),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 18),

                  // Payment Method Selector
                  Text(
                    'PAYMENT METHOD',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: context.text2,
                      letterSpacing: 1.0,
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
                  const SizedBox(height: 18),

                  // Date Field
                  GestureDetector(
                    onTap: _selectDate,
                    child: AbsorbPointer(
                      child: AppTextField(
                        label: 'Payment Date',
                        hint: 'Select date',
                        controller: _dateCtrl,
                        prefix: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(Icons.calendar_today_rounded, size: 18, color: context.text3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Notes Field
                  AppTextField(
                    label: 'Notes (Optional)',
                    hint: 'Payment note...',
                    controller: _noteCtrl,
                    prefix: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.notes_rounded, size: 18, color: context.text3),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            decoration: BoxDecoration(
              color: context.isDark ? const Color(0xFF0F1C30) : context.surface2,
              border: Border(
                top: BorderSide(
                  color: context.isDark ? Colors.white.withValues(alpha: 0.06) : context.border,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Cancel Button
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.text2,
                    side: BorderSide(color: context.isDark ? Colors.white.withValues(alpha: 0.08) : context.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 12),

                // Record Payment Button (Gold)
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF5A623), Color(0xFFD97706)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x59F5A623),
                        blurRadius: 14,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: const Color(0xFF1A0A00),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF1A0A00),
                            ),
                          )
                        : Text(
                            'Record Payment ✓',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayMethodOption(PaymentMethod method, String iconStr, String label) {
    final isSelected = _method == method;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _method = method);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0x14F5A623) : (context.isDark ? const Color(0x08FFFFFF) : context.surface2),
            border: Border.all(
              color: isSelected ? const Color(0xFFF5A623) : (context.isDark ? const Color(0x12FFFFFF) : context.border),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(iconStr, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? context.accent : context.text2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
