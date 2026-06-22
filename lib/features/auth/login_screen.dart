import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/shared_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscure = true;
  String _selectedLang = 'English';
  bool _isLoggingIn = false;
  
  final _emailController = TextEditingController(text: 'test@darzipro.com');
  final _passwordController = TextEditingController(text: 'password');

  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(() => setState(() {}));
    _passwordFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    HapticFeedback.lightImpact();
    setState(() => _isLoggingIn = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (mounted) {
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        // Success/Error SnackBar matching guidelines:
        // bg Color(0xFF1A2A40), left border Color(0xFFFF3A58) 3px (Error)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Text('⚠️ ', style: TextStyle(fontSize: 16)),
                Expanded(
                  child: Text(
                    'Login failed: ${e.toString()}',
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
            shape: const Border(
              left: BorderSide(color: AppColors.red, width: 3),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoggingIn = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final text2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final text3 = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
    final accentCol = isDark ? AppColors.accent : AppColors.accentL;

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 380,
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo box
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: const Color(0x25F5A623),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFFF5A623).withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x25F5A623),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('✂️', style: TextStyle(fontSize: 34)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  GradientText(
                    'Darzi Pro',
                    style: GoogleFonts.outfit(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                    colors: const [Color(0xFFF5A623), Color(0xFFFFD080)],
                  ),
                  const SizedBox(height: 6),
                  
                  // Subtitle
                  Text(
                    'Sign in to manage your shop',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: text2,
                    ),
                  ),
                  const SizedBox(height: 28),

                  AppTextField(
                    label: 'PHONE NUMBER OR EMAIL',
                    focusNode: _emailFocusNode,
                    controller: _emailController,
                    prefix: Icon(
                      Icons.person_outline_rounded,
                      size: 18,
                      color: text3,
                    ),
                    hint: 'test@darzipro.com',
                  ),
                  const SizedBox(height: 2),

                  AppTextField(
                    label: 'PASSWORD',
                    focusNode: _passwordFocusNode,
                    controller: _passwordController,
                    obscureText: _obscure,
                    prefix: Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: text3,
                    ),
                    hint: '••••••••',
                    suffix: IconButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() => _obscure = !_obscure);
                      },
                      icon: Icon(
                        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 18,
                        color: text3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Forgot password
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                      },
                      child: Text(
                        'Forgot Password?',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: accentCol,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Login button
                  GoldButton(
                    width: double.infinity,
                    height: 48,
                    borderRadius: 24,
                    onPressed: _isLoggingIn ? null : _handleLogin,
                    child: _isLoggingIn
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF1A0F00),
                            ),
                          )
                        : Text(
                            'LOGIN',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                              color: const Color(0xFF1A0F00),
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),

                  // "OR" Divider
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: isDark ? const Color(0x12FFFFFF) : const Color(0x0D0F172A),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          'OR',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: text3,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: isDark ? const Color(0x12FFFFFF) : const Color(0x0D0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Biometric Button
                  BiometricButton(
                    onTap: () {
                      // Trigger biometric action
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'BIOMETRIC',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: text2,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Language selector
                  AppCard(
                    padding: const EdgeInsets.all(5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _langBtn('English', isDark, accentCol, text2),
                        _langBtn('اردو', isDark, accentCol, text2),
                        _langBtn('پښتو', isDark, accentCol, text2),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Secure text
                  Text(
                    'Securely access your shop records with enterprise-grade encryption.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: text3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }



  Widget _langBtn(String label, bool isDark, Color accentColor, Color text2Color) {
    final isActive = _selectedLang == label;
    final activeBg = isDark ? const Color(0x14FFFFFF) : const Color(0x0D0F172A);
    final activeBorder = isDark ? const Color(0x2EFFFFFF) : const Color(0x240F172A);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedLang = label);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? activeBorder : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isActive ? accentColor : text2Color,
          ),
        ),
      ),
    );
  }
}

class BiometricButton extends StatefulWidget {
  final VoidCallback onTap;

  const BiometricButton({super.key, required this.onTap});

  @override
  State<BiometricButton> createState() => _BiometricButtonState();
}

class _BiometricButtonState extends State<BiometricButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0x09FFFFFF) : const Color(0x0F000000);
    final border = isDark ? const Color(0x1FFFFFFF) : const Color(0x1F000000);

    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.92),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 1.5),
          ),
          child: const Center(
            child: Icon(
              Icons.fingerprint_rounded,
              size: 28,
              color: Color(0xFFF5A623),
            ),
          ),
        ),
      ),
    );
  }
}

class GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final List<Color> colors;

  const GradientText(
    this.text, {
    super.key,
    required this.style,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & bounds.size),
      child: Text(
        text,
        style: style.copyWith(color: Colors.white),
      ),
    );
  }
}
