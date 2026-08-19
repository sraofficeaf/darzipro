import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/admin_service.dart';

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

  static const _amber = Color(0xFFF5A623);
  static const _red = Color(0xFFFF3A58);

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final surface = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final surface2 = isDark ? const Color(0xFF273548) : const Color(0xFFF1F5F9);
    final border = isDark ? const Color(0x18FFFFFF) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Container(
        width: 460,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.1),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: border)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF5A623), Color(0xFFD97706)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_add_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Create New User',
                            style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: textPrimary)),
                        Text('New shop account banao',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: textSecondary)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _loading ? null : () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.close_rounded,
                          color: textSecondary, size: 16),
                    ),
                  ),
                ],
              ),
            ),

            // Form
            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Error message
                    if (_errorMsg != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _red.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: _red, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_errorMsg!,
                                  style: GoogleFonts.inter(
                                      fontSize: 12, color: _red)),
                            ),
                          ],
                        ),
                      ),

                    _buildField(
                      controller: _shopCtrl,
                      label: 'Shop Name',
                      hint: 'e.g. Ali Tailor & Sons',
                      icon: Icons.storefront_outlined,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      surface2: surface2,
                      border: border,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      controller: _nameCtrl,
                      label: 'Owner Full Name',
                      hint: 'e.g. Saifur Rahman',
                      icon: Icons.person_outline_rounded,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      surface2: surface2,
                      border: border,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      controller: _emailCtrl,
                      label: 'Email Address',
                      hint: 'e.g. ali@example.com',
                      icon: Icons.email_outlined,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      surface2: surface2,
                      border: border,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (!v.contains('@')) return 'Valid email required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      controller: _passCtrl,
                      label: 'Password',
                      hint: 'Min 8 characters',
                      icon: Icons.lock_outline_rounded,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      surface2: surface2,
                      border: border,
                      obscure: _obscure,
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
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

                    const SizedBox(height: 24),

                    // Info box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _amber.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _amber.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: _amber, size: 15),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'User ka account create hoga aur wo directly login kar sakta hai. Email confirmation ki zaroorat nahi.',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: _amber.withValues(alpha: 0.9),
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                _loading ? null : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textSecondary,
                              side: BorderSide(color: border),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text('Cancel',
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _amber,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.person_add_rounded,
                                          size: 16),
                                      const SizedBox(width: 8),
                                      Text('Create User',
                                          style: GoogleFonts.inter(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14)),
                                    ],
                                  ),
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
    required Color textPrimary,
    required Color textSecondary,
    required Color surface2,
    required Color border,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textSecondary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.inter(color: textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                GoogleFonts.inter(color: textSecondary.withValues(alpha: 0.5), fontSize: 13),
            prefixIcon: Icon(icon, color: textSecondary, size: 18),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: surface2,
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
              borderSide: const BorderSide(color: _amber, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _red),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }
}
