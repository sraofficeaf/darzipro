import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_enums.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/providers/app_providers.dart';

class EditCustomerModal extends ConsumerStatefulWidget {
  final CustomerModel customer;

  const EditCustomerModal({
    super.key,
    required this.customer,
  });

  static Future<void> show(BuildContext context, {required CustomerModel customer}) {
    return showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      barrierDismissible: false,
      barrierLabel: 'EditCustomerModal',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(20),
            child: EditCustomerModal(customer: customer),
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
  ConsumerState<EditCustomerModal> createState() => _EditCustomerModalState();
}

class _EditCustomerModalState extends ConsumerState<EditCustomerModal> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _birthdayCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  CustomerGender _gender = CustomerGender.male;
  DateTime? _birthday;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.customer.name;
    _phoneCtrl.text = widget.customer.phone;
    _addressCtrl.text = widget.customer.address;
    _gender = widget.customer.gender;

    // Parse WhatsApp & Birthday from Notes
    String? whatsapp;
    String? birthdayStr;
    String cleanedNotes = '';

    if (widget.customer.notes != null) {
      final lines = widget.customer.notes!.split('\n');
      final cleanLines = <String>[];
      for (final line in lines) {
        if (line.startsWith('WhatsApp: ')) {
          whatsapp = line.substring('WhatsApp: '.length);
        } else if (line.startsWith('Birthday: ')) {
          birthdayStr = line.substring('Birthday: '.length);
        } else {
          cleanLines.add(line);
        }
      }
      cleanedNotes = cleanLines.join('\n');
    }

    _notesCtrl.text = cleanedNotes;
    _whatsappCtrl.text = whatsapp ?? '';
    _birthdayCtrl.text = birthdayStr ?? '';

    if (birthdayStr != null) {
      try {
        _birthday = DateFormat('dd MMM yyyy').parse(birthdayStr);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _whatsappCtrl.dispose();
    _birthdayCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectBirthday(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
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
        _birthday = picked;
        _birthdayCtrl.text = DateFormat('dd MMM yyyy').format(picked);
      });
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ Full Name is required',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    if (_phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ Phone Number is required',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    // Construct Notes with WhatsApp & Birthday
    final List<String> notesParts = [];
    if (_notesCtrl.text.trim().isNotEmpty) {
      notesParts.add(_notesCtrl.text.trim());
    }
    if (_whatsappCtrl.text.trim().isNotEmpty) {
      notesParts.add('WhatsApp: ${_whatsappCtrl.text.trim()}');
    }
    if (_birthdayCtrl.text.trim().isNotEmpty) {
      notesParts.add('Birthday: ${_birthdayCtrl.text.trim()}');
    }
    final finalNotes = notesParts.isEmpty ? null : notesParts.join('\n');

    final updated = widget.customer.copyWith(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      gender: _gender,
      notes: finalNotes,
    );

    try {
      await ref.read(customersProvider.notifier).updateCustomer(updated);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Profile updated ✓',
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
    const double width = 760.0;
    return AppModal(
      title: 'Edit Profile',
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Scrollable Fields
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Full Name
                  AppTextField(
                    label: 'Full Name (Required)',
                    hint: 'e.g. Saifur Rahman',
                    controller: _nameCtrl,
                    prefix: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.person_rounded, size: 18, color: Color(0xFF2D4060)),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Phone Number
                  AppTextField(
                    label: 'Phone Number (Required)',
                    hint: 'e.g. 0300 1234567',
                    controller: _phoneCtrl,
                    prefix: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.phone_rounded, size: 18, color: Color(0xFF2D4060)),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 18),

                  // Address
                  AppTextField(
                    label: 'Address (Optional)',
                    hint: 'e.g. Saddar, Peshawar',
                    controller: _addressCtrl,
                    prefix: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.location_on_rounded, size: 18, color: Color(0xFF2D4060)),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // WhatsApp
                  AppTextField(
                    label: 'WhatsApp (Optional)',
                    hint: 'e.g. 0300 1234567',
                    controller: _whatsappCtrl,
                    prefix: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.chat_rounded, size: 18, color: Color(0xFF2D4060)),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 18),

                  // Gender Selector
                  Text(
                    'GENDER',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: context.text3,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildGenderOption(CustomerGender.male, '👔', 'Men'),
                      const SizedBox(width: 8),
                      _buildGenderOption(CustomerGender.female, '👗', 'Women'),
                      const SizedBox(width: 8),
                      _buildGenderOption(CustomerGender.child, '👕', 'Children'),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Birthday
                  GestureDetector(
                    onTap: () => _selectBirthday(context),
                    child: AbsorbPointer(
                      child: AppTextField(
                        label: 'Birthday (Optional)',
                        hint: 'Select birthday',
                        controller: _birthdayCtrl,
                        prefix: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(Icons.cake_rounded, size: 18, color: Color(0xFF2D4060)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Notes (Multiline)
                  AppTextField(
                    label: 'Notes (Optional)',
                    hint: 'Special instructions...',
                    controller: _notesCtrl,
                    prefix: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.notes_rounded, size: 18, color: Color(0xFF2D4060)),
                    ),
                    maxLines: 3,
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

                // Save Changes Button (Gold)
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
                            'Save Changes ✓',
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

  Widget _buildGenderOption(CustomerGender g, String emoji, String label) {
    final isSelected = _gender == g;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _gender = g);
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
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? const Color(0xFFF5A623) : context.text2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
