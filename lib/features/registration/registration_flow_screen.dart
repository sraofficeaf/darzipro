import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/registration_service.dart';
import '../../core/utils/image_compressor.dart';
import '../../shared/widgets/pro_field.dart';
import '../../shared/widgets/pricing_plan_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Steps:
//  0 → Select Plan       (SaaS Pricing Cards)
//  1 → Basic Info        (Shop Name + Owner Name)
//  2 → Contact Info      (Email + Phone)
//  3 → Location & Invite (Address + Referral Checkbox) + submit to API
//  4 → Verify OTP
//  5 → Set Password
//  6 → Payment Proof
//  7 → Done ✅
// ─────────────────────────────────────────────────────────────────────────────

const int _kTotalSteps = 8;

const List<String> _kStepLabels = [
  'Plan', 'Shop', 'Contact', 'Location', 'OTP', 'Password', 'Payment', 'Done',
];

class RegistrationFlowScreen extends StatefulWidget {
  const RegistrationFlowScreen({super.key});

  @override
  State<RegistrationFlowScreen> createState() => _RegistrationFlowScreenState();
}

class _RegistrationFlowScreenState extends State<RegistrationFlowScreen>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  String _selectedPlan = 'full_access';
  String? _registrationId;
  String _email = '';
  String _shopName = '';
  bool _hasInviteCode = false;

  // Controllers
  final _shopNameCtrl    = TextEditingController();
  final _ownerNameCtrl   = TextEditingController();
  final _emailCtrl       = TextEditingController();
  final _phoneCtrl       = TextEditingController();
  final _addressCtrl     = TextEditingController();
  final _inviteCodeCtrl  = TextEditingController();
  final _otpCtrl         = TextEditingController();
  final _passwordCtrl    = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _obscurePass    = true;
  bool _obscureConfirm = true;

  // Payment
  Uint8List? _receiptBytes;
  String _paymentMethod = 'Easypaisa';

  bool _isLoading = false;
  String? _errorMessage;

  // Invite
  Timer? _debounce;
  bool _isValidatingInvite = false;
  bool? _isInviteValid;

  // Entrance animation
  late AnimationController _animCtrl;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _cardFade;
  late Animation<Offset> _cardSlide;

  // Plan data (Ordered: Basic -> Professional (middle) -> Enterprise)
  final List<Map<String, dynamic>> _plans = [
    {
      'id': 'mobile_only',
      'name': 'Basic Plan',
      'tabLabel': '📱 Basic',
      'price': 'Rs 12,000',
      'priceLabel': '/ one-time lifetime',
      'subtitle': 'Mobile App Only',
      'badge': 'STARTER',
      'isPopular': false,
      'badgeColor': const Color(0xFF3B82F6),
      'accentColor': const Color(0xFF3B82F6),
      'features': [
        'Android & iOS Mobile App',
        'Customer & Measurement Book',
        'Order Tracking & Job Slips',
        'WhatsApp & SMS Notifications',
        'Daily Sales & Expense Reports',
        'Offline & Fast Local Storage',
        'Level 1 Referral Bonus Profit',
        'Lifetime License (No Monthly Fees)',
      ],
    },
    {
      'id': 'full_access',
      'name': 'Professional Plan',
      'tabLabel': '🚀 Professional',
      'price': 'Rs 35,000',
      'priceLabel': '/ one-time lifetime',
      'subtitle': 'Web + Mobile + Windows Desktop',
      'badge': 'MOST POPULAR',
      'isPopular': true,
      'badgeColor': const Color(0xFF8B5CF6),
      'accentColor': const Color(0xFF6366F1),
      'features': [
        'Everything in Basic Plan',
        'Windows Desktop Native Application',
        'Web Portal Access (Any Browser)',
        'Thermal & POS Slip Printing',
        'Real-time Multi-device Sync',
        '100% Ad-Free Clean Workspace',
        'Level 1-2 Referral Multi-Profit',
        'Lifetime License + Free Updates',
      ],
    },
    {
      'id': 'full_access_3yr',
      'name': 'Enterprise Plan',
      'tabLabel': '👑 Enterprise',
      'price': 'Rs 70,000',
      'priceLabel': '/ one-time lifetime',
      'subtitle': 'All Apps + 3 Years Cloud',
      'badge': 'BEST VALUE',
      'isPopular': false,
      'badgeColor': const Color(0xFF10B981),
      'accentColor': const Color(0xFF10B981),
      'features': [
        'Everything in Professional Plan',
        '3 Years Unlimited Cloud Storage',
        'Multi-Staff & Worker Role Access',
        'Automated Daily Cloud Backups',
        'Barcode & Thermal Custom Header',
        'Max Level 1-4 Referral Profit',
        'VIP Priority 24/7 WhatsApp Support',
        'Lifetime Unlimited License',
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _inviteCodeCtrl.addListener(_onInviteChanged);

    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

    _logoScale = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack)));
    _logoFade = CurvedAnimation(parent: _animCtrl, curve: const Interval(0.0, 0.40, curve: Curves.easeOut));
    _titleFade = CurvedAnimation(parent: _animCtrl, curve: const Interval(0.18, 0.55, curve: Curves.easeOut));
    _titleSlide = Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _animCtrl, curve: const Interval(0.18, 0.60, curve: Curves.easeOutCubic)));
    _cardFade = CurvedAnimation(parent: _animCtrl, curve: const Interval(0.35, 0.80, curve: Curves.easeOut));
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
      CurvedAnimation(parent: _animCtrl, curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic)));

    _animCtrl.forward();
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose(); _ownerNameCtrl.dispose(); _emailCtrl.dispose();
    _phoneCtrl.dispose(); _addressCtrl.dispose(); _inviteCodeCtrl.dispose();
    _otpCtrl.dispose(); _passwordCtrl.dispose(); _confirmPassCtrl.dispose();
    _debounce?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _onInviteChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    final code = _inviteCodeCtrl.text.trim();
    if (code.isEmpty) { setState(() { _isInviteValid = null; _isValidatingInvite = false; }); return; }
    setState(() { _isValidatingInvite = true; _isInviteValid = null; });
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final valid = await RegistrationService.instance.validateInviteCode(code);
      if (mounted) setState(() { _isValidatingInvite = false; _isInviteValid = valid; });
    });
  }

  void _goNext() { HapticFeedback.lightImpact(); setState(() { _currentStep++; _errorMessage = null; }); }
  void _goPrev() { if (_currentStep > 0) { HapticFeedback.lightImpact(); setState(() { _currentStep--; _errorMessage = null; }); } }
  void _setError(String msg) => setState(() { _errorMessage = msg; _isLoading = false; });

  String get _selectedPlanPrice => (_plans.firstWhere((p) => p['id'] == _selectedPlan))['price'] as String;
  String get _selectedPlanName  => (_plans.firstWhere((p) => p['id'] == _selectedPlan))['name'] as String;

  // ── Step validators ───────────────────────────────────────────────────────
  void _submitStep1() {
    if (_shopNameCtrl.text.trim().isEmpty) { _setError('Please enter your shop name'); return; }
    if (_ownerNameCtrl.text.trim().isEmpty) { _setError('Please enter owner name'); return; }
    _goNext();
  }

  void _submitStep2() {
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) { _setError('Enter a valid email address'); return; }
    if (phone.length < 10 || !RegExp(r'^[0-9+\-\s]+$').hasMatch(phone)) { _setError('Enter a valid phone number'); return; }
    _goNext();
  }

  Future<void> _submitStep3() async {
    final address = _addressCtrl.text.trim();
    if (address.isEmpty) {
      _setError('Please enter shop address');
      return;
    }

    final code = _inviteCodeCtrl.text.trim();
    if (_hasInviteCode) {
      if (code.isEmpty) {
        _setError('Please enter your invite/referral code or uncheck the referral box');
        return;
      }
      setState(() { _isLoading = true; _errorMessage = null; });
      final isValid = await RegistrationService.instance.validateInviteCode(code);
      if (!isValid) {
        setState(() {
          _isLoading = false;
          _isInviteValid = false;
        });
        _setError('❌ Invalid invite code! Please enter a valid code or uncheck "I have a referral code"');
        return;
      }
    }

    setState(() { _isLoading = true; _errorMessage = null; });
    final validCode = (_hasInviteCode && code.isNotEmpty) ? code : null;

    final res = await RegistrationService.instance.createRegistration(
      shopName: _shopNameCtrl.text.trim(),
      ownerName: _ownerNameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: '',
      inviteCodeUsed: validCode,
      planSelected: _selectedPlan,
      phone: _phoneCtrl.text.trim(),
      address: address,
    );
    if (res['success'] == true) {
      _registrationId = res['id'];
      _email = _emailCtrl.text.trim();
      _shopName = _shopNameCtrl.text.trim();
      await RegistrationService.instance.sendOTP(email: _email, code: res['code'], shopName: _shopName);
      setState(() { _isLoading = false; });
      _goNext();
    } else {
      _setError(res['error'] ?? 'Registration failed');
    }
  }

  Future<void> _submitStep4() async {
    final code = _otpCtrl.text.trim();
    if (code.length < 6) { _setError('Enter the 6-digit code'); return; }
    setState(() { _isLoading = true; _errorMessage = null; });
    final res = await RegistrationService.instance.verifyOTP(
      registrationId: _registrationId!, code: code, email: _email);
    if (res['success'] == true) { setState(() { _isLoading = false; }); _goNext(); }
    else { _setError(res['error'] ?? 'Invalid code'); }
  }

  Future<void> _submitStep5() async {
    final pw = _passwordCtrl.text;
    if (pw.length < 6) { _setError('Password must be at least 6 characters'); return; }
    if (pw != _confirmPassCtrl.text) { _setError('Passwords do not match'); return; }
    setState(() { _isLoading = true; _errorMessage = null; });
    // SECURITY: Password is NOT stored in the database.
    // It will be set securely when admin approves via the Edge Function.
    setState(() { _isLoading = false; }); _goNext();
  }

  Future<void> _pickReceipt() async {
    try {
      final compressed = await ImageCompressor.pickAndCompress();
      if (compressed != null) setState(() { _receiptBytes = compressed; _errorMessage = null; });
    } catch (e) { _setError(e.toString().replaceAll('Exception: ', '')); }
  }

  Future<void> _submitStep6() async {
    if (_receiptBytes == null) { _setError('Please upload payment receipt'); return; }
    setState(() { _isLoading = true; _errorMessage = null; });
    final url = await RegistrationService.instance.uploadPaymentScreenshot(
      registrationId: _registrationId!, bytes: _receiptBytes!, filename: 'receipt.jpg');
    if (url == null) { _setError('Failed to upload receipt. Try again.'); return; }
    final res = await RegistrationService.instance.submitPaymentProof(
      registrationId: _registrationId!, screenshotUrl: url, paymentMethod: _paymentMethod);
    if (res['success'] == true) { setState(() { _isLoading = false; }); _goNext(); }
    else { _setError(res['error'] ?? 'Submission failed'); }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP BUILDERS
  // ═══════════════════════════════════════════════════════════════════════════

  // ── Step 0: Plan (Modern SaaS Pricing Cards) ──────────────────────────────
  Widget _buildStep0(bool isDark, Color text, Color sub) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _stepHeader('Select Your Plan', 'Choose the right software tier for your business', text, sub),
            const SizedBox(height: 18),

            if (isWide) ...[
              // Desktop / Tablet layout: 3 cards side-by-side
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _plans.map((plan) {
                  final isSelected = _selectedPlan == plan['id'];
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: PricingPlanCard(
                        planId: plan['id'] as String,
                        name: plan['name'] as String,
                        price: plan['price'] as String,
                        priceLabel: plan['priceLabel'] as String,
                        subtitle: plan['subtitle'] as String,
                        badge: plan['badge'] as String?,
                        isPopular: plan['isPopular'] == true,
                        isSelected: isSelected,
                        accentColor: plan['accentColor'] as Color,
                        features: List<String>.from(plan['features'] as List),
                        buttonText: isSelected ? 'Selected Plan' : 'Select Plan',
                        onSelect: () {
                          setState(() => _selectedPlan = plan['id'] as String);
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
            ] else ...[
              // Mobile layout: Segmented tab selector + Active Pricing Card
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131D2E) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2A3547) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: _plans.map((plan) {
                    final isSel = _selectedPlan == plan['id'];
                    final accent = plan['accentColor'] as Color;
                    final isPopular = plan['isPopular'] == true;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedPlan = plan['id'] as String);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            gradient: isSel
                                ? LinearGradient(
                                    colors: isPopular
                                        ? [const Color(0xFF8B5CF6), const Color(0xFF6366F1)]
                                        : [accent, accent.withValues(alpha: 0.85)],
                                  )
                                : null,
                            color: isSel ? null : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: isSel
                                ? [
                                    BoxShadow(
                                      color: accent.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Text(
                            plan['tabLabel'] as String? ?? plan['name'] as String,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                              color: isSel
                                  ? Colors.white
                                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              // Render currently selected card with full checklist
              Builder(
                builder: (context) {
                  final activePlan = _plans.firstWhere((p) => p['id'] == _selectedPlan);
                  return PricingPlanCard(
                    planId: activePlan['id'] as String,
                    name: activePlan['name'] as String,
                    price: activePlan['price'] as String,
                    priceLabel: activePlan['priceLabel'] as String,
                    subtitle: activePlan['subtitle'] as String,
                    badge: activePlan['badge'] as String?,
                    isPopular: activePlan['isPopular'] == true,
                    isSelected: true,
                    accentColor: activePlan['accentColor'] as Color,
                    features: List<String>.from(activePlan['features'] as List),
                    buttonText: 'Selected Plan ✓',
                    onSelect: () {},
                  );
                },
              ),
            ],

            const SizedBox(height: 18),
            _primaryButton('Continue with $_selectedPlanName', false, _goNext),
          ],
        );
      },
    );
  }

  // ── Step 1: Shop + Owner ───────────────────────────────────────────────────
  Widget _buildStep1(bool isDark, Color text, Color sub) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _stepHeader('Shop & Owner', 'Tell us about your tailor shop', text, sub),
      const SizedBox(height: 16),
      ProField(controller: _shopNameCtrl, label: 'Shop Name', hint: 'e.g. Mian Tailor House', icon: Icons.storefront_rounded),
      ProField(controller: _ownerNameCtrl, label: 'Owner Full Name', hint: 'e.g. Saifur Rahman', icon: Icons.person_rounded),
      _errorRow(), _primaryButton('Next Step', false, _submitStep1),
    ]);

  // ── Step 2: Contact ────────────────────────────────────────────────────────
  Widget _buildStep2(bool isDark, Color text, Color sub) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _stepHeader('Contact Details', 'How can we reach you?', text, sub),
      const SizedBox(height: 16),
      ProField(controller: _emailCtrl, label: 'Email Address', hint: 'yourshop@email.com',
          icon: Icons.email_rounded, keyboardType: TextInputType.emailAddress),
      ProField(controller: _phoneCtrl, label: 'Phone / WhatsApp', hint: '03XX-XXXXXXX',
          icon: Icons.phone_rounded, keyboardType: TextInputType.phone),
      _errorRow(), _primaryButton('Next Step', false, _submitStep2),
    ]);

  // ── Step 3: Location + Referral Code (Combined) ───────────────────────────
  Widget _buildStep3(bool isDark, Color text, Color sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader('Shop Location & Referral', 'Where is your shop located?', text, sub),
        const SizedBox(height: 16),

        ProField(
          controller: _addressCtrl,
          label: 'Shop Address',
          hint: 'Street, Market / Plaza, City, Province',
          icon: Icons.location_on_rounded,
          maxLines: 2,
        ),

        const SizedBox(height: 8),

        // ── Referral / Invite Code Checkbox ───────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131D2E) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF2A3547) : const Color(0xFFE2E8F0),
              width: 1.1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _hasInviteCode = !_hasInviteCode;
                    if (!_hasInviteCode) {
                      _inviteCodeCtrl.clear();
                      _isInviteValid = null;
                      _errorMessage = null;
                    }
                  });
                },
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: _hasInviteCode ? const Color(0xFF6366F1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _hasInviteCode
                              ? const Color(0xFF6366F1)
                              : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                          width: 1.8,
                        ),
                      ),
                      child: _hasInviteCode
                          ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'I have a referral / invite code',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: text,
                            ),
                          ),
                          Text(
                            'میرے پاس ریفرل یا انوائٹ کوڈ ہے (Optional)',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: sub,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Expandable Invite Code input
              if (_hasInviteCode) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isInviteValid == true
                          ? Colors.green
                          : (_isInviteValid == false
                              ? const Color(0xFFEF4444)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                      width: 1.3,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.confirmation_number_rounded,
                        size: 19,
                        color: _isInviteValid == true
                            ? Colors.green
                            : (_isInviteValid == false
                                ? const Color(0xFFEF4444)
                                : const Color(0xFFADB5C7)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _inviteCodeCtrl,
                          textCapitalization: TextCapitalization.characters,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: text,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter invite code (e.g. DARZI-XXXX)',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 13,
                              letterSpacing: 0,
                              color: isDark ? const Color(0xFF475569) : const Color(0xFFADB5C7),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      if (_isValidatingInvite)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_inviteCodeCtrl.text.trim().isNotEmpty && _isInviteValid != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Text(
                      _isInviteValid!
                          ? '✅ Valid Invite Code — referral bonus connected!'
                          : '❌ Invalid invite code! Please check code or uncheck above.',
                      style: GoogleFonts.inter(
                        color: _isInviteValid! ? Colors.green : const Color(0xFFEF4444),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Plan reminder pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0x18F5A623) : const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: const Color(0x35F5A623)),
          ),
          child: Row(
            children: [
              const Text('✂️', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Plan: $_selectedPlanName — $_selectedPlanPrice',
                  style: GoogleFonts.inter(
                    color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),
        _errorRow(),
        _primaryButton('Create Account & Verify', _isLoading, _submitStep3),
      ],
    );
  }

  // ── Step 4: OTP ────────────────────────────────────────────────────────────
  Widget _buildStep4(bool isDark, Color text, Color sub) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _stepHeader('Verify Email', 'Enter the 6-digit code sent to', text, sub),
      Text(_email, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700,
          color: const Color(0xFFF5A623)), textAlign: TextAlign.center),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131D2E) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? const Color(0xFF2A3547) : const Color(0xFFE2E8F0), width: 1.2),
        ),
        child: TextField(
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold,
              letterSpacing: 10, color: text),
          decoration: InputDecoration(
            hintText: '- - - - - -',
            hintStyle: GoogleFonts.inter(fontSize: 20, letterSpacing: 6, color: sub),
            counterText: '',
            border: InputBorder.none, isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
      const SizedBox(height: 20),
      _errorRow(),
      _primaryButton('Verify & Continue', _isLoading, _submitStep4),
    ]);
  }

  // ── Step 5: Password ───────────────────────────────────────────────────────
  Widget _buildStep5(bool isDark, Color text, Color sub) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _stepHeader('Set Password', 'Create a strong password for your account', text, sub),
      const SizedBox(height: 16),
      ProField(
        controller: _passwordCtrl, label: 'Create Password',
        hint: 'At least 6 characters', icon: Icons.lock_rounded, obscure: _obscurePass,
        suffix: GestureDetector(
          onTap: () { HapticFeedback.lightImpact(); setState(() => _obscurePass = !_obscurePass); },
          child: Icon(_obscurePass ? Icons.visibility_rounded : Icons.visibility_off_rounded,
              size: 18, color: isDark ? const Color(0xFF64748B) : const Color(0xFFADB5C7)),
        ),
      ),
      ProField(
        controller: _confirmPassCtrl, label: 'Confirm Password',
        hint: 'Re-enter your password', icon: Icons.lock_outline_rounded, obscure: _obscureConfirm,
        suffix: GestureDetector(
          onTap: () { HapticFeedback.lightImpact(); setState(() => _obscureConfirm = !_obscureConfirm); },
          child: Icon(_obscureConfirm ? Icons.visibility_rounded : Icons.visibility_off_rounded,
              size: 18, color: isDark ? const Color(0xFF64748B) : const Color(0xFFADB5C7)),
        ),
      ),
      _errorRow(),
      _primaryButton('Save & Continue', _isLoading, _submitStep5),
    ]);

  // ── Step 6: Payment ────────────────────────────────────────────────────────
  Widget _buildStep6(bool isDark, Color text, Color sub) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _stepHeader('Payment Proof', 'Transfer fee & upload receipt to activate', text, sub),
      const SizedBox(height: 14),

      // Bank details card
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131D2E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? const Color(0xFF2A3547) : const Color(0xFFE2E8F0)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0x20F5A623) : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Total: $_selectedPlanPrice',
                style: GoogleFonts.inter(color: const Color(0xFFF5A623), fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(height: 10),
          Text('Easypaisa: 0300-1234567', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: text)),
          const SizedBox(height: 3),
          Text('JazzCash: 0301-9876543', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: text)),
          const SizedBox(height: 8),
          Text('Transfer the exact amount and upload receipt below.', style: GoogleFonts.inter(color: sub, fontSize: 11.5)),
        ]),
      ),
      const SizedBox(height: 12),

      // Payment method tabs
      Row(children: ['Easypaisa', 'JazzCash', 'Bank'].map((m) {
        final sel = _paymentMethod == m || (m == 'Bank' && _paymentMethod == 'Bank Transfer');
        final realVal = m == 'Bank' ? 'Bank Transfer' : m;
        return Expanded(
          child: GestureDetector(
            onTap: () { HapticFeedback.selectionClick(); setState(() => _paymentMethod = realVal); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: sel ? const Color(0xFFF5A623) : (isDark ? const Color(0xFF131D2E) : Colors.white),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sel ? const Color(0xFFF5A623) : (isDark ? const Color(0xFF2A3547) : const Color(0xFFE2E8F0))),
              ),
              child: Text(m,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700,
                      color: sel ? Colors.white : sub),
                  textAlign: TextAlign.center),
            ),
          ),
        );
      }).toList()),
      const SizedBox(height: 12),

      // Receipt upload
      GestureDetector(
        onTap: _pickReceipt,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 96,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131D2E) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _receiptBytes != null ? const Color(0xFF22C55E) : (isDark ? const Color(0xFF2A3547) : const Color(0xFFCBD5E1)),
              width: _receiptBytes != null ? 2 : 1,
            ),
          ),
          child: _receiptBytes != null
              ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  ClipRRect(borderRadius: BorderRadius.circular(8),
                      child: Image.memory(_receiptBytes!, height: 62, width: 62, fit: BoxFit.cover)),
                  const SizedBox(width: 12),
                  Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 15),
                      const SizedBox(width: 5),
                      Text('Receipt Ready', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF22C55E), fontSize: 13)),
                    ]),
                    const SizedBox(height: 3),
                    Text('Tap to change', style: GoogleFonts.inter(fontSize: 11, color: sub)),
                  ]),
                ])
              : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.cloud_upload_outlined, color: Color(0xFFF5A623), size: 26),
                  const SizedBox(height: 4),
                  Text('Upload Receipt / Screenshot', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: text, fontSize: 13)),
                  Text('Auto-compressed • < 1MB', style: GoogleFonts.inter(color: sub, fontSize: 10.5)),
                ]),
        ),
      ),
      const SizedBox(height: 16),
      _errorRow(),
      _primaryButton('Submit Proof', _isLoading, _submitStep6),
    ]);
  }

  // ── Step 7: Done ───────────────────────────────────────────────────────────
  Widget _buildStep7(bool isDark, Color text, Color sub) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 4),
      Center(child: Container(
        width: 70, height: 70,
        decoration: const BoxDecoration(color: Color(0x1F22C55E), shape: BoxShape.circle),
        child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF22C55E), size: 44),
      )),
      const SizedBox(height: 14),
      Text('Registration Submitted!', style: GoogleFonts.outfit(fontSize: 21, fontWeight: FontWeight.bold, color: text), textAlign: TextAlign.center),
      const SizedBox(height: 3),
      Text('Thank you, $_shopName 🎉', style: GoogleFonts.inter(fontSize: 13.5, color: sub), textAlign: TextAlign.center),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131D2E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? const Color(0xFF2A3547) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          'Your registration is under review. You\'ll receive login credentials via email once approved — usually within 24 hours.',
          style: GoogleFonts.inter(fontSize: 13, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155), height: 1.55),
          textAlign: TextAlign.center,
        ),
      ),
      const SizedBox(height: 20),
      OutlinedButton(
        onPressed: () => context.go('/login'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: isDark ? const Color(0xFF2A3547) : const Color(0xFFE2E8F0)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        ),
        child: Text('Back to Login', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: text)),
      ),
    ]);

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARED UI HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _stepHeader(String title, String subtitle, Color text, Color sub) => Column(children: [
    Text(title, style: GoogleFonts.outfit(fontSize: 21, fontWeight: FontWeight.bold, color: text), textAlign: TextAlign.center),
    const SizedBox(height: 3),
    Text(subtitle, style: GoogleFonts.inter(fontSize: 12.5, color: sub), textAlign: TextAlign.center),
  ]);

  Widget _errorRow() {
    if (_errorMessage == null) return const SizedBox(height: 2);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12.5), textAlign: TextAlign.center),
    );
  }

  Widget _primaryButton(String label, bool loading, VoidCallback onTap) {
    return GestureDetector(
      onTap: loading ? null : () { HapticFeedback.lightImpact(); onTap(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 54,
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

  // ── Stepper (outside card) ─────────────────────────────────────────────────
  Widget _buildStepper(bool isDark) {
    return Column(children: [
      Row(children: List.generate(_kTotalSteps, (i) {
        final done   = i < _currentStep;
        final active = i == _currentStep;
        return Expanded(
          flex: i == _kTotalSteps - 1 ? 0 : 1,
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 20, height: 20,
              decoration: BoxDecoration(
                color: done || active ? const Color(0xFFF5A623)
                    : (isDark ? const Color(0xFF1E2D3E) : const Color(0xFFE2E8F0)),
                shape: BoxShape.circle,
                boxShadow: active ? const [BoxShadow(color: Color(0x55F5A623), blurRadius: 8)] : null,
              ),
              alignment: Alignment.center,
              child: done
                  ? const Icon(Icons.check_rounded, size: 11, color: Colors.white)
                  : Text('${i + 1}', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold,
                      color: active ? Colors.white : const Color(0xFF64748B))),
            ),
            if (i < _kTotalSteps - 1)
              Expanded(child: Container(
                height: 2, margin: const EdgeInsets.symmetric(horizontal: 1),
                color: done ? const Color(0xFFF5A623) : (isDark ? const Color(0xFF1E2D3E) : const Color(0xFFE2E8F0)),
              )),
          ]),
        );
      })),
      const SizedBox(height: 5),
      Text('Step ${_currentStep + 1} of $_kTotalSteps: ${_kStepLabels[_currentStep]}',
          style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFFF5A623))),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg       = isDark ? const Color(0xFF070D1A) : const Color(0xFFF8FAFC);
    final cardBg   = isDark ? const Color(0x0EFFFFFF) : const Color(0xFFFFFFFF);
    final cardBord = isDark ? const Color(0x1AFFFFFF) : const Color(0x12000000);
    final text1    = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0A0F1C);
    final sub      = isDark ? const Color(0xFF64748B) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(children: [
          // Ambient glow (dark mode)
          if (isDark)
            Positioned.fill(child: Container(
              decoration: const BoxDecoration(gradient: RadialGradient(
                center: Alignment(0, -0.4), radius: 1.1,
                colors: [Color(0x14F5A623), Colors.transparent],
              )),
            )),

          Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(left: 24, right: 24, top: 56, bottom: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: _currentStep == 0 ? 1040 : 484),
              child: Column(mainAxisSize: MainAxisSize.min, children: [

                // ── LOGO (outside card, animated) ──────────────────────────
                ScaleTransition(
                  scale: _logoScale,
                  child: FadeTransition(
                    opacity: _logoFade,
                    child: Container(
                      width: 68, height: 68,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                      ),
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

                // ── DARZI PRO TITLE (outside card) ─────────────────────────
                SlideTransition(
                  position: _titleSlide,
                  child: FadeTransition(
                    opacity: _titleFade,
                    child: Column(children: [
                      Text('Darzi Pro',
                          style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900,
                              color: text1, letterSpacing: -0.5)),
                      const SizedBox(height: 2),
                      Text('Register your tailor shop',
                          style: GoogleFonts.inter(fontSize: 12.5, color: sub, fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),

                // ── STEPPER (outside card - 70% width) ──────────────────────
                FadeTransition(
                  opacity: _titleFade,
                  child: FractionallySizedBox(
                    widthFactor: 0.70,
                    child: _buildStepper(isDark),
                  ),
                ),
                const SizedBox(height: 14),

                // ── MAIN CARD ───────────────────────────────────────────────
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
                            blurRadius: 28, offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(children: [
                        // Back button
                        if (_currentStep > 0 && _currentStep < 7)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: GestureDetector(
                              onTap: _goPrev,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.arrow_back_rounded, size: 15, color: sub),
                                  const SizedBox(width: 4),
                                  Text('Back', style: GoogleFonts.inter(fontSize: 12, color: sub, fontWeight: FontWeight.w600)),
                                ]),
                              ),
                            ),
                          ),

                        // Step content with slide animation
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, anim) => SlideTransition(
                            position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero)
                                .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                            child: FadeTransition(opacity: anim, child: child),
                          ),
                          child: KeyedSubtree(
                            key: ValueKey(_currentStep),
                            child: Builder(builder: (_) {
                              switch (_currentStep) {
                                case 0:  return _buildStep0(isDark, text1, sub);
                                case 1:  return _buildStep1(isDark, text1, sub);
                                case 2:  return _buildStep2(isDark, text1, sub);
                                case 3:  return _buildStep3(isDark, text1, sub);
                                case 4:  return _buildStep4(isDark, text1, sub);
                                case 5:  return _buildStep5(isDark, text1, sub);
                                case 6:  return _buildStep6(isDark, text1, sub);
                                case 7:  return _buildStep7(isDark, text1, sub);
                                default: return const SizedBox();
                              }
                            }),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    ),
  );
  }
}
