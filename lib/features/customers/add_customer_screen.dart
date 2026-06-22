import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_enums.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/models/models.dart';

class AddCustomerScreen extends ConsumerStatefulWidget {
  const AddCustomerScreen({super.key});

  @override
  ConsumerState<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends ConsumerState<AddCustomerScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  CustomerGender _gender = CustomerGender.male;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    
    final newCustomer = CustomerModel(
      id: const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      gender: _gender,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdAt: DateTime.now(),
    );

    try {
      await ref.read(customersProvider.notifier).addCustomer(newCustomer);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to save client: $e',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
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
        title: Text(
          'Add Client',
          style: GoogleFonts.inter(
              fontSize: 18, fontWeight: FontWeight.w800, color: t1),
        ),
        leading: IconButton(
          icon: const Text('←', style: TextStyle(fontSize: 20)),
          onPressed: () => context.pop(),
        ),
        actions: const [],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildField('FULL NAME', '👤', _nameCtrl, t1, t2, t3, surf2, border,
              hint: 'e.g. Ali Khan'),
          _buildField('PHONE', '📱', _phoneCtrl, t1, t2, t3, surf2, border,
              hint: '0300 1234567',
              keyboard: TextInputType.phone),
          _buildField('ADDRESS', '🏠', _addressCtrl, t1, t2, t3, surf2, border,
              hint: 'Saddar, Peshawar'),

          // Gender selector
          _label('GENDER', t2),
          const SizedBox(height: 6),
          Row(
            children: CustomerGender.values.map((g) {
              final isActive = _gender == g;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _gender = g),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.accentSS : surf2,
                      border: Border.all(
                        color: isActive ? (isDark ? AppColors.accent : AppColors.accentL) : border,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(g.emoji, style: const TextStyle(fontSize: 22)),
                        const SizedBox(height: 4),
                        Text(
                          g.label,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isActive ? AppColors.accent : t2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          _buildField('NOTES', '📌', _notesCtrl, t1, t2, t3, surf2, border,
              hint: 'Special instructions, preferences…',
              maxLines: 3),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: GoldButton(
              onPressed: _save,
              borderRadius: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('💾', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    'SAVE CLIENT',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ));
  }

  Widget _label(String text, Color color) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: color,
      ),
    );
  }

  Widget _buildField(
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
    int maxLines = 1,
  }) {
    return AppTextField(
      label: label,
      prefixIcon: icon,
      controller: ctrl,
      hint: hint,
      keyboardType: keyboard,
      maxLines: maxLines,
    );
  }
}
