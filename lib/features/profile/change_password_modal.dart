import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../../core/widgets/shared_widgets.dart';

class ChangePasswordModal extends ConsumerStatefulWidget {
  const ChangePasswordModal({super.key});

  static Future<void> show(BuildContext context) {
    return showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      barrierDismissible: false,
      barrierLabel: 'ChangePasswordModal',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(20),
            child: const ChangePasswordModal(),
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
  ConsumerState<ChangePasswordModal> createState() => _ChangePasswordModalState();
}

class _ChangePasswordModalState extends ConsumerState<ChangePasswordModal> {
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;

  String? _currentError;
  String? _newError;
  String? _confirmError;

  @override
  void dispose() {
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  String get _strengthText {
    final pass = _newPassCtrl.text;
    if (pass.isEmpty) return '';
    if (pass.length < 8) return 'Weak';
    
    bool hasLetters = pass.contains(RegExp(r'[a-zA-Z]'));
    bool hasDigits = pass.contains(RegExp(r'[0-9]'));
    bool hasSpecial = pass.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    
    if (hasLetters && hasDigits && hasSpecial) return 'Strong';
    if (hasLetters && hasDigits) return 'Medium';
    return 'Weak';
  }

  Color get _strengthColor {
    switch (_strengthText) {
      case 'Strong':
        return const Color(0xFF10CBA0); // Teal
      case 'Medium':
        return const Color(0xFFF5A623); // Gold
      case 'Weak':
      default:
        return const Color(0xFFFF3A58); // Red
    }
  }

  Future<void> _save() async {
    setState(() {
      _currentError = null;
      _newError = null;
      _confirmError = null;
    });

    bool isValid = true;

    if (_currentPassCtrl.text.isEmpty) {
      setState(() => _currentError = 'Current password is required');
      isValid = false;
    }

    if (_newPassCtrl.text.length < 8) {
      setState(() => _newError = 'New password must be at least 8 characters');
      isValid = false;
    }

    if (_confirmPassCtrl.text != _newPassCtrl.text) {
      setState(() => _confirmError = 'Confirm password must match new password');
      isValid = false;
    }

    if (!isValid) return;

    setState(() => _isSaving = true);

    try {
      // Call Supabase auth.updateUser
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newPassCtrl.text),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Password changed successfully ✓',
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
            content: Text('❌ Password change failed: $e'),
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
      title: 'Change Password',
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
                  // Current Password
                  AppTextField(
                    label: 'Current Password',
                    hint: 'Enter current password',
                    controller: _currentPassCtrl,
                    obscureText: _obscureCurrent,
                    prefix: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.lock_rounded, size: 18, color: Color(0xFF2D4060)),
                    ),
                    suffix: IconButton(
                      icon: Icon(
                        _obscureCurrent ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        size: 18,
                        color: const Color(0xFF5A7090),
                      ),
                      onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                    ),
                  ),
                  if (_currentError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _currentError!,
                      style: GoogleFonts.inter(color: AppColors.red, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                  const SizedBox(height: 18),

                  // New Password
                  AppTextField(
                    label: 'New Password',
                    hint: 'Enter new password',
                    controller: _newPassCtrl,
                    obscureText: _obscureNew,
                    onChanged: (_) => setState(() {}), // refresh strength indicator
                    prefix: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.lock_open_rounded, size: 18, color: Color(0xFF2D4060)),
                    ),
                    suffix: IconButton(
                      icon: Icon(
                        _obscureNew ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        size: 18,
                        color: const Color(0xFF5A7090),
                      ),
                      onPressed: () => setState(() => _obscureNew = !_obscureNew),
                    ),
                  ),
                  _buildStrengthBar(),
                  if (_newError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _newError!,
                      style: GoogleFonts.inter(color: AppColors.red, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                  const SizedBox(height: 18),

                  // Confirm Password
                  AppTextField(
                    label: 'Confirm New Password',
                    hint: 'Confirm new password',
                    controller: _confirmPassCtrl,
                    obscureText: _obscureConfirm,
                    prefix: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.lock_rounded, size: 18, color: Color(0xFF2D4060)),
                    ),
                    suffix: IconButton(
                      icon: Icon(
                        _obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        size: 18,
                        color: const Color(0xFF5A7090),
                      ),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  if (_confirmError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _confirmError!,
                      style: GoogleFonts.inter(color: AppColors.red, fontSize: 11, fontWeight: FontWeight.w600),
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
              color: const Color(0xFF0F1C30),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.06),
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
                    foregroundColor: const Color(0xFF8AA0B8),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
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

                // Save Password Button (Gold)
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
                            'Change Password ✓',
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

  Widget _buildStrengthBar() {
    final strength = _strengthText;
    if (strength.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: strength == 'Weak' ? 0.33 : (strength == 'Medium' ? 0.66 : 1.0),
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  valueColor: AlwaysStoppedAnimation(_strengthColor),
                  minHeight: 4,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              strength,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: _strengthColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
