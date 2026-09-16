import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/admin_service.dart';
import '../../core/theme/theme_extensions.dart';
import 'widgets/admin_ui_kit.dart';

class AdminCreateUserModal extends StatefulWidget {
  const AdminCreateUserModal({super.key});

  @override
  State<AdminCreateUserModal> createState() => _AdminCreateUserModalState();
}

class _AdminCreateUserModalState extends State<AdminCreateUserModal> {
  final _formKey = GlobalKey<FormState>();
  final _shopCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _shopCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    final result = await AdminService.instance.createShopUser(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
      shopName: _shopCtrl.text.trim(),
      ownerName: _nameCtrl.text.trim(),
    );

    if (mounted) {
      if (result['success'] == true) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _loading = false;
          _errorMsg = result['error']?.toString() ?? 'Unknown error occurred';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    final border = context.border;
    final textPrimary = context.text1;
    final textSecondary = context.text2;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Container(
        width: 460,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 36,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header (HTML Section 2 match)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AdminColors.indigo, AdminColors.violet],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create New User',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'New shop account banao',
                          style: GoogleFonts.inter(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  AdminIconBtn(
                    icon: Icons.close_rounded,
                    size: 32,
                    onPressed: _loading ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Form
            Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Error message
                    if (_errorMsg != null) ...[
                      AdminInfoBox.rose(text: _errorMsg!),
                      const SizedBox(height: 14),
                    ],

                    _buildField(
                      controller: _shopCtrl,
                      label: 'Shop Name',
                      hint: 'e.g. Ali Tailor & Sons',
                      icon: Icons.storefront_outlined,
                      context: context,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _nameCtrl,
                      label: 'Owner Full Name',
                      hint: 'e.g. Saifur Rahman',
                      icon: Icons.person_outline_rounded,
                      context: context,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _emailCtrl,
                      label: 'Email Address',
                      hint: 'e.g. ali@example.com',
                      icon: Icons.email_outlined,
                      context: context,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (!v.contains('@')) return 'Valid email required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _passCtrl,
                      label: 'Password',
                      hint: 'Min 8 characters',
                      icon: Icons.lock_outline_rounded,
                      context: context,
                      obscure: _obscure,
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: textSecondary,
                          size: 18,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (v.length < 8) return 'Min 8 characters';
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Info box (HTML match)
                    const AdminInfoBox.amber(
                      text: 'User ka account create hoga aur wo directly login kar sakta hai. Email confirmation ki zaroorat nahi.',
                    ),

                    const SizedBox(height: 18),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: AdminButton.ghost(
                            label: 'Cancel',
                            onPressed: _loading ? null : () => Navigator.pop(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: AdminButton.primary(
                            label: _loading ? 'Creating...' : 'Create User',
                            icon: _loading ? null : Icons.person_add_rounded,
                            onPressed: _loading ? null : _submit,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required BuildContext context,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: text2),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.inter(color: text1, fontSize: 13.5),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: text2.withValues(alpha: 0.5), fontSize: 13),
            prefixIcon: Icon(icon, color: text2, size: 18),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: context.bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AdminColors.indigo, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AdminColors.rose),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }
}
