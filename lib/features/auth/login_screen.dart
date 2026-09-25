import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/build_info.dart';
import '../../shared/providers/admin_providers.dart';
import '../../shared/providers/subscription_provider.dart';
import '../../shared/providers/supabase_providers.dart';
import '../../shared/widgets/pro_field.dart';

import 'package:local_auth/local_auth.dart' show BiometricType;
import '../../core/services/biometric_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  bool _obscure = true;
  bool _isLoggingIn = false;

  final _emailController = TextEditingController(text: '');
  final _passwordController = TextEditingController(text: '');

  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  late AnimationController _animController;
  late Animation<double> _logoScaleAnim;
  late Animation<double> _logoFadeAnim;
  late Animation<double> _titleFadeAnim;
  late Animation<Offset> _titleSlideAnim;
  late Animation<double> _cardFadeAnim;
  late Animation<Offset> _cardSlideAnim;
  late Animation<double> _bannerFadeAnim;
  late Animation<Offset> _bannerSlideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );


    // 1. Logo pop & scale (0.0 to 0.45)
    _logoScaleAnim = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),

      ),
    );
    _logoFadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );

    // 2. App Name & Subtitle slide down (0.18 to 0.60)
    _titleFadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.18, 0.55, curve: Curves.easeOut),
    );
    _titleSlideAnim = Tween<Offset>(
      begin: const Offset(0, -0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.18, 0.60, curve: Curves.easeOutCubic),
    ));

    // 3. Main Card slide up & scale (0.35 to 0.85)
    _cardFadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.35, 0.80, curve: Curves.easeOut),
    );
    _cardSlideAnim = Tween<Offset>(
      begin: const Offset(0, 0.14),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic),
    ));

    // 4. Register Banner slide up (0.55 to 1.0)
    _bannerFadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.55, 0.95, curve: Curves.easeOut),
    );
    _bannerSlideAnim = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.55, 1.0, curve: Curves.easeOutCubic),
    ));

    _animController.forward();
  }


  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _isLoggingIn = true);
    try {
      final email = _emailController.text.trim();
      // SECURITY: Do not trim passwords — spaces can be valid characters
      final password = _passwordController.text;

      if (email.isEmpty || password.isEmpty) {
        throw Exception('Please enter email/phone and password');
      }

      // ── Step 1: Authenticate with Supabase Auth ──────────────────────────
      AuthResponse authResponse;
      try {
        authResponse = await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } on AuthException catch (authErr) {
        if (authErr.message.toLowerCase().contains('email not confirmed') ||
            authErr.code == 'email_not_confirmed') {
          if (mounted) {
            _showUnconfirmedEmailDialog(email);
          }
          return;
        }
        rethrow;
      }

      final user = authResponse.user;
      if (user == null) {
        throw Exception('Invalid login response from authentication server.');
      }

      // ── Step 2: Dynamic Admin Check (Database-driven via admin_users) ─────
      bool isAdminLoggedIn = false;
      try {
        final adminUser = await Supabase.instance.client
            .from('admin_users')
            .select('id, name, email, role')
            .eq('email', email)
            .maybeSingle();

        if (adminUser != null) {
          final adminName = (adminUser['name'] as String?) ?? 'Super Admin';
          ref.read(adminAuthProvider.notifier).setLoggedInAdmin(
                email: email,
                name: adminName,
              );
          isAdminLoggedIn = true;
        }
      } catch (adminErr) {
        debugPrint('Dynamic admin verification error: $adminErr');
      }

      if (isAdminLoggedIn) {
        if (mounted) {
          context.go('/admin');
        }
        return;
      }

      // Check shop status and prefetch subscription
      try {
        final profileData = await Supabase.instance.client
            .from('profiles')
            .select('shop_id, role, shops(status, plan_code)')
            .eq('id', user.id)
            .maybeSingle();

        if (profileData != null) {
          final role = (profileData['role'] as String?) ?? 'owner';

          if (role != 'super_admin' && role != 'admin') {
            final shopData = profileData['shops'] as Map<String, dynamic>?;
            final shopStatus = shopData?['status'] as String?;

            if (shopStatus == 'deleted') {
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'This account has been deleted and cannot be accessed.',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                    backgroundColor: const Color(0xFFFF3A58),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(16),
                  ),
                );
              }
              return;
            }
          }

          final shopId = profileData['shop_id'] as String?;
          if (shopId != null && shopId.isNotEmpty) {
            try {
              await ref
                  .read(subscriptionStateProvider.notifier)
                  .fetchForShop(shopId, forceRefresh: true);
              ref.invalidate(currentShopProvider);
              ref.invalidate(profileProvider);
            } catch (subErr) {
              debugPrint('Pre-login subscription fetch error: $subErr');
            }
          }
        } else if (!isAdminLoggedIn) {
          // Stranded account: user exists in auth.users, but registration RPC failed
          // so no profile or shop was created. Direct them to complete registration.
          if (mounted) {
            context.go('/registration-resume?email=${Uri.encodeComponent(email)}');
            return;
          }
        }
      } catch (platformErr) {
        debugPrint('Platform check error: $platformErr');
      }

      // Save credentials for quick biometric sign-in
      await BiometricService.instance.saveCredentials(
        email: email,
        password: password,
      );

      if (mounted) {
        context.go('/dashboard');
      }
    } catch (e) {
      if (e is AuthException &&
          (e.message.toLowerCase().contains('email not confirmed') ||
              e.code == 'email_not_confirmed')) {
        if (mounted) {
          _showUnconfirmedEmailDialog(_emailController.text.trim());
        }
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Text('⚠️ ', style: TextStyle(fontSize: 16)),
                Expanded(
                  child: Text(
                    'Login failed: ${e.toString().replaceAll('Exception:', '').trim()}',
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
              left: BorderSide(color: Color(0xFFFF3A58), width: 3),
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

  void _showUnconfirmedEmailDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isResending = false;
        String? feedbackMsg;
        bool isError = false;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.mark_email_unread_rounded, color: AppColors.accent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Email Not Confirmed',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your account email ($email) has not been confirmed yet.',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Please check your inbox (and spam folder) for the verification link. If you didn\'t receive it, tap below to resend.',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white60, height: 1.4),
                  ),
                  if (feedbackMsg != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isError
                            ? const Color(0xFFFF3A58).withValues(alpha: 0.15)
                            : const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        feedbackMsg!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isError ? const Color(0xFFFF3A58) : const Color(0xFF10B981),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Close', style: GoogleFonts.inter(color: Colors.white54)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isResending
                      ? null
                      : () async {
                          setDialogState(() {
                            isResending = true;
                            feedbackMsg = null;
                          });
                          try {
                            await Supabase.instance.client.auth.resend(
                              type: OtpType.signup,
                              email: email,
                              emailRedirectTo: kIsWeb
                                  ? 'https://darzipro.pk/#/login'
                                  : 'darzipro://login',
                            );
                            setDialogState(() {
                              isResending = false;
                              isError = false;
                              feedbackMsg = '✅ Confirmation email sent! Please check your inbox.';
                            });
                          } catch (err) {
                            setDialogState(() {
                              isResending = false;
                              isError = true;
                              feedbackMsg = 'Failed to resend: $err';
                            });
                          }
                        },
                  icon: isResending
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.send_rounded, size: 16),
                  label: Text(
                    isResending ? 'Sending...' : 'Resend Confirmation Email',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleBiometricLogin() async {
    HapticFeedback.heavyImpact();
    final service = BiometricService.instance;

    final canAuth = await service.canAuthenticate();
    if (!canAuth) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Fingerprint / Biometric authentication is not supported on this device.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13),
            ),
            backgroundColor: const Color(0xFF1A2A40),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final hasSaved = await service.hasSavedCredentials();
    if (!hasSaved) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please log in with Email & Password once to activate Biometric sign-in.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13),
            ),
            backgroundColor: const Color(0xFF1A2A40),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final authenticated = await service.authenticate(
      reason: 'Touch Fingerprint Sensor to log in to Darzi Pro',
    );

    if (authenticated) {
      HapticFeedback.vibrate();
      final creds = await service.getSavedCredentials();
      if (creds != null && mounted) {
        _emailController.text = creds['email'] ?? '';
        _passwordController.text = creds['password'] ?? '';
        _handleLogin();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF070D1A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0x0EFFFFFF) : const Color(0xFFFFFFFF);
    final cardBorder = isDark ? const Color(0x1AFFFFFF) : const Color(0x12000000);
    final text1 = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0A0F1C);
    final textSecondary = isDark ? const Color(0xFF64748B) : const Color(0xFF64748B);
    final textMuted = isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8);
    final accent = isDark ? const Color(0xFFF5A623) : const Color(0xFFD97706);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(
          children: [
            // Ambient background glow
            if (isDark)
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -0.4),
                      radius: 1.1,
                      colors: [
                        Color(0x18F5A623),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 24, right: 24, top: 56, bottom: 24),
                child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 462),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── 1. HEADER OUTSIDE CARD (Floating Brand) ──────────
                    ScaleTransition(
                      scale: _logoScaleAnim,
                      child: FadeTransition(
                        opacity: _logoFadeAnim,
                        child: Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Image.asset(
                              'assets/logo/app_logo.png',
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SlideTransition(
                      position: _titleSlideAnim,
                      child: FadeTransition(
                        opacity: _titleFadeAnim,
                        child: Column(
                          children: [
                            Text(
                              'Darzi Pro',
                              style: GoogleFonts.outfit(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: text1,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sign in to manage your shop',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── 2. MAIN LOGIN CARD (Tall, Spacious & Focused) ──────
                    SlideTransition(
                      position: _cardSlideAnim,
                      child: FadeTransition(
                        opacity: _cardFadeAnim,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: cardBorder,
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                                blurRadius: 32,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome Back 👋',
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: text1,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Enter your credentials to access your account',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 24),

                              ProField(
                                label: 'Email or Phone',
                                hint: 'yourshop@email.com',
                                icon: Icons.person_rounded,
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                focusNode: _emailFocusNode,
                              ),
                              ProField(
                                label: 'Password',
                                hint: 'Enter your password',
                                icon: Icons.lock_rounded,
                                obscure: _obscure,
                                controller: _passwordController,
                                keyboardType: TextInputType.visiblePassword,
                                focusNode: _passwordFocusNode,
                                suffix: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setState(() => _obscure = !_obscure);
                                  },
                                  child: Icon(
                                    _obscure
                                        ? Icons.visibility_rounded
                                        : Icons.visibility_off_rounded,
                                    size: 18,
                                    color: textMuted,
                                  ),
                                ),
                              ),

                              // FORGOT PASSWORD
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    context.push('/forgot-password');
                                  },
                                  child: Text(
                                    'Forgot Password?',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: accent,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // ── LOGIN & BIOMETRIC BUTTON ROW ─────────
                              Row(
                                children: [
                                  Expanded(
                                    child: _LoginButton(
                                      onTap: _isLoggingIn ? null : _handleLogin,
                                      isLoading: _isLoggingIn,
                                      label: 'LOGIN',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _BiometricButton(
                                    onTap: _handleBiometricLogin,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── 3. OUTSIDE CARD (New Shop Register Banner) ──────
                    SlideTransition(
                      position: _bannerSlideAnim,
                      child: FadeTransition(
                        opacity: _bannerFadeAnim,
                        child: _RegisterBanner(
                          onTap: () {
                            context.push('/join');
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // SECURE FOOTER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_outlined, size: 14, color: textMuted),
                        const SizedBox(width: 6),
                        Text(
                          'Enterprise-grade encryption & biometric security',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      BuildInfo.fullBuildTag,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: textMuted.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  }
}







// _AuthField replaced by shared ProField widget (lib/shared/widgets/pro_field.dart)

// ── CUSTOM SCALE TRANSITION LOGIN BUTTON ───────────────────────────────
class _LoginButton extends StatefulWidget {
  final VoidCallback? onTap;
  final bool isLoading;
  final String label;

  const _LoginButton({
    required this.onTap,
    required this.isLoading,
    required this.label,
  });

  @override
  State<_LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<_LoginButton> {
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
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF5A623), Color(0xFFD97706)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55F5A623),
                blurRadius: 20,
                offset: Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF1A0A00),
                  ),
                )
              : Text(
                  widget.label.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A0A00),
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }
}

// ── PRO BIOMETRIC BUTTON (DYNAMICAL FINGERPRINT / FACE ID) ────────────────
class _BiometricButton extends StatefulWidget {
  final VoidCallback onTap;

  const _BiometricButton({required this.onTap});

  @override
  State<_BiometricButton> createState() => _BiometricButtonState();
}

class _BiometricButtonState extends State<_BiometricButton> {
  IconData _icon = Icons.fingerprint_rounded;

  @override
  void initState() {
    super.initState();
    _checkType();
  }

  Future<void> _checkType() async {
    final type = await BiometricService.instance.getPrimaryBiometricType();
    if (type == BiometricType.face && mounted) {
      setState(() => _icon = Icons.face_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFFF5A623) : const Color(0xFFD97706);
    final btnBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return InkWell(
      onTap: () {
        HapticFeedback.heavyImpact();
        widget.onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: btnBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.10),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: accent.withValues(alpha: isDark ? 0.25 : 0.15),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            _icon,
            size: 34,
            color: accent,
          ),
        ),
      ),
    );
  }
}




// ── CLEAN CARDLESS REGISTER SHOP LINK ROW ──────────────────────────────
class _RegisterBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _RegisterBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0A0F1C);
    final subColor = const Color(0xFF64748B);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_business_rounded,
              size: 16,
              color: subColor,
            ),
            const SizedBox(width: 8),
            RichText(
              text: TextSpan(
                style: GoogleFonts.inter(fontSize: 12.5, color: subColor),
                children: [
                  const TextSpan(text: 'New Shop Owner? '),
                  TextSpan(
                    text: 'Register Your Shop',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_forward_rounded,
              size: 14,
              color: accentColor,
            ),
          ],
        ),
      ),
    );
  }
}




