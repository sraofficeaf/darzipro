import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/registration_service.dart';
import '../../shared/widgets/pro_field.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RegistrationResumeScreen
//
// Shown when: a user is authenticated (has a Supabase session) but has no
// profiles row — meaning their previous registration attempt created an auth
// account but the shop setup failed (RPC error, network drop, etc.).
//
// Options presented:
//   1. Complete Registration — re-enters shop details and calls the same
//      register_new_shop_free_trial RPC (email pre-filled, not editable).
//   2. Sign out — clears the dangling session and returns to /login.
// ─────────────────────────────────────────────────────────────────────────────
class RegistrationResumeScreen extends StatefulWidget {
  /// The email pre-filled from the stranded auth account.
  final String email;

  const RegistrationResumeScreen({super.key, required this.email});

  @override
  State<RegistrationResumeScreen> createState() => _RegistrationResumeScreenState();
}

class _RegistrationResumeScreenState extends State<RegistrationResumeScreen> {
  final _shopNameCtrl    = TextEditingController();
  final _ownerNameCtrl   = TextEditingController();
  final _phoneCtrl       = TextEditingController();
  final _addressCtrl     = TextEditingController();
  final _cityCtrl        = TextEditingController();

  bool _isLoading   = false;
  bool _isSigningOut = false;
  String? _error;

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  void _setError(String msg) => setState(() { _error = msg; _isLoading = false; });

  Future<void> _complete() async {
    final shopName  = _shopNameCtrl.text.trim();
    final ownerName = _ownerNameCtrl.text.trim();
    final phone     = _phoneCtrl.text.trim();
    final address   = _addressCtrl.text.trim();

    if (shopName.isEmpty)  { _setError('Please enter your shop name'); return; }
    if (ownerName.isEmpty) { _setError('Please enter your name'); return; }
    if (phone.length < 10 || !RegExp(r'^[0-9+\-\s]+$').hasMatch(phone)) {
      _setError('Please enter a valid phone number'); return;
    }
    if (address.isEmpty) { _setError('Please enter your shop address'); return; }

    setState(() { _isLoading = true; _error = null; });
    HapticFeedback.lightImpact();

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _setError('Session expired. Please sign in again.');
      return;
    }

    final res = await RegistrationService.instance.completeStrandedRegistration(
      shopName:  shopName,
      ownerName: ownerName,
      phone:     phone,
      address:   address,
      city:      _cityCtrl.text.trim().isNotEmpty ? _cityCtrl.text.trim() : null,
    );

    if (res['success'] == true) {
      setState(() => _isLoading = false);
      if (mounted) context.go('/dashboard');
    } else {
      _setError(res['error'] ?? 'Setup failed. Please try again.');
    }
  }

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    await Supabase.instance.client.auth.signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF070D1A) : const Color(0xFFF8FAFC);
    final text1  = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0A0F1C);
    final sub    = const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0x0EFFFFFF) : Colors.white;
    final cardBd = isDark ? const Color(0x1AFFFFFF) : const Color(0x12000000);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Icon ──────────────────────────────────────────────────
                  Center(
                    child: Container(
                      width: 64, height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5A623).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFF5A623).withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: const Text('⚠️', style: TextStyle(fontSize: 28)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Heading ───────────────────────────────────────────────
                  Text(
                    'Complete Your Registration',
                    style: GoogleFonts.outfit(
                      fontSize: 22, fontWeight: FontWeight.w900, color: text1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your account was created (${widget.email}) but shop setup '
                    'did not complete. Please fill in your shop details to continue.',
                    style: GoogleFonts.inter(fontSize: 13, color: sub, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // ── Card ─────────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cardBd, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
                          blurRadius: 24, offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ProField(
                          controller: _shopNameCtrl,
                          label: 'Shop Name',
                          hint: 'Enter shop name',
                          icon: Icons.storefront_rounded,
                        ),
                        ProField(
                          controller: _ownerNameCtrl,
                          label: 'Owner Full Name',
                          hint: 'Enter owner full name',
                          icon: Icons.person_rounded,
                        ),
                        ProField(
                          controller: _phoneCtrl,
                          label: 'Phone / WhatsApp',
                          hint: '03XX-XXXXXXX',
                          icon: Icons.phone_rounded,
                          keyboardType: TextInputType.phone,
                        ),
                        ProField(
                          controller: _cityCtrl,
                          label: 'City (optional)',
                          hint: 'Enter city',
                          icon: Icons.location_city_rounded,
                        ),
                        ProField(
                          controller: _addressCtrl,
                          label: 'Shop Address',
                          hint: 'Street, Market, Shop No.',
                          icon: Icons.location_on_rounded,
                          maxLines: 2,
                        ),

                        if (_error != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: Color(0xFFEF4444), fontSize: 12.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 12),

                        // ── Submit ────────────────────────────────────────
                        GestureDetector(
                          onTap: _isLoading ? null : _complete,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF5A623), Color(0xFFD97706)],
                              ),
                              borderRadius: BorderRadius.circular(13),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x44F5A623),
                                  blurRadius: 14, offset: Offset(0, 5),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22, height: 22,
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF1A0A00), strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    'Complete Setup & Enter Dashboard 🚀',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF1A0A00),
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Sign out link ─────────────────────────────────────────
                  TextButton(
                    onPressed: _isSigningOut ? null : _signOut,
                    child: _isSigningOut
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            'Sign out and use a different account',
                            style: GoogleFonts.inter(fontSize: 13, color: sub),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
