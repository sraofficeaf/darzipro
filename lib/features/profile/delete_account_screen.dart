import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/providers/supabase_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Delete Account Screen — 3-step flow
// Step 1: Warning + shop name confirmation
// Step 2: Password re-entry
// Step 3: Processing + completion
// ─────────────────────────────────────────────────────────────────────────────

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  static Future<void> show(BuildContext context) {
    return showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.82),
      barrierDismissible: false,
      barrierLabel: 'DeleteAccountScreen',
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: const Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: DeleteAccountScreen(),
            ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
              .animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen>
    with SingleTickerProviderStateMixin {
  int _step = 1; // 1 = warning, 2 = password, 3 = processing/done
  bool _isDeleting = false;
  bool _deletionComplete = false;
  String? _errorMessage;

  // Step 1: Confirmation text
  final _confirmCtrl = TextEditingController();
  String _shopName = '';

  // Step 2: Password
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  late AnimationController _stepAnimCtrl;
  late Animation<double> _stepFade;

  @override
  void initState() {
    super.initState();
    _stepAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _stepFade = CurvedAnimation(parent: _stepAnimCtrl, curve: Curves.easeOut);
    _stepAnimCtrl.forward();
    _loadShopName();
  }

  Future<void> _loadShopName() async {
    final shopId = ref.read(currentShopIdProvider);
    if (shopId == null) return;
    try {
      final data = await Supabase.instance.client
          .from('shops')
          .select('name')
          .eq('id', shopId)
          .maybeSingle();
      if (mounted && data != null) {
        setState(() => _shopName = data['name'] as String? ?? '');
      }
    } catch (_) {}
  }

  Future<void> _animateToStep(int step) async {
    await _stepAnimCtrl.reverse();
    setState(() => _step = step);
    _stepAnimCtrl.forward();
  }

  // Step 2 → password re-authentication
  Future<void> _verifyPasswordAndDelete() async {
    if (_passwordCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter your password');
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });
    await _animateToStep(3); // Show processing step immediately

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('No active session');

      final shopId = ref.read(currentShopIdProvider);
      if (shopId == null) throw Exception('Shop ID not found');

      // Re-authenticate user to confirm identity
      final email = user.email ?? '';
      final authResponse = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: _passwordCtrl.text.trim(),
      );
      if (authResponse.user == null) {
        throw Exception('Incorrect password. Please try again.');
      }

      // Get JWT for Edge Function call
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) throw Exception('Session expired');

      // Call Edge Function — this is the atomic deletion operation
      // Double-tap safe: button already disabled once _isDeleting=true
      final response = await Supabase.instance.client.functions.invoke(
        'delete-shop-account',
        body: {'shop_id': shopId},
      );

      if (response.status != 200) {
        final errData = response.data;
        final errMsg = (errData is Map ? errData['error'] : null) ?? 'Deletion failed';
        throw Exception(errMsg.toString());
      }

      // ── Client-side cleanup: clear all Hive boxes before sign out
      final hiveBoxNames = [
        'customers_box',
        'orders_box',
        'settings_box',
        'measurements_box',
        'naap_drafts_box',
        'offline_queue_box',
        'license_box',
      ];
      for (final boxName in hiveBoxNames) {
        try {
          final box = Hive.isBoxOpen(boxName)
              ? Hive.box(boxName)
              : await Hive.openBox(boxName);
          await box.clear();
        } catch (_) {}
      }

      // Sign out
      await Supabase.instance.client.auth.signOut();

      if (mounted) {
        setState(() {
          _isDeleting = false;
          _deletionComplete = true;
        });
      }

      // After 2.5 seconds, redirect to login
      await Future.delayed(const Duration(milliseconds: 2500));
      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDeleting = false;
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _step = 2; // Go back to password step to show error
        });
        _stepAnimCtrl.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _confirmCtrl.dispose();
    _passwordCtrl.dispose();
    _stepAnimCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D1626) : Colors.white;
    final border = isDark ? const Color(0x1AFFFFFF) : const Color(0x14000000);
    final t1 = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0F172A);
    final t2 = isDark ? const Color(0xFF64748B) : const Color(0xFF475569);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x33FF3A58), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0x40FF3A58),
              blurRadius: 60,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: border, width: 1)),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0x1AFF3A58),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x33FF3A58), width: 1),
                    ),
                    child: const Center(
                      child: Text('⚠️', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _step == 3 && _deletionComplete
                          ? 'Account Deleted'
                          : 'Delete Your Account',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFFF3A58),
                      ),
                    ),
                  ),
                  if (_step < 3)
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x0DFFFFFF) : const Color(0x08000000),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.close_rounded, size: 18, color: t2),
                      ),
                    ),
                ],
              ),
            ),

            // Body (animated and scrollable to prevent keyboard overflow)
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: FadeTransition(
                  opacity: _stepFade,
                  child: _buildStepContent(t1, t2, isDark),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent(Color t1, Color t2, bool isDark) {
    switch (_step) {
      case 1:
        return _buildStep1(t1, t2, isDark);
      case 2:
        return _buildStep2(t1, t2, isDark);
      case 3:
        return _buildStep3(t1, t2);
      default:
        return const SizedBox();
    }
  }

  // ─── STEP 1: Warning + Confirmation ──────────────────────────────────────
  Widget _buildStep1(Color t1, Color t2, bool isDark) {
    final typedText = _confirmCtrl.text.trim();
    final matches = _shopName.isNotEmpty && typedText == _shopName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Warning box — what will be deleted
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0x0DFF3A58),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x33FF3A58), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will permanently delete:',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFF3A58),
                ),
              ),
              const SizedBox(height: 8),
              ...[
                '🗑️  Your shop profile and login',
                '👥  All your customers and their measurements',
                '📦  All your orders and order history',
                '🖼️  Your shop logo and uploaded images',
              ].map((item) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      item,
                      style: GoogleFonts.inter(fontSize: 12.5, color: t1),
                    ),
                  )),
              const SizedBox(height: 12),
              Container(height: 1, color: const Color(0x22FF3A58)),
              const SizedBox(height: 10),
              Text(
                'The following will be anonymized (kept for accounting/legal reasons):',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFD97706),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '📋  Payment and subscription history',
                style: GoogleFonts.inter(fontSize: 12, color: t1),
              ),
              const SizedBox(height: 10),
              Container(height: 1, color: const Color(0x22FF3A58)),
              const SizedBox(height: 10),
              Text(
                '💸  Any pending or unpaid invite earnings will be forfeited.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFF3A58),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Cannot be undone warning
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF3A58), size: 16),
            const SizedBox(width: 6),
            Text(
              'This action CANNOT be undone.',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFFF3A58),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Confirmation text field
        Text(
          _shopName.isNotEmpty
              ? 'Type your shop name to confirm: "$_shopName"'
              : 'Loading shop name...',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: t1,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _confirmCtrl,
          onChanged: (_) => setState(() {}),
          style: GoogleFonts.inter(fontSize: 14, color: t1),
          decoration: InputDecoration(
            hintText: 'Type shop name exactly...',
            hintStyle: GoogleFonts.inter(fontSize: 13, color: t2),
            filled: true,
            fillColor: isDark ? const Color(0x0AFFFFFF) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: const Color(0x33FF3A58), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: matches ? AppColors.red : const Color(0x33FF3A58),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: matches ? AppColors.red : const Color(0x66FF3A58),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 20),

        // Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: t2,
                  side: BorderSide(color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8F0)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Cancel', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: matches
                    ? () => _animateToStep(2)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3A58),
                  disabledBackgroundColor: const Color(0x33FF3A58),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: const Color(0x66FF3A58),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  'Continue',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── STEP 2: Password Re-entry ────────────────────────────────────────────
  Widget _buildStep2(Color t1, Color t2, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Confirm your identity',
          style: GoogleFonts.outfit(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: t1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Enter your password to permanently delete this account.',
          style: GoogleFonts.inter(fontSize: 13, color: t2),
        ),
        const SizedBox(height: 20),

        TextField(
          controller: _passwordCtrl,
          obscureText: _obscurePassword,
          style: GoogleFonts.inter(fontSize: 14, color: t1),
          decoration: InputDecoration(
            labelText: 'Password',
            labelStyle: GoogleFonts.inter(fontSize: 13, color: t2),
            filled: true,
            fillColor: isDark ? const Color(0x0AFFFFFF) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8F0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFFF3A58), width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: t2,
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x0DFF3A58),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x33FF3A58)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Color(0xFFFF3A58), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFFF3A58)),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isDeleting ? null : () => _animateToStep(1),
                style: OutlinedButton.styleFrom(
                  foregroundColor: t2,
                  side: BorderSide(
                    color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8F0),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Back', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                // Disable while request in-flight (prevents double-tap)
                onPressed: _isDeleting ? null : _verifyPasswordAndDelete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3A58),
                  disabledBackgroundColor: const Color(0x33FF3A58),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  'Delete My Account Permanently',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── STEP 3: Processing / Completed ──────────────────────────────────────
  Widget _buildStep3(Color t1, Color t2) {
    if (_deletionComplete) {
      return Column(
        children: [
          const SizedBox(height: 16),
          const Icon(Icons.check_circle_rounded, color: AppColors.teal, size: 56),
          const SizedBox(height: 16),
          Text(
            'Your account has been deleted.',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.teal,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'All your personal data has been removed. Redirecting to login...',
            style: GoogleFonts.inter(fontSize: 13, color: t2),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
        ],
      );
    }

    return Column(
      children: [
        const SizedBox(height: 24),
        const CircularProgressIndicator(
          color: Color(0xFFFF3A58),
          strokeWidth: 3,
        ),
        const SizedBox(height: 20),
        Text(
          'Deleting your account...',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: t1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'This may take a few seconds. Please do not close the app.',
          style: GoogleFonts.inter(fontSize: 12, color: t2),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
