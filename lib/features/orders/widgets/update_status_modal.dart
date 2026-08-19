import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_enums.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/providers/app_providers.dart';


class UpdateStatusModal extends ConsumerStatefulWidget {
  final OrderModel order;

  const UpdateStatusModal({
    super.key,
    required this.order,
  });

  static Future<void> show(BuildContext context, {required OrderModel order}) {
    return showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      barrierDismissible: false,
      barrierLabel: 'UpdateStatusModal',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(20),
            child: UpdateStatusModal(order: order),
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
  ConsumerState<UpdateStatusModal> createState() => _UpdateStatusModalState();
}

class _UpdateStatusModalState extends ConsumerState<UpdateStatusModal> {
  late OrderStatus _selectedStatus;
  bool _sendWhatsApp = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.order.status;
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return const Color(0xFFF5A623);
      case OrderStatus.cutting:
        return const Color(0xFF9B5CF5);
      case OrderStatus.stitching:
        return const Color(0xFF5B72F5);
      case OrderStatus.ready:
        return const Color(0xFF10CBA0);
      case OrderStatus.delivered:
        return const Color(0xFF5A7090);
      case OrderStatus.cancelled:
        return const Color(0xFFFF3A58);
    }
  }

  Color _getStatusTextColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
      case OrderStatus.ready:
        return const Color(0xFF1A0A00);
      case OrderStatus.cutting:
      case OrderStatus.stitching:
      case OrderStatus.delivered:
      case OrderStatus.cancelled:
        return Colors.white;
    }
  }

  String _getStatusUrdu(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'آرڈر موصول ہوا';
      case OrderStatus.cutting:
        return 'کپڑا کاٹا جا رہا ہے';
      case OrderStatus.stitching:
        return 'سلائی ہو رہی ہے';
      case OrderStatus.ready:
        return 'تیار ہے، اطلاع دیں';
      case OrderStatus.delivered:
        return 'گاہک کو دے دیا';
      case OrderStatus.cancelled:
        return 'منسوخ ہو گیا';
    }
  }

  String _getStatusEnglish(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Order Received';
      case OrderStatus.cutting:
        return 'Fabric is being cut';
      case OrderStatus.stitching:
        return 'Stitching in progress';
      case OrderStatus.ready:
        return 'Ready, notify customer';
      case OrderStatus.delivered:
        return 'Delivered to customer';
      case OrderStatus.cancelled:
        return 'Order cancelled';
    }
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _isSaving = true);
    
    try {
      await ref.read(ordersProvider.notifier).updateOrderStatus(widget.order.id, _selectedStatus);
      
      if (mounted) {
        nav.pop();
        
        // WhatsApp trigger
        if (_selectedStatus == OrderStatus.ready && _sendWhatsApp) {
          final customers = ref.read(customersProvider).valueOrNull ?? [];
          final customer = customers.firstWhere((c) => c.id == widget.order.customerId, orElse: () => CustomerModel(
            id: widget.order.customerId,
            name: widget.order.customerName,
            phone: '',
            address: '',
            gender: CustomerGender.male,
            createdAt: DateTime.now(),
          ));

          if (customer.phone.isNotEmpty) {
            var phone = customer.phone.replaceAll(RegExp(r'\D'), '');
            if (phone.startsWith('0')) {
              phone = '92${phone.substring(1)}';
            }
            final message = 'Aapka order ${widget.order.tokenNumber} tayyar hai. Darzi shop se le jayein.';
            final urlStr = 'https://wa.me/$phone?text=${Uri.encodeComponent(message)}';
            final uri = Uri.parse(urlStr);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          }
        }

        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '✅ Status updated to: ${_selectedStatus.label}',
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
            content: Text('❌ Failed to update status: $e'),
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
    const double width = 680.0;
    return AppModal(
      title: 'Update Order Status',
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current Status Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: context.isDark ? Colors.white.withValues(alpha: 0.03) : context.surface2,
                      border: Border.all(color: context.isDark ? Colors.white.withValues(alpha: 0.05) : context.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'CURRENT STATUS',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: context.text3,
                            letterSpacing: 1.0,
                          ),
                        ),
                        _buildStatusBadge(widget.order.status),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Selectable options
                  Text(
                    'SELECT NEW STATUS',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: context.text3,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Column(
                    children: OrderStatus.values.map((status) => _buildStatusCard(status)).toList(),
                  ),

                  // WhatsApp Toggle (if Ready selected)
                  if (_selectedStatus == OrderStatus.ready) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.isDark ? const Color(0x0A10CBA0) : AppColors.lightTealBg,
                        border: Border.all(color: context.isDark ? const Color(0x1A10CBA0) : AppColors.lightTealBorder),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('💬', style: TextStyle(fontSize: 18)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Send WhatsApp to customer',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: context.text1,
                                  ),
                                ),
                              ),
                              Switch.adaptive(
                                value: _sendWhatsApp,
                                activeTrackColor: const Color(0x6610CBA0),
                                activeThumbColor: const Color(0xFF10CBA0),
                                onChanged: (val) {
                                    setState(() => _sendWhatsApp = val);
                                },
                              ),
                            ],
                          ),
                          if (_sendWhatsApp) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: context.isDark ? Colors.black.withValues(alpha: 0.25) : context.surface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Aapka order ${widget.order.tokenNumber} tayyar hai. Darzi shop se le jayein.',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: context.text2,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
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

                // Update Button (Gold)
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
                            'Update Status ✓',
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

  Widget _buildStatusCard(OrderStatus status) {
    final isSelected = _selectedStatus == status;
    final statusColor = _getStatusColor(status);
    final statusTextColor = _getStatusTextColor(status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _selectedStatus = status);
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? statusColor : (context.isDark ? Colors.white.withValues(alpha: 0.03) : context.surface2),
            border: Border.all(
              color: isSelected ? statusColor : (context.isDark ? Colors.white.withValues(alpha: 0.05) : context.border),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Text(
                status.emoji,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${status.label} — ${_getStatusUrdu(status)}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? statusTextColor : context.text1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getStatusEnglish(status),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isSelected ? statusTextColor.withValues(alpha: 0.7) : context.text2,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: statusTextColor,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    final statusColor = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.15),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: statusColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
