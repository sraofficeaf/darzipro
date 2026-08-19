import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/providers/app_providers.dart';


class DeliveryDateModal extends ConsumerStatefulWidget {
  final OrderModel order;

  const DeliveryDateModal({
    super.key,
    required this.order,
  });

  static Future<void> show(BuildContext context, {required OrderModel order}) {
    return showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      barrierDismissible: false,
      barrierLabel: 'DeliveryDateModal',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(20),
            child: DeliveryDateModal(order: order),
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
  ConsumerState<DeliveryDateModal> createState() => _DeliveryDateModalState();
}

class _DeliveryDateModalState extends ConsumerState<DeliveryDateModal> {
  late DateTime _selectedDate;
  final _reasonCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.order.deliveryDate ?? DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _addDays(int days) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedDate = DateTime.now().add(Duration(days: days));
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    String? updatedNotes = widget.order.notes;
    if (_reasonCtrl.text.trim().isNotEmpty) {
      final changeLog = 'Delivery date changed to ${DateFormat('dd MMM yyyy').format(_selectedDate)}. Reason: ${_reasonCtrl.text.trim()}';
      if (updatedNotes == null || updatedNotes.trim().isEmpty) {
        updatedNotes = changeLog;
      } else {
        updatedNotes = '${updatedNotes.trim()}\n$changeLog';
      }
    }

    try {
      await ref.read(ordersProvider.notifier).updateDeliveryDate(
        widget.order.id,
        _selectedDate,
        updatedNotes,
      );
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Delivery date updated ✓',
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
            content: Text('❌ Update failed: $e'),
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
    const double width = 560.0;
    
    return AppModal(
      title: 'Change Delivery Date',
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current Date Display
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.isDark ? Colors.white.withValues(alpha: 0.03) : context.surface2,
                      border: Border.all(color: context.isDark ? Colors.white.withValues(alpha: 0.05) : context.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'CURRENT DATE',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: context.text3,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          widget.order.deliveryDate != null
                              ? DateFormat('dd MMM yyyy').format(widget.order.deliveryDate!)
                              : 'Not Set',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFF5A623),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Calendar Picker (Inline)
                  Theme(
                    data: context.isDark
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
                              onPrimary: Colors.white,
                              surface: Colors.white,
                              onSurface: Color(0xFF0F172A),
                            ),
                          ),
                    child: SizedBox(
                      height: 280,
                      child: CalendarDatePicker(
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                        onDateChanged: (date) {
                          setState(() => _selectedDate = date);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quick Options Row
                  Text(
                    'QUICK SET',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: context.text3,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildQuickOption('+7 Days', () => _addDays(7)),
                      const SizedBox(width: 8),
                      _buildQuickOption('+14 Days', () => _addDays(14)),
                      const SizedBox(width: 8),
                      _buildQuickOption('+30 Days', () => _addDays(30)),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Reason Note
                  AppTextField(
                    label: 'Reason for change (Optional)',
                    hint: 'e.g. Fabric delayed, client request',
                    controller: _reasonCtrl,
                    prefix: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.edit_calendar_rounded, size: 18, color: context.text3),
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
                // Cancel
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

                // Save Date Button (Gold)
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
                            'Update Date ✓',
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

  Widget _buildQuickOption(String label, VoidCallback onTap) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: context.text1,
          backgroundColor: context.isDark ? Colors.white.withValues(alpha: 0.03) : context.surface2,
          side: BorderSide(color: context.isDark ? Colors.white.withValues(alpha: 0.06) : context.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
