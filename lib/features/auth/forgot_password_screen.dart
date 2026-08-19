import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bcrypt/bcrypt.dart';
import '../../core/constants/app_colors.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Step tracker: 0 = Email, 1 = Verification Code (OTP), 2 = New Password, 3 = Success
  int _step = 0;

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _otpFocusNode = FocusNode();
  final FocusNode _newPasswordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  bool _isLoading = false;
  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    _emailFocusNode.dispose();
    _otpFocusNode.dispose();
    _newPasswordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(isError ? '⚠️ ' : '✅ ', style: const TextStyle(fontSize: 16)),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryDark,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A2A40),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: Border(
          left: BorderSide(
            color: isError ? const Color(0xFFFF3A58) : const Color(0xFF10CBA0),
            width: 3,
          ),
        ),
      ),
    );
  }

  // STEP 1: Send OTP Code to Email
  Future<void> _handleSendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnackBar('Please enter your email address');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      setState(() {
        _step = 1;
      });
      _showSnackBar('Verification code sent to your email!', isError: false);
    } catch (e) {
      _showSnackBar('Failed to send verification code: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // STEP 2: Verify OTP Code
  Future<void> _handleVerifyCode() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();

    if (otp.isEmpty) {
      _showSnackBar('Please enter the 6-digit verification code');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.recovery,
      );

      if (response.session != null || response.user != null) {
        setState(() {
          _step = 2;
        });
        _showSnackBar('Code verified! Enter your new password.', isError: false);
      } else {
        _showSnackBar('Invalid verification code. Please try again.');
      }
    } catch (e) {
      _showSnackBar('Verification failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // STEP 3: Set New Password
  Future<void> _handleResetPassword() async {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.isEmpty) {
      _showSnackBar('Please enter a new password');
      return;
    }
    if (newPassword.length < 6) {
      _showSnackBar('Password must be at least 6 characters');
      return;
    }
    if (newPassword != confirmPassword) {
      _showSnackBar('Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      // 1. If this is an admin account, keep admin_users.password_hash in sync
      try {
        final email = _emailController.text.trim();
        final newBcryptHash = BCrypt.hashpw(newPassword, BCrypt.gensalt());
        await Supabase.instance.client.from('admin_users').update({
          'password_hash': newBcryptHash,
        }).eq('email', email);
      } catch (_) {}

      // 2. Sign out the temporary OTP recovery session so login screen starts fresh
      await Supabase.instance.client.auth.signOut();

      setState(() {
        _step = 3;
      });
    } catch (e) {
      _showSnackBar('Failed to update password: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleBack() {
    HapticFeedback.lightImpact();
    if (_step > 0 && _step < 3) {
      setState(() => _step--);
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF070D1A) : const Color(0xFFFFFFFF);
    final cardBg = isDark ? const Color(0x09FFFFFF) : const Color(0xFFFFFFFF);
    final cardBorder = isDark ? const Color(0x14FFFFFF) : const Color(0x1A000000);
    final text1 = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0A0F1C);
    final textSecondary = isDark ? const Color(0xFF4A6080) : const Color(0xFF4A5568);
    final backBtnBg = isDark ? const Color(0x0DFFFFFF) : const Color(0x0D000000);
    final backBtnBorder = isDark ? const Color(0x14FFFFFF) : const Color(0x1A000000);
    final backBtnIcon = isDark ? const Color(0xFF5A7090) : const Color(0xFF4A5568);
    final infoBg = isDark ? const Color(0x0F5B72F5) : const Color(0x0F5B72F5);
    final infoBorder = isDark ? const Color(0x265B72F5) : const Color(0x265B72F5);
    final infoText = isDark ? const Color(0xFF8AA0B8) : const Color(0xFF5A7090);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          if (isDark)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.2,
                    colors: [
                      Color(0x1AF5A623),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: cardBorder,
                          width: 1,
                        ),
                      ),
                      child: Stack(
                        children: [
                          if (isDark)
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 1,
                                decoration: const BoxDecoration(
                                  color: Color(0x26FFFFFF),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(24),
                                    topRight: Radius.circular(24),
                                  ),
                                ),
                              ),
                            ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 10),

                              // Header Navigation Row
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: _handleBack,
                                    child: Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: backBtnBg,
                                        borderRadius: BorderRadius.circular(9),
                                        border: Border.all(
                                          color: backBtnBorder,
                                          width: 1,
                                        ),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.arrow_back_rounded,
                                          color: backBtnIcon,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _step == 0
                                        ? 'Forgot Password'
                                        : (_step == 1
                                            ? 'Enter OTP Code'
                                            : (_step == 2
                                                ? 'New Password'
                                                : 'Success')),
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: text1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),

                              // STEP 0: Email Entry
                              if (_step == 0) ...[
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: const Color(0x1AF5A623),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0x33F5A623),
                                      width: 1.5,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x1AF5A623),
                                        blurRadius: 16,
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.key_rounded,
                                      color: Color(0xFFF5A623),
                                      size: 24,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Reset Password',
                                  style: GoogleFonts.outfit(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: text1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Enter your email to receive a verification code',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: infoBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: infoBorder,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.info_outline_rounded,
                                        color: Color(0xFF5B72F5),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          "We'll send a 6-digit verification code to your email address.",
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            height: 1.4,
                                            color: infoText,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _AuthField(
                                  label: 'EMAIL ADDRESS',
                                  hint: 'Enter your email',
                                  prefixIcon: Icons.email_rounded,
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  focusNode: _emailFocusNode,
                                ),
                                const SizedBox(height: 8),
                                _ResetButton(
                                  onTap: _isLoading ? null : _handleSendCode,
                                  isLoading: _isLoading,
                                  label: 'SEND VERIFICATION CODE',
                                ),
                              ]

                              // STEP 1: Verification Code (OTP) Entry
                              else if (_step == 1) ...[
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: const Color(0x1A5B72F5),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0x335B72F5),
                                      width: 1.5,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x1A5B72F5),
                                        blurRadius: 16,
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.mark_email_read_rounded,
                                      color: Color(0xFF5B72F5),
                                      size: 24,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Enter OTP Code',
                                  style: GoogleFonts.outfit(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: text1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Code sent to ${_emailController.text.trim()}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                _AuthField(
                                  label: 'VERIFICATION CODE',
                                  hint: 'Enter 6-digit code',
                                  prefixIcon: Icons.pin_rounded,
                                  controller: _otpController,
                                  keyboardType: TextInputType.number,
                                  focusNode: _otpFocusNode,
                                ),
                                const SizedBox(height: 8),
                                _ResetButton(
                                  onTap: _isLoading ? null : _handleVerifyCode,
                                  isLoading: _isLoading,
                                  label: 'VERIFY CODE',
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        setState(() => _step = 0);
                                      },
                                      child: Text(
                                        'Change Email',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF5B72F5),
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: _isLoading ? null : _handleSendCode,
                                      child: Text(
                                        'Resend Code',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFFF5A623),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ]

                              // STEP 2: Enter New Password
                              else if (_step == 2) ...[
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: const Color(0x1A10CBA0),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0x3310CBA0),
                                      width: 1.5,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x1A10CBA0),
                                        blurRadius: 16,
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.lock_reset_rounded,
                                      color: Color(0xFF10CBA0),
                                      size: 24,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'New Password',
                                  style: GoogleFonts.outfit(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: text1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Set a strong new password for your account',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                _AuthField(
                                  label: 'NEW PASSWORD',
                                  hint: 'Enter new password',
                                  prefixIcon: Icons.lock_outline_rounded,
                                  controller: _newPasswordController,
                                  keyboardType: TextInputType.visiblePassword,
                                  focusNode: _newPasswordFocusNode,
                                  obscureText: _obscureNewPass,
                                  suffixIcon: _obscureNewPass
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  onSuffixTap: () {
                                    setState(() => _obscureNewPass = !_obscureNewPass);
                                  },
                                ),
                                _AuthField(
                                  label: 'CONFIRM PASSWORD',
                                  hint: 'Re-enter new password',
                                  prefixIcon: Icons.lock_outline_rounded,
                                  controller: _confirmPasswordController,
                                  keyboardType: TextInputType.visiblePassword,
                                  focusNode: _confirmPasswordFocusNode,
                                  obscureText: _obscureConfirmPass,
                                  suffixIcon: _obscureConfirmPass
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  onSuffixTap: () {
                                    setState(() => _obscureConfirmPass = !_obscureConfirmPass);
                                  },
                                ),
                                const SizedBox(height: 8),
                                _ResetButton(
                                  onTap: _isLoading ? null : _handleResetPassword,
                                  isLoading: _isLoading,
                                  label: 'SET NEW PASSWORD',
                                ),
                              ]

                              // STEP 3: Success State Card
                              else ...[
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0x0A10CBA0),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0x2610CBA0),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: const BoxDecoration(
                                          color: Color(0x1A10CBA0),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.check_circle_outline_rounded,
                                            color: Color(0xFF10CBA0),
                                            size: 28,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Password Reset!',
                                        style: GoogleFonts.outfit(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF10CBA0),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Your password has been changed successfully. You can now sign in with your new password.',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: textSecondary,
                                          height: 1.4,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 32),
                                _ResetButton(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    context.go('/login');
                                  },
                                  isLoading: false,
                                  label: 'SIGN IN WITH NEW PASSWORD',
                                ),
                              ],

                              const SizedBox(height: 24),
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  context.pop();
                                },
                                child: Text(
                                  'Remember your password? Sign In',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFF5A7090) : const Color(0xFF4A5568),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
}

// ── CUSTOM AUTH FIELD WIDGET ───────────────────────────────────────────
class _AuthField extends StatefulWidget {
  final String label;
  final String hint;
  final IconData prefixIcon;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final FocusNode focusNode;
  final bool obscureText;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;

  const _AuthField({
    required this.label,
    required this.hint,
    required this.prefixIcon,
    required this.controller,
    required this.keyboardType,
    required this.focusNode,
    this.obscureText = false,
    this.suffixIcon,
    this.onSuffixTap,
  });

  @override
  State<_AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<_AuthField> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = widget.focusNode.hasFocus;
      });
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? const Color(0xFF3D5470) : const Color(0xFF94A3B8);
    final fieldBg = _isFocused
        ? (isDark ? const Color(0x08F5A623) : const Color(0x08D97706))
        : (isDark ? const Color(0x0AFFFFFF) : const Color(0xFFF4F6FA));
    final fieldBorderColor = _isFocused
        ? (isDark ? const Color(0x80F5A623) : const Color(0x80D97706))
        : (isDark ? const Color(0x14FFFFFF) : const Color(0x1A000000));
    final shadowColor = isDark ? const Color(0x14F5A623) : const Color(0x14D97706);
    final prefixIconColor = isDark ? const Color(0xFF2D4060) : const Color(0xFF94A3B8);
    final textColor = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0A0F1C);
    final hintColor = isDark ? const Color(0xFF1E3050) : const Color(0xFF94A3B8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: labelColor,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: fieldBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: fieldBorderColor,
              width: 1,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: shadowColor,
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: Row(
            children: [
              Icon(
                widget.prefixIcon,
                size: 18,
                color: prefixIconColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  keyboardType: widget.keyboardType,
                  obscureText: widget.obscureText,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: textColor,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: GoogleFonts.inter(
                      fontSize: 13,
                      color: hintColor,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (widget.suffixIcon != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: widget.onSuffixTap,
                  child: Icon(
                    widget.suffixIcon,
                    size: 18,
                    color: prefixIconColor,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── CUSTOM SCALE TRANSITION RESET BUTTON ───────────────────────────────
class _ResetButton extends StatefulWidget {
  final VoidCallback? onTap;
  final bool isLoading;
  final String label;

  const _ResetButton({
    required this.onTap,
    required this.isLoading,
    required this.label,
  });

  @override
  State<_ResetButton> createState() => _ResetButtonState();
}

class _ResetButtonState extends State<_ResetButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onTap == null;
    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => setState(() => _scale = 0.97),
      onTapUp: isDisabled
          ? null
          : (_) {
              setState(() => _scale = 1.0);
              HapticFeedback.lightImpact();
              widget.onTap!();
            },
      onTapCancel: isDisabled ? null : () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF5A623), Color(0xFFD97706)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66F5A623),
                blurRadius: 22,
                offset: Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF1A0A00),
                  ),
                )
              : Text(
                  widget.label.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A0A00),
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }
}
