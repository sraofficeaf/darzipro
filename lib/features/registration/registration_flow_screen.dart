import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/registration_service.dart';
import '../../shared/widgets/pro_field.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Free Trial Registration Flow (Phase 7 — Overhaul):
//  Step 0 → Shop & Owner (Shop Name, Owner Name, Phone / WhatsApp)
//  Step 1 → Location & Referral (Address, City, Referral Code optional)
//  Step 2 → Account Credentials (Email, Password, Confirm Password)
//  Step 3 → Done 🎉 Instant Access on Free Trial
// ─────────────────────────────────────────────────────────────────────────────

const int _kTotalSteps = 4;

const List<String> _kStepLabels = [
  'Shop', 'Location', 'Account', 'Ready',
];

class RegistrationFlowScreen extends StatefulWidget {
  const RegistrationFlowScreen({super.key});

  @override
  State<RegistrationFlowScreen> createState() => _RegistrationFlowScreenState();
}

class _RegistrationFlowScreenState extends State<RegistrationFlowScreen>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  bool _hasInviteCode = false;

  // Controllers
  final _shopNameCtrl    = TextEditingController();
  final _ownerNameCtrl   = TextEditingController();
  final _phoneCtrl       = TextEditingController();
  final _cityCtrl        = TextEditingController();
  final _addressCtrl     = TextEditingController();
  final _inviteCodeCtrl  = TextEditingController();
  final _emailCtrl       = TextEditingController();
  final _passwordCtrl    = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  bool _isLoading      = false;
  String? _errorMessage;

  // Invite validation
  Timer? _debounce;
  bool _isValidatingInvite = false;
  bool? _isInviteValid;

  // Entrance animations
  late AnimationController _animCtrl;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _cardFade;
  late Animation<Offset> _cardSlide;

  @override
  void initState() {
    super.initState();
    _inviteCodeCtrl.addListener(_onInviteChanged);

    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack)),
    );
    _logoFade = CurvedAnimation(parent: _animCtrl, curve: const Interval(0.0, 0.40, curve: Curves.easeOut));
    _titleFade = CurvedAnimation(parent: _animCtrl, curve: const Interval(0.18, 0.55, curve: Curves.easeOut));
    _titleSlide = Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _animCtrl, curve: const Interval(0.18, 0.60, curve: Curves.easeOutCubic)),
    );
    _cardFade = CurvedAnimation(parent: _animCtrl, curve: const Interval(0.35, 0.80, curve: Curves.easeOut));
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
      CurvedAnimation(parent: _animCtrl, curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic)),
    );

    _animCtrl.forward();
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    _inviteCodeCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPassCtrl.dispose();
    _debounce?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  void _onInviteChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    final code = _inviteCodeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() { _isInviteValid = null; _isValidatingInvite = false; });
      return;
    }
    setState(() { _isValidatingInvite = true; _isInviteValid = null; });
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final valid = await RegistrationService.instance.validateInviteCode(code);
      if (mounted) setState(() { _isValidatingInvite = false; _isInviteValid = valid; });
    });
  }

  void _goNext() {
    HapticFeedback.lightImpact();
    setState(() { _currentStep++; _errorMessage = null; });
  }

  void _goPrev() {
    if (_currentStep > 0) {
      HapticFeedback.lightImpact();
      setState(() { _currentStep--; _errorMessage = null; });
    }
  }

  void _setError(String msg) => setState(() { _errorMessage = msg; _isLoading = false; });

  // ── Step validators ───────────────────────────────────────────────────────
  void _submitStep0() {
    if (_shopNameCtrl.text.trim().isEmpty) { _setError('Please enter your shop name'); return; }
    if (_ownerNameCtrl.text.trim().isEmpty) { _setError('Please enter owner name'); return; }
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 10 || !RegExp(r'^[0-9+\-\s]+$').hasMatch(phone)) {
      _setError('Please enter a valid phone/WhatsApp number');
      return;
    }
    _goNext();
  }

  Future<void> _submitStep1() async {
    final address = _addressCtrl.text.trim();
    if (address.isEmpty) {
      _setError('Please enter shop address');
      return;
    }

    final code = _inviteCodeCtrl.text.trim();
    if (_hasInviteCode) {
      if (code.isEmpty) {
        _setError('Please enter your referral code or uncheck the referral box');
        return;
      }
      setState(() { _isLoading = true; _errorMessage = null; });
      final isValid = await RegistrationService.instance.validateInviteCode(code);
      if (!isValid) {
        setState(() {
          _isLoading = false;
          _isInviteValid = false;
        });
        _setError('❌ Invalid invite code! Please check code or untick referral box.');
        return;
      }
    }

    setState(() { _isLoading = false; _errorMessage = null; });
    _goNext();
  }

  Future<void> _submitStep2() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm = _confirmPassCtrl.text;

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      _setError('Enter a valid email address');
      return;
    }
    if (password.length < 6) {
      _setError('Password must be at least 6 characters');
      return;
    }
    if (password != confirm) {
      _setError('Passwords do not match');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    final code = _inviteCodeCtrl.text.trim();
    final invite = (_hasInviteCode && code.isNotEmpty) ? code : null;

    final res = await RegistrationService.instance.registerFreeTrial(
      email: email,
      password: password,
      shopName: _shopNameCtrl.text.trim(),
      ownerName: _ownerNameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      city: _cityCtrl.text.trim().isNotEmpty ? _cityCtrl.text.trim() : null,
      inviteCode: invite,
    );

    if (res['success'] == true) {
      setState(() { _isLoading = false; });
      _goNext();
    } else {
      _setError(res['error'] ?? 'Sign-up failed. Please try again.');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP BUILDERS
  // ═══════════════════════════════════════════════════════════════════════════

  // ── Step 0: Shop & Owner ───────────────────────────────────────────────────
  Widget _buildStep0(bool isDark, Color text, Color sub) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _stepHeader('Shop & Owner', 'Start your 14-day free trial — no payment required', text, sub),
      const SizedBox(height: 16),
      // Trial highlight banner
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0x1810B981) : const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Text('🎁', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Free Trial: 14 Days · 20 Orders · Full Features · Rs 0',
                style: GoogleFonts.inter(
                  color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      ProField(controller: _shopNameCtrl, label: 'Shop Name', hint: 'e.g. Al-Madina Tailors', icon: Icons.storefront_rounded),
      ProField(controller: _ownerNameCtrl, label: 'Owner Full Name', hint: 'e.g. Muhammad Aslam', icon: Icons.person_rounded),
      ProField(controller: _phoneCtrl, label: 'Phone / WhatsApp', hint: '03XX-XXXXXXX', icon: Icons.phone_rounded, keyboardType: TextInputType.phone),
      _errorRow(),
      _primaryButton('Continue to Location', false, _submitStep0),
    ],
  );

  // ── Step 1: Location & Referral ───────────────────────────────────────────
  Widget _buildStep1(bool isDark, Color text, Color sub) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _stepHeader('Location & Referral', 'Where is your shop located?', text, sub),
      const SizedBox(height: 16),
      ProField(controller: _cityCtrl, label: 'City', hint: 'e.g. Peshawar, Lahore, Karachi', icon: Icons.location_city_rounded),
      ProField(
        controller: _addressCtrl,
        label: 'Shop Address',
        hint: 'Street, Market / Plaza, Shop No.',
        icon: Icons.location_on_rounded,
        maxLines: 2,
      ),
      const SizedBox(height: 8),
      InkWell(
        onTap: () => setState(() => _hasInviteCode = !_hasInviteCode),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: _hasInviteCode,
                  onChanged: (v) => setState(() => _hasInviteCode = v ?? false),
                  activeColor: AppColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'I have a referral / invite code',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: text),
              ),
            ],
          ),
        ),
      ),
      if (_hasInviteCode) ...[
        const SizedBox(height: 8),
        ProField(
          controller: _inviteCodeCtrl,
          label: 'Invite Code',
          hint: 'Enter 6-character code (e.g. DARZ77)',
          icon: Icons.card_giftcard_rounded,
          suffix: _isValidatingInvite
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : _isInviteValid == true
                  ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20)
                  : _isInviteValid == false
                      ? const Icon(Icons.cancel_rounded, color: Colors.red, size: 20)
                      : null,
        ),
      ],
      _errorRow(),
      _primaryButton('Continue to Account', false, _submitStep1),
    ],
  );

  // ── Step 2: Account Login Credentials ─────────────────────────────────────
  Widget _buildStep2(bool isDark, Color text, Color sub) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _stepHeader('Account & Login', 'Set your login email and secure password', text, sub),
      const SizedBox(height: 16),
      ProField(
        controller: _emailCtrl,
        label: 'Email Address',
        hint: 'yourshop@email.com',
        icon: Icons.email_rounded,
        keyboardType: TextInputType.emailAddress,
      ),
      ProField(
        controller: _passwordCtrl,
        label: 'Password',
        hint: 'At least 6 characters',
        icon: Icons.lock_rounded,
        obscure: _obscurePass,
        suffix: GestureDetector(
          onTap: () => setState(() => _obscurePass = !_obscurePass),
          child: Icon(_obscurePass ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 18, color: sub),
        ),
      ),
      ProField(
        controller: _confirmPassCtrl,
        label: 'Confirm Password',
        hint: 'Re-enter your password',
        icon: Icons.lock_outline_rounded,
        obscure: _obscureConfirm,
        suffix: GestureDetector(
          onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
          child: Icon(_obscureConfirm ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 18, color: sub),
        ),
      ),
      _errorRow(),
      _primaryButton('Create Account & Start Trial', _isLoading, _submitStep2),
    ],
  );

  // ── Step 3: Success — Instant Free Trial ──────────────────────────────────
  Widget _buildStep3(bool isDark, Color text, Color sub) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.14),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4), width: 2),
        ),
        child: const Text('🎉', style: TextStyle(fontSize: 34)),
      ),
      const SizedBox(height: 16),
      Text(
        'Free Trial Activated!',
        style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: text),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      Text(
        'Welcome to Darzi Pro! Your shop has been created and your 14-day Free Trial is now active.',
        style: GoogleFonts.inter(fontSize: 13, color: sub, height: 1.5),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0x12FFFFFF) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? const Color(0x1EFFFFFF) : const Color(0xFFCBD5E1)),
        ),
        child: Column(
          children: [
            _summaryRow('Plan', 'Free Trial (14 Days)'),
            const Divider(height: 14),
            _summaryRow('Order Quota', '20 Orders'),
            const Divider(height: 14),
            _summaryRow('Initial Price', 'Rs 0 (Free)'),
            const Divider(height: 14),
            _summaryRow('Auto-Upgrade', 'Dual-Metric Enabled'),
          ],
        ),
      ),
      const SizedBox(height: 22),
      _primaryButton('Enter Shop Dashboard 🚀', false, () => context.go('/dashboard')),
      const SizedBox(height: 12),
      TextButton(
        onPressed: () => context.go('/login'),
        child: Text('Go to Login Screen', style: GoogleFonts.inter(fontSize: 13, color: sub)),
      ),
    ],
  );

  Widget _summaryRow(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
      Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
    ],
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARED UI HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _stepHeader(String title, String subtitle, Color text, Color sub) => Column(
    children: [
      Text(title, style: GoogleFonts.outfit(fontSize: 21, fontWeight: FontWeight.bold, color: text), textAlign: TextAlign.center),
      const SizedBox(height: 3),
      Text(subtitle, style: GoogleFonts.inter(fontSize: 12.5, color: sub), textAlign: TextAlign.center),
    ],
  );

  Widget _errorRow() {
    if (_errorMessage == null) return const SizedBox(height: 6);
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12.5), textAlign: TextAlign.center),
    );
  }

  Widget _primaryButton(String label, bool loading, VoidCallback onTap) {
    return GestureDetector(
      onTap: loading ? null : () { HapticFeedback.lightImpact(); onTap(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFF5A623), Color(0xFFD97706)]),
          borderRadius: BorderRadius.circular(13),
          boxShadow: const [BoxShadow(color: Color(0x44F5A623), blurRadius: 14, offset: Offset(0, 5))],
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Color(0xFF1A0A00), strokeWidth: 2.5))
            : Text(label, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF1A0A00))),
      ),
    );
  }

  Widget _buildStepper(bool isDark) {
    return Column(
      children: [
        Row(
          children: List.generate(_kTotalSteps, (i) {
            final done   = i < _currentStep;
            final active = i == _currentStep;
            return Expanded(
              flex: i == _kTotalSteps - 1 ? 0 : 1,
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: done || active
                          ? const Color(0xFFF5A623)
                          : (isDark ? const Color(0xFF1E2D3E) : const Color(0xFFE2E8F0)),
                      shape: BoxShape.circle,
                      boxShadow: active ? const [BoxShadow(color: Color(0x55F5A623), blurRadius: 8)] : null,
                    ),
                    alignment: Alignment.center,
                    child: done
                        ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                        : Text('${i + 1}',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: active ? Colors.white : const Color(0xFF64748B),
                            )),
                  ),
                  if (i < _kTotalSteps - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        color: done
                            ? const Color(0xFFF5A623)
                            : (isDark ? const Color(0xFF1E2D3E) : const Color(0xFFE2E8F0)),
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          'Step ${_currentStep + 1} of $_kTotalSteps: ${_kStepLabels[_currentStep]}',
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFF5A623)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final bg       = isDark ? const Color(0xFF070D1A) : const Color(0xFFF8FAFC);
    final cardBg   = isDark ? const Color(0x0EFFFFFF) : const Color(0xFFFFFFFF);
    final cardBord = isDark ? const Color(0x1AFFFFFF) : const Color(0x12000000);
    final text1    = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0A0F1C);
    final sub      = isDark ? const Color(0xFF64748B) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(
          children: [
            if (isDark)
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -0.4),
                      radius: 1.1,
                      colors: [Color(0x14F5A623), Colors.transparent],
                    ),
                  ),
                ),
              ),

            Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 24, right: 24, top: 48, bottom: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 484),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      ScaleTransition(
                        scale: _logoScale,
                        child: FadeTransition(
                          opacity: _logoFade,
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.asset(
                                'assets/logo/app_logo.png',
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Title
                      SlideTransition(
                        position: _titleSlide,
                        child: FadeTransition(
                          opacity: _titleFade,
                          child: Column(
                            children: [
                              Text(
                                'Darzi Pro',
                                style: GoogleFonts.outfit(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: text1,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Free Tailor Shop Registration',
                                style: GoogleFonts.inter(fontSize: 12.5, color: sub, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Stepper
                      FadeTransition(
                        opacity: _titleFade,
                        child: FractionallySizedBox(
                          widthFactor: 0.75,
                          child: _buildStepper(isDark),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Card
                      SlideTransition(
                        position: _cardSlide,
                        child: FadeTransition(
                          opacity: _cardFade,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: cardBord, width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.06),
                                  blurRadius: 28,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                if (_currentStep > 0 && _currentStep < 3)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: GestureDetector(
                                      onTap: _goPrev,
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.arrow_back_rounded, size: 15, color: sub),
                                            const SizedBox(width: 4),
                                            Text('Back', style: GoogleFonts.inter(fontSize: 12, color: sub, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  transitionBuilder: (child, anim) => SlideTransition(
                                    position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero)
                                        .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                                    child: FadeTransition(opacity: anim, child: child),
                                  ),
                                  child: KeyedSubtree(
                                    key: ValueKey(_currentStep),
                                    child: Builder(
                                      builder: (_) {
                                        switch (_currentStep) {
                                          case 0:  return _buildStep0(isDark, text1, sub);
                                          case 1:  return _buildStep1(isDark, text1, sub);
                                          case 2:  return _buildStep2(isDark, text1, sub);
                                          case 3:  return _buildStep3(isDark, text1, sub);
                                          default: return const SizedBox();
                                        }
                                      },
                                    ),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
