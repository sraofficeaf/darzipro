import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_enums.dart';
import '../../core/services/update_service.dart';
import '../../core/widgets/update_dialog.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/providers/supabase_providers.dart';
import '../../shared/providers/license_provider.dart';
import '../settings/add_template_modal.dart';
import '../storage/storage_addon_modal.dart';
import 'change_password_modal.dart';
import 'delete_account_screen.dart';

// ── COLOR CONSTANTS (CACHED) ────────────────────────────────────────────────
class _ProfColors {
  static const ink = Color(0xFF111827);
  static const muted = Color(0xFF7B8494);
  static const faint = Color(0xFFAAB2BF);
  static const line = Color(0xFFE8EAF0);
  static const paper = Color(0xFFF5F6F8);
  static const white = Color(0xFFFFFFFF);
  static const dark = Color(0xFF151922);
  static const darkCard = Color(0xFF181D27);
  static const darkLine = Color(0xFF333946);

  static const gold = Color(0xFFE9A227);
  static const gold2 = Color(0xFFFFC65A);
  static const goldBg = Color(0xFFFFF6E5);
  static const goldLine = Color(0xFFF3DDA8);

  static const green = Color(0xFF18B887);
  static const greenBg = Color(0xFFEAFBF5);
  static const greenLine = Color(0xFFCFEFE3);

  static const rose = Color(0xFFEF5261);
  static const roseBg = Color(0xFFFFF0F2);
  static const roseLine = Color(0xFFFFD9DE);

  static const blue = Color(0xFF5478E8);
  static const blueBg = Color(0xFFEEF2FF);
}

// ── TYPOGRAPHY CONSTANTS (CACHED) ───────────────────────────────────────────
class _ProfStyles {
  static final heroTitle = GoogleFonts.manrope(
    fontSize: 21,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    color: Colors.white,
  );

  static final heroSub = GoogleFonts.dmSans(
    fontSize: 12,
    color: const Color(0xFFAEB5C2),
  );

  static final shopNameBig = GoogleFonts.manrope(
    fontSize: 26,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.8,
  );

  static final sectionTitle = GoogleFonts.dmSans(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.4,
    color: _ProfColors.muted,
  );

  static final rowLabel = GoogleFonts.manrope(
    fontSize: 13.5,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
  );

  static final rowSub = GoogleFonts.dmSans(
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
    color: _ProfColors.muted,
  );

  static final statNum = GoogleFonts.ibmPlexMono(
    fontSize: 17,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
  );

  static final statLbl = GoogleFonts.dmSans(
    fontSize: 9,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.7,
    color: _ProfColors.muted,
  );
}

// ── PROFILE SCREEN ──────────────────────────────────────────────────────────
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUploadingLogo = false;
  String _activeTab = 'overview'; // 'overview', 'shop', 'templates', 'settings'

  // ──── Helper: Get Initials ────
  String _getInitials(String name) {
    if (name.isEmpty) return 'DP';
    final clean = name.trim();
    final parts = clean.split(' ');
    if (parts.length >= 2) {
      final p1 = parts[0];
      final p2 = parts[1];
      if (p1.isNotEmpty && p2.isNotEmpty) {
        return '${p1[0]}${p2[0]}'.toUpperCase();
      }
    }
    if (clean.length >= 2) {
      return clean.substring(0, 2).toUpperCase();
    }
    return clean.toUpperCase();
  }

  // ──── Helper: Field Hint Text ────
  String _getFieldHint(String label) {
    switch (label.toLowerCase()) {
      case 'shop name':
        return 'e.g. Ahmed Tailors';
      case 'owner name':
        return 'e.g. Muhammad Ahmed';
      case 'phone':
        return 'e.g. 0300-1234567';
      case 'address':
        return 'e.g. Main Bazaar, Lahore';
      case 'card footer':
        return 'e.g. Thank you for your business!';
      default:
        return 'Enter $label';
    }
  }

  // ──── Resilient Shop & User ID Resolver ────
  Future<({String? shopId, String? userId})> _getResolvedShopAndUserId() async {
    String? userId = ref.read(currentUserIdProvider) ?? Supabase.instance.client.auth.currentUser?.id;
    String? shopId = ref.read(currentShopIdProvider);

    userId ??= Supabase.instance.client.auth.currentUser?.id;

    if (shopId == null && userId != null) {
      try {
        final profileRes = await Supabase.instance.client
            .from('profiles')
            .select('shop_id')
            .eq('id', userId)
            .maybeSingle();
        shopId = profileRes?['shop_id'] as String?;
      } catch (_) {}
    }

    if (shopId == null) {
      final shop = ref.read(currentShopProvider).value;
      shopId = shop?['id'] as String?;
    }

    return (shopId: shopId, userId: userId);
  }

  // ──── Logo Upload ────
  Future<void> _pickAndUploadLogo() async {
    final messenger = ScaffoldMessenger.of(context);
    final isUrdu = ref.read(localeProvider) == 'ur';

    final resolved = await _getResolvedShopAndUserId();
    final shopId = resolved.shopId;
    if (shopId == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(isUrdu ? '❌ ایرر: دکان کی معلومات نہیں ملیں!' : '❌ Error: Shop ID not found!'),
          backgroundColor: _ProfColors.rose,
        ),
      );
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;

    setState(() => _isUploadingLogo = true);
    try {
      final bytes = await picked.readAsBytes();
      final extension = picked.name.split('.').last.toLowerCase();
      final storagePath = '$shopId/logo_${DateTime.now().millisecondsSinceEpoch}.$extension';

      final shop = ref.read(currentShopProvider).value;
      final oldLogo = shop?['logo_url'] as String?;
      if (oldLogo != null && oldLogo.isNotEmpty && !oldLogo.startsWith('http')) {
        try {
          await Supabase.instance.client.storage.from('shop-logos').remove([oldLogo]);
        } catch (_) {}
      }

      await Supabase.instance.client.storage.from('shop-logos').uploadBinary(
        storagePath,
        bytes,
        fileOptions: FileOptions(upsert: true, contentType: 'image/$extension'),
      );

      await Supabase.instance.client.from('shops').update({'logo_url': storagePath}).eq('id', shopId);

      ref.invalidate(currentShopProvider);
      ref.invalidate(profileProvider);

      messenger.showSnackBar(
        SnackBar(
          content: Text(isUrdu ? '✅ لوگو تبدیل ہو گیا!' : '✅ Logo updated successfully!'),
          backgroundColor: _ProfColors.green,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('❌ Upload failed: $e'),
          backgroundColor: _ProfColors.rose,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
    }
  }

  // ──── Save Profile Field ────
  Future<void> _updateShopField(String key, String value) async {
    final messenger = ScaffoldMessenger.of(context);
    final isUrdu = ref.read(localeProvider) == 'ur';

    final resolved = await _getResolvedShopAndUserId();
    final shopId = resolved.shopId;

    // Debug: log what we got
    debugPrint('[ProfileUpdate] shopId=$shopId userId=${resolved.userId}');

    if (shopId == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(isUrdu ? '❌ ایرر: دکان کا اکاؤنٹ نہیں ملا!' : '❌ Error: Shop ID not found! Please logout and login again.'),
          backgroundColor: _ProfColors.rose,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    try {
      debugPrint('[ProfileUpdate] Updating shops.$key for shopId=$shopId');

      // Use .select() so that RLS violations throw instead of silently 0-row updating
      final result = await Supabase.instance.client
          .from('shops')
          .update({key: value})
          .eq('id', shopId)
          .select('id, $key')
          .maybeSingle();

      debugPrint('[ProfileUpdate] Update result: $result');

      if (result == null) {
        // 0 rows matched — either wrong shopId or RLS blocked update
        messenger.showSnackBar(
          SnackBar(
            content: Text('❌ Update blocked! No rows matched (shopId=$shopId). Check RLS policy on shops table.'),
            backgroundColor: _ProfColors.rose,
            duration: const Duration(seconds: 6),
          ),
        );
        return;
      }

      if (key == 'name') {
        try {
          await Supabase.instance.client.from('licenses').update({'shop_name': value}).eq('shop_id', shopId);
        } catch (_) {}
      }

      ref.invalidate(currentShopProvider);
      ref.invalidate(profileProvider);

      messenger.showSnackBar(
        SnackBar(
          content: Text(isUrdu ? '✅ معلومات محفوظ ہو گئیں!' : '✅ $key updated successfully!'),
          backgroundColor: _ProfColors.green,
        ),
      );
    } catch (e) {
      debugPrint('[ProfileUpdate] ERROR: $e');
      messenger.showSnackBar(
        SnackBar(
          content: Text('❌ Save failed: $e'),
          backgroundColor: _ProfColors.rose,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _updateProfileField(String key, String value) async {
    final messenger = ScaffoldMessenger.of(context);
    final isUrdu = ref.read(localeProvider) == 'ur';

    final resolved = await _getResolvedShopAndUserId();
    final userId = resolved.userId;

    if (userId == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(isUrdu ? '❌ ایرر: یوزر اکاؤنٹ نہیں ملا!' : '❌ Error: User account not found!'),
          backgroundColor: _ProfColors.rose,
        ),
      );
      return;
    }

    try {
      await Supabase.instance.client.from('profiles').update({key: value}).eq('id', userId);

      ref.invalidate(profileProvider);
      ref.invalidate(currentShopProvider);

      messenger.showSnackBar(
        SnackBar(
          content: Text(isUrdu ? '✅ معلومات محفوظ ہو گئیں!' : '✅ Profile updated successfully!'),
          backgroundColor: _ProfColors.green,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('❌ Save failed: $e'),
          backgroundColor: _ProfColors.rose,
        ),
      );
    }
  }

  // ──── Edit Single Field Modal (Matches HTML #modalField) ────
  void _openFieldEdit(String label, String initialValue, Future<void> Function(String) onSave, {int maxLines = 1, String? hintText}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController(text: initialValue);
    bool saving = false;

    // Map label to hint if not provided
    final resolvedHint = hintText ?? _getFieldHint(label);

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Dialog(
              backgroundColor: isDark ? _ProfColors.darkCard : _ProfColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit $label',
                              style: GoogleFonts.manrope(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : _ProfColors.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Changes save immediately to your shop.',
                              style: GoogleFonts.dmSans(
                                fontSize: 11.5,
                                color: _ProfColors.muted,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      label.toUpperCase(),
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: _ProfColors.muted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: controller,
                      maxLines: maxLines,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : _ProfColors.ink,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? _ProfColors.dark : _ProfColors.paper,
                        hintText: resolvedHint,
                        hintStyle: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: _ProfColors.faint,
                          fontStyle: FontStyle.italic,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? _ProfColors.darkLine : _ProfColors.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _ProfColors.gold, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: isDark ? _ProfColors.darkLine : _ProfColors.line),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: _ProfColors.muted),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: saving
                                ? null
                                : () async {
                                    setDialogState(() => saving = true);
                                    try {
                                      await onSave(controller.text.trim());
                                      if (ctx.mounted) Navigator.pop(ctx);
                                    } finally {
                                      if (ctx.mounted) setDialogState(() => saving = false);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _ProfColors.gold,
                              foregroundColor: const Color(0xFF211500),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF211500)),
                                  )
                                : Text(
                                    'Save Changes',
                                    style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 13),
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
    );
  }

  // ──── Edit Profile Modal (Full — Matches HTML #modalEdit) ────
  void _openEditProfileModal(String sName, String oName, String phone, String address) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shopCtrl = TextEditingController(text: sName);
    final ownerCtrl = TextEditingController(text: oName);
    final phoneCtrl = TextEditingController(text: phone);
    final addressCtrl = TextEditingController(text: address);
    bool saving = false;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Dialog(
              backgroundColor: isDark ? _ProfColors.darkCard : _ProfColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Edit Profile',
                                style: GoogleFonts.manrope(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : _ProfColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Update your shop and owner information.',
                                style: GoogleFonts.dmSans(fontSize: 11.5, color: _ProfColors.muted),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildFieldInput('SHOP NAME', shopCtrl, isDark),
                      const SizedBox(height: 12),
                      _buildFieldInput('OWNER NAME', ownerCtrl, isDark),
                      const SizedBox(height: 12),
                      _buildFieldInput('PHONE', phoneCtrl, isDark),
                      const SizedBox(height: 12),
                      _buildFieldInput('ADDRESS', addressCtrl, isDark, maxLines: 2),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: BorderSide(color: isDark ? _ProfColors.darkLine : _ProfColors.line),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text('Cancel', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: _ProfColors.muted)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: saving
                                  ? null
                                  : () async {
                                      setDialogState(() => saving = true);
                                      try {
                                        final resolved = await _getResolvedShopAndUserId();
                                        final sId = resolved.shopId;
                                        final uId = resolved.userId;

                                        if (sId != null) {
                                          await Supabase.instance.client.from('shops').update({
                                            'name': shopCtrl.text.trim(),
                                            'phone': phoneCtrl.text.trim(),
                                            'address': addressCtrl.text.trim(),
                                          }).eq('id', sId);

                                          try {
                                            await Supabase.instance.client.from('licenses').update({
                                              'shop_name': shopCtrl.text.trim(),
                                              'phone': phoneCtrl.text.trim(),
                                            }).eq('shop_id', sId);
                                          } catch (_) {}
                                        }

                                        if (uId != null) {
                                          await Supabase.instance.client.from('profiles').update({
                                            'full_name': ownerCtrl.text.trim(),
                                          }).eq('id', uId);
                                        }

                                        ref.invalidate(currentShopProvider);
                                        ref.invalidate(profileProvider);

                                        if (ctx.mounted) Navigator.pop(ctx);
                                      } finally {
                                        if (ctx.mounted) setDialogState(() => saving = false);
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _ProfColors.gold,
                                foregroundColor: const Color(0xFF211500),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: saving
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF211500)))
                                  : Text('Save Profile', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 13)),
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
    );
  }

  Widget _buildFieldInput(String label, TextEditingController ctrl, bool isDark, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: _ProfColors.muted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : _ProfColors.ink,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? _ProfColors.dark : _ProfColors.paper,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? _ProfColors.darkLine : _ProfColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _ProfColors.gold, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // ──── Language Sheet (Matches HTML #sheetLang) ────
  void _openLangSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentLang = ref.read(localeProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? _ProfColors.darkCard : _ProfColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: _ProfColors.line, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Select Language', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : _ProfColors.ink)),
            const SizedBox(height: 16),
            _buildLangOption('English', currentLang == 'en', isDark, () {
              Navigator.pop(ctx);
              ref.read(localeProvider.notifier).setLanguage('en');
            }),
            const SizedBox(height: 8),
            _buildLangOption('اردو (Urdu)', currentLang == 'ur', isDark, () {
              Navigator.pop(ctx);
              ref.read(localeProvider.notifier).setLanguage('ur');
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLangOption(String name, bool isSelected, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? _ProfColors.goldBg : (isDark ? _ProfColors.dark : _ProfColors.paper),
          border: Border.all(color: isSelected ? _ProfColors.gold : (isDark ? _ProfColors.darkLine : _ProfColors.line), width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              name,
              style: GoogleFonts.manrope(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: isSelected ? const Color(0xFFB45309) : (isDark ? Colors.white : _ProfColors.ink),
              ),
            ),
            if (isSelected) const Text('✓', style: TextStyle(color: _ProfColors.gold, fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  // ──── Logout Modal (Matches HTML #modalLogout) ────
  void _openLogoutModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Dialog(
            backgroundColor: isDark ? _ProfColors.darkCard : _ProfColors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Logout Confirmation', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : _ProfColors.ink)),
                  const SizedBox(height: 8),
                  Text(
                    'Any unsaved changes will be lost. Your data stays safe on the cloud.',
                    style: GoogleFonts.dmSans(fontSize: 12.5, color: _ProfColors.muted, height: 1.6),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: isDark ? _ProfColors.darkLine : _ProfColors.line),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Cancel', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: _ProfColors.muted)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await Supabase.instance.client.auth.signOut();
                            if (mounted) context.go('/login');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _ProfColors.rose,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Logout', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(currentShopProvider);
    final profileAsync = ref.watch(profileProvider);
    final license = ref.watch(licenseProvider);
    final customersAsync = ref.watch(customersProvider);
    final ordersAsync = ref.watch(ordersProvider);
    final templatesAsync = ref.watch(measurementTemplatesProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUrdu = ref.watch(localeProvider) == 'ur';

    final shop = shopAsync.valueOrNull;
    final shopName = shop?['name'] as String? ?? '';
    final ownerName = profileAsync.valueOrNull?['full_name'] as String? ?? '';
    final phoneNum = shop?['phone'] as String? ?? '';
    final addressVal = shop?['address'] as String? ?? '';
    final logoUrl = shop?['logo_url'] as String?;

    final Box settingsBox = Hive.box('settings_box');
    final cardFooter = settingsBox.get('card_footer', defaultValue: '') as String;

    final clientsCount = customersAsync.valueOrNull?.length ?? 0;
    final activeOrdersCount = ordersAsync.valueOrNull?.where((o) =>
        o.status != OrderStatus.delivered && o.status != OrderStatus.cancelled).length ?? 0;

    final isPro = license.isPro || license.isBusiness;

    // Cloud storage calculation
    final usedBytes = (shop?['storage_used_bytes'] as int?) ?? 420000;
    final double usedMb = (usedBytes / 1000000);
    final isAddonActive = shop?['storage_addon_active'] == true;
    final double storageProgress = isAddonActive ? 1.0 : (usedBytes / 1500000).clamp(0.0, 1.0);

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 1000;

    return Directionality(
      textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: isDark ? _ProfColors.dark : _ProfColors.paper,
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 28 : 16,
              vertical: isDesktop ? 24 : 16,
            ),
            children: [
              // 1. TOP HERO BANNER (Matches HTML .hero)
              RepaintBoundary(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                  decoration: BoxDecoration(
                    color: _ProfColors.dark,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2E111827),
                        blurRadius: 30,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_ProfColors.gold2, _ProfColors.gold],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text(
                            'D',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF241605),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Profile & Settings', style: _ProfStyles.heroTitle),
                            const SizedBox(height: 3),
                            Text('Manage your shop, templates, and app preferences · پروفائل اور سیٹنگز', style: _ProfStyles.heroSub),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Top Action Buttons
                      if (isDesktop) ...[
                        // Theme Toggle
                        _buildHeroActionButton(
                          icon: isDark ? '☀️' : '🌙',
                          label: 'Theme',
                          onTap: () {
                            final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
                            ref.read(themeModeProvider.notifier).state = newMode;
                            settingsBox.put('themeMode', isDark ? 'light' : 'dark');
                          },
                        ),
                        const SizedBox(width: 8),
                        // Edit Profile
                        _buildHeroActionButton(
                          icon: '✏',
                          label: 'Edit',
                          onTap: () => _openEditProfileModal(shopName, ownerName, phoneNum, addressVal),
                        ),
                        const SizedBox(width: 8),
                        // Save Button
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('✓ Profile saved successfully!'), backgroundColor: _ProfColors.green),
                            );
                          },
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [_ProfColors.gold2, _ProfColors.gold]),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text('✓ Save', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF211500))),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 2. MAIN LAYOUT (DESKTOP: SIDEBAR + CONTENT, MOBILE: STACKED)
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT COLUMN: SIDEBAR (320px)
                    SizedBox(
                      width: 320,
                      child: _buildDesktopSidebar(
                        context,
                        shopName: shopName,
                        ownerName: ownerName,
                        addressVal: addressVal,
                        logoUrl: logoUrl,
                        isDark: isDark,
                        isPro: isPro,
                        usedMb: usedMb,
                        storageProgress: storageProgress,
                      ),
                    ),
                    const SizedBox(width: 18),
                    // RIGHT COLUMN: MAIN CONTENT (TABS + ACTIVE VIEW)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildNavbar(isDark),
                          const SizedBox(height: 14),
                          _buildActiveViewContent(
                            isDark: isDark,
                            isUrdu: isUrdu,
                            shopName: shopName,
                            ownerName: ownerName,
                            phoneNum: phoneNum,
                            addressVal: addressVal,
                            cardFooter: cardFooter,
                            logoUrl: logoUrl,
                            clientsCount: clientsCount,
                            activeOrdersCount: activeOrdersCount,
                            isPro: isPro,
                            usedMb: usedMb,
                            storageProgress: storageProgress,
                            templatesAsync: templatesAsync,
                            settingsBox: settingsBox,
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else
                // MOBILE COMPACT VIEW (< 1000px)
                Column(
                  children: [
                    // Compact Mobile Hero Card (.m-hero) — on tabs other than Overview
                    if (_activeTab != 'overview') ...[
                      _buildMobileHeroCard(
                        isDark: isDark,
                        shopName: shopName,
                        ownerName: ownerName,
                        addressVal: addressVal,
                        logoUrl: logoUrl,
                        clientsCount: clientsCount,
                        activeOrdersCount: activeOrdersCount,
                        isPro: isPro,
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Mobile Tabs
                    _buildNavbar(isDark),
                    const SizedBox(height: 14),
                    // Content
                    _buildActiveViewContent(
                      isDark: isDark,
                      isUrdu: isUrdu,
                      shopName: shopName,
                      ownerName: ownerName,
                      phoneNum: phoneNum,
                      addressVal: addressVal,
                      cardFooter: cardFooter,
                      logoUrl: logoUrl,
                      clientsCount: clientsCount,
                      activeOrdersCount: activeOrdersCount,
                      isPro: isPro,
                      usedMb: usedMb,
                      storageProgress: storageProgress,
                      templatesAsync: templatesAsync,
                      settingsBox: settingsBox,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ──── Hero Top Action Button ────
  Widget _buildHeroActionButton({required String icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1D222D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF333946)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFE9ECF2))),
          ],
        ),
      ),
    );
  }

  // ──── DESKTOP SIDEBAR (.side, 320px) ────
  Widget _buildDesktopSidebar(
    BuildContext context, {
    required String shopName,
    required String ownerName,
    required String addressVal,
    required String? logoUrl,
    required bool isDark,
    required bool isPro,
    required double usedMb,
    required double storageProgress,
  }) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? _ProfColors.darkCard : _ProfColors.white,
          border: Border.all(color: isDark ? _ProfColors.darkLine : _ProfColors.line),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12111827),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Side Cover
            Container(
              height: 130,
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.6, -0.4),
                  radius: 1.2,
                  colors: [Color(0xFF2A2110), Color(0xFF181D27)],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 70px Avatar with Online Dot
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFD97706), Color(0xFFB45309)]),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0x66FFC65A), width: 2),
                        ),
                        child: Center(
                          child: Text(
                            _getInitials(shopName),
                            style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10CBA0),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF181D27), width: 2.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(shopName, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                  Text(
                    addressVal.isNotEmpty ? '$ownerName · $addressVal' : ownerName.isNotEmpty ? ownerName : 'Owner Name',
                    style: GoogleFonts.ibmPlexMono(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFFAEB5C2)),
                  ),
                ],
              ),
            ),

            // Side Body
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Side Nav Items
                  _buildSideNavItem(
                    icon: '🏪',
                    title: 'Shop Profile',
                    subtitle: 'Name, owner, contact',
                    isActive: _activeTab == 'shop',
                    isDark: isDark,
                    onTap: () => setState(() => _activeTab = 'shop'),
                  ),
                  const SizedBox(height: 4),
                  _buildSideNavItem(
                    icon: '📐',
                    title: 'Naap Templates',
                    subtitle: '3 defaults · add new',
                    isActive: _activeTab == 'templates',
                    isDark: isDark,
                    onTap: () => setState(() => _activeTab = 'templates'),
                  ),
                  const SizedBox(height: 4),
                  _buildSideNavItem(
                    icon: '⚙️',
                    title: 'App Settings',
                    subtitle: 'Theme, language, updates',
                    isActive: _activeTab == 'settings',
                    isDark: isDark,
                    onTap: () => setState(() => _activeTab = 'settings'),
                  ),
                  const SizedBox(height: 4),
                  _buildSideNavItem(
                    icon: '⭐',
                    title: 'Plan & Storage',
                    subtitle: isPro ? 'Pro · Limited storage' : 'Free Plan',
                    isActive: _activeTab == 'overview',
                    isDark: isDark,
                    onTap: () => setState(() => _activeTab = 'overview'),
                  ),
                  const SizedBox(height: 4),
                  _buildSideNavItem(
                    icon: '🔒',
                    title: 'Security',
                    subtitle: 'Password, logout',
                    isActive: false,
                    isDark: isDark,
                    onTap: () => setState(() => _activeTab = 'settings'),
                  ),
                  const SizedBox(height: 16),

                  // Storage Meter (.side-meter)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _ProfColors.goldBg,
                      border: Border.all(color: _ProfColors.goldLine, style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('CLOUD STORAGE', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF8B6C22))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(7)),
                              child: Text(
                                '${usedMb.toStringAsFixed(2)} / 1.5 MB',
                                style: GoogleFonts.ibmPlexMono(fontSize: 10.5, fontWeight: FontWeight.w800, color: const Color(0xFF8B6C22)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: storageProgress,
                            minHeight: 6,
                            backgroundColor: Colors.white,
                            valueColor: const AlwaysStoppedAnimation<Color>(_ProfColors.gold),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Limited plan · upgrade for unlimited storage',
                          style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF8B6C22)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Quick Actions (.side-quick)
                  ElevatedButton(
                    onPressed: () => AddTemplateModal.show(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _ProfColors.gold,
                      foregroundColor: const Color(0xFF211500),
                      minimumSize: const Size(double.infinity, 40),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('＋ Add Naap Template', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 7),
                  OutlinedButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final update = await UpdateService().checkForUpdate();
                        if (update != null && context.mounted) {
                          showDialog(context: context, builder: (_) => UpdateDialog(update: update));
                        } else {
                          messenger.showSnackBar(const SnackBar(content: Text('App is up to date!'), backgroundColor: _ProfColors.green));
                        }
                      } catch (e) {
                        messenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: _ProfColors.rose));
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 40),
                      side: BorderSide(color: isDark ? _ProfColors.darkLine : _ProfColors.line),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('🔄 Check Updates', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, color: isDark ? Colors.white : _ProfColors.ink)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideNavItem({
    required String icon,
    required String title,
    required String subtitle,
    required bool isActive,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isActive ? _ProfColors.dark : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isActive ? Colors.white10 : (isDark ? _ProfColors.dark : _ProfColors.paper),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Text(icon, style: const TextStyle(fontSize: 15))),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isActive ? Colors.white : (isDark ? Colors.white : _ProfColors.ink),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isActive ? const Color(0xFFAEB5C2) : _ProfColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: isActive ? const Color(0xFFAEB5C2) : _ProfColors.faint,
            ),
          ],
        ),
      ),
    );
  }

  // ──── STICKY NAVBAR TABS (.navbar) ────
  Widget _buildNavbar(bool isDark) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isDark ? _ProfColors.darkCard : _ProfColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? _ProfColors.darkLine : _ProfColors.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTabBtn('Overview', 'overview', isDark),
                    const SizedBox(width: 4),
                    _buildTabBtn('Shop', 'shop', isDark),
                    const SizedBox(width: 4),
                    _buildTabBtn('Templates', 'templates', isDark),
                    const SizedBox(width: 4),
                    _buildTabBtn('Settings', 'settings', isDark),
                  ],
                ),
              ),
            ),
            // Actions on right
            IconButton(
              icon: const Text('🌐', style: TextStyle(fontSize: 16)),
              onPressed: _openLangSheet,
              tooltip: 'Language',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBtn(String label, String id, bool isDark) {
    final isActive = _activeTab == id;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _activeTab = id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? _ProfColors.dark : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive) ...[
              Container(width: 6, height: 6, decoration: const BoxDecoration(color: _ProfColors.gold, shape: BoxShape.circle)),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isActive ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : _ProfColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──── MOBILE HERO CARD (.m-hero) ────
  Widget _buildMobileHeroCard({
    required bool isDark,
    required String shopName,
    required String ownerName,
    required String addressVal,
    required String? logoUrl,
    required int clientsCount,
    required int activeOrdersCount,
    required bool isPro,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const RadialGradient(
          center: Alignment(0.8, -0.6),
          radius: 1.5,
          colors: [Color(0xFF2A2110), Color(0xFF1B2436)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_ProfColors.gold2, Color(0xFFD97706)]),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x66FFC65A), width: 2),
                ),
                child: Center(
                  child: Text(
                    _getInitials(shopName),
                    style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shopName, style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(
                      addressVal.isNotEmpty ? '$ownerName · $addressVal' : ownerName.isNotEmpty ? ownerName : 'Owner Name',
                      style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFFAEB5C2)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 3-stat strip
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0x10FFFFFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x14FFFFFF)),
            ),
            child: Row(
              children: [
                Expanded(child: _buildMobileStat('$clientsCount', 'CLIENTS')),
                Container(width: 1, height: 22, color: Colors.white12),
                Expanded(child: _buildMobileStat('$activeOrdersCount', 'ACTIVE')),
                Container(width: 1, height: 22, color: Colors.white12),
                Expanded(child: _buildMobileStat(isPro ? 'PRO' : 'FREE', 'PLAN')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileStat(String val, String lbl) {
    return Column(
      children: [
        Text(val, style: GoogleFonts.ibmPlexMono(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 2),
        Text(lbl, style: GoogleFonts.dmSans(fontSize: 8.5, fontWeight: FontWeight.w900, color: const Color(0xFFAEB5C2), letterSpacing: 0.5)),
      ],
    );
  }

  // ──── VIEW CONTENT SWITCHER ────
  Widget _buildActiveViewContent({
    required bool isDark,
    required bool isUrdu,
    required String shopName,
    required String ownerName,
    required String phoneNum,
    required String addressVal,
    required String cardFooter,
    required String? logoUrl,
    required int clientsCount,
    required int activeOrdersCount,
    required bool isPro,
    required double usedMb,
    required double storageProgress,
    required AsyncValue<List<Map<String, dynamic>>> templatesAsync,
    required Box settingsBox,
  }) {
    switch (_activeTab) {
      case 'shop':
        return _buildShopTabView(isDark, shopName, ownerName, phoneNum, addressVal, cardFooter, settingsBox);
      case 'templates':
        return _buildTemplatesTabView(isDark, templatesAsync);
      case 'settings':
        return _buildSettingsTabView(isDark, isUrdu, settingsBox);
      case 'overview':
      default:
        return _buildOverviewTabView(
          isDark: isDark,
          isUrdu: isUrdu,
          shopName: shopName,
          ownerName: ownerName,
          phoneNum: phoneNum,
          addressVal: addressVal,
          cardFooter: cardFooter,
          logoUrl: logoUrl,
          clientsCount: clientsCount,
          activeOrdersCount: activeOrdersCount,
          isPro: isPro,
          usedMb: usedMb,
          storageProgress: storageProgress,
          templatesAsync: templatesAsync,
          settingsBox: settingsBox,
        );
    }
  }

  // ──── TAB 1: OVERVIEW VIEW ────
  Widget _buildOverviewTabView({
    required bool isDark,
    required bool isUrdu,
    required String shopName,
    required String ownerName,
    required String phoneNum,
    required String addressVal,
    required String cardFooter,
    required String? logoUrl,
    required int clientsCount,
    required int activeOrdersCount,
    required bool isPro,
    required double usedMb,
    required double storageProgress,
    required AsyncValue<List<Map<String, dynamic>>> templatesAsync,
    required Box settingsBox,
  }) {
    final planLabel = isPro ? 'PRO' : 'FREE';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Overview Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dashboard', style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : _ProfColors.ink)),
                const SizedBox(height: 2),
                Text('Everything about your shop, in one place.', style: GoogleFonts.dmSans(fontSize: 11, color: _ProfColors.muted)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: _ProfColors.greenBg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: _ProfColors.green, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('Active', style: GoogleFonts.dmSans(fontSize: 10.5, fontWeight: FontWeight.w800, color: _ProfColors.green)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // BIG PROFILE HERO CARD (.profile-hero)
        RepaintBoundary(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF2A2110), const Color(0xFF181D27)]
                    : [_ProfColors.goldBg, const Color(0xFFFFFDF8), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: _ProfColors.goldLine),
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [
                BoxShadow(color: Color(0x1AE9A227), blurRadius: 24, offset: Offset(0, 10)),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 680;

                final avatarWidget = Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: isCompact ? 72 : 90,
                      height: isCompact ? 72 : 90,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_ProfColors.gold2, Color(0xFFD97706)]),
                        borderRadius: BorderRadius.circular(isCompact ? 20 : 24),
                        border: Border.all(color: const Color(0x80FFC65A), width: 2),
                      ),
                      child: Center(
                        child: Text(
                          _getInitials(shopName),
                          style: GoogleFonts.manrope(
                            fontSize: isCompact ? 26 : 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: isCompact ? 14 : 16,
                        height: isCompact ? 14 : 16,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10CBA0),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                        ),
                      ),
                    ),
                  ],
                );

                final infoWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      shopName,
                      style: (isCompact
                              ? GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)
                              : _ProfStyles.shopNameBig)
                          .copyWith(color: isDark ? Colors.white : _ProfColors.ink),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$ownerName · $addressVal',
                      style: GoogleFonts.dmSans(
                        fontSize: isCompact ? 11.5 : 12.5,
                        color: _ProfColors.muted,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );

                final statsWidget = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.6),
                    border: Border.all(color: _ProfColors.goldLine),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _buildStatItem('$clientsCount', 'CLIENTS')),
                      Container(width: 1, height: 26, color: _ProfColors.goldLine),
                      Expanded(child: _buildStatItem('$activeOrdersCount', 'ACTIVE')),
                      Container(width: 1, height: 26, color: _ProfColors.goldLine),
                      Expanded(child: _buildStatItem(isPro ? 'PRO' : 'FREE', 'PLAN')),
                    ],
                  ),
                );

                final editBtn = ElevatedButton(
                  onPressed: () => _openEditProfileModal(shopName, ownerName, phoneNum, addressVal),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _ProfColors.gold,
                    foregroundColor: const Color(0xFF211500),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('✏ Edit Profile', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800)),
                );

                final logoBtn = OutlinedButton(
                  onPressed: _isUploadingLogo ? null : _pickAndUploadLogo,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    side: BorderSide(color: isDark ? _ProfColors.darkLine : _ProfColors.line),
                    backgroundColor: isDark ? _ProfColors.dark : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isUploadingLogo
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text('🖼 Change Logo', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, color: isDark ? Colors.white : _ProfColors.ink)),
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          avatarWidget,
                          const SizedBox(width: 14),
                          Expanded(child: infoWidget),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: editBtn),
                          const SizedBox(width: 10),
                          Expanded(child: logoBtn),
                        ],
                      ),
                      const SizedBox(height: 14),
                      statsWidget,
                    ],
                  );
                }

                // Desktop spacious row
                return Row(
                  children: [
                    avatarWidget,
                    const SizedBox(width: 22),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          infoWidget,
                          const SizedBox(height: 14),
                          statsWidget,
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        editBtn,
                        const SizedBox(height: 8),
                        logoBtn,
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 18),

        // PLAN & STORAGE CARD (.plan-card)
        RepaintBoundary(
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [_ProfColors.darkCard, const Color(0xFF1B2436)]
                    : [const Color(0xFFFFFDF8), Colors.white],
              ),
              border: Border.all(color: _ProfColors.goldLine),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CURRENT PLAN', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w900, color: _ProfColors.muted, letterSpacing: 1)),
                        const SizedBox(height: 4),
                        Text(isPro ? 'Professional' : 'Free Plan', style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : _ProfColors.ink)),
                        const SizedBox(height: 2),
                        Text('Active license · Darzi Pro Tailor Suite', style: GoogleFonts.dmSans(fontSize: 11.5, color: _ProfColors.muted)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_ProfColors.gold2, _ProfColors.gold]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 14, color: Color(0xFF211500)),
                          const SizedBox(width: 4),
                          Text(planLabel, style: GoogleFonts.dmSans(fontSize: 10.5, fontWeight: FontWeight.w900, color: const Color(0xFF211500))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Cloud Storage', style: GoogleFonts.dmSans(fontSize: 11.5, fontWeight: FontWeight.w700, color: _ProfColors.muted)),
                    Text('Limited · ${usedMb.toStringAsFixed(2)} MB / 1.5 MB', style: GoogleFonts.ibmPlexMono(fontSize: 11.5, fontWeight: FontWeight.w800, color: isDark ? Colors.white : _ProfColors.ink)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: storageProgress,
                    minHeight: 8,
                    backgroundColor: isDark ? _ProfColors.dark : _ProfColors.paper,
                    valueColor: const AlwaysStoppedAnimation<Color>(_ProfColors.gold),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => context.push('/subscription'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _ProfColors.gold,
                          foregroundColor: const Color(0xFF211500),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                        ),
                        child: Text('⬆ Plan & Billing', style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => StorageAddonModal.show(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: _ProfColors.green),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                        ),
                        child: Text('☁ Buy Storage', style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w800, color: _ProfColors.green)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        // SHOP PROFILE 5 ROWS (Matches HTML #section-shop)
        _buildSectionHeader('SHOP PROFILE', '5 fields', _ProfColors.gold),
        const SizedBox(height: 10),
        _buildCardWrapper(
          isDark,
          children: [
            _buildProfileRow('🏪', 'Shop Name', shopName, isDark, hint: 'e.g. Ahmed Tailors', onTap: () {
              _openFieldEdit('Shop Name', shopName, (val) => _updateShopField('name', val));
            }),
            _buildProfileRow('👤', 'Owner Name', ownerName, isDark, hint: 'e.g. Muhammad Ahmed', onTap: () {
              _openFieldEdit('Owner Name', ownerName, (val) => _updateProfileField('full_name', val));
            }),
            _buildProfileRow('📞', 'Phone', phoneNum, isDark, hint: 'e.g. 0300-1234567', onTap: () {
              _openFieldEdit('Phone', phoneNum, (val) => _updateShopField('phone', val));
            }),
            _buildProfileRow('📍', 'Address', addressVal, isDark, hint: 'e.g. Main Bazaar, Lahore', onTap: () {
              _openFieldEdit('Address', addressVal, (val) => _updateShopField('address', val), maxLines: 2);
            }),
            _buildProfileRow('🪪', 'Card Footer', cardFooter, isDark, isLast: true, hint: 'e.g. Thank you for your business!', onTap: () {
              _openFieldEdit('Card Footer', cardFooter, (val) async {
                await settingsBox.put('card_footer', val);
                if (mounted) setState(() {});
              });
            }),
          ],
        ),
        const SizedBox(height: 18),

        // MEASUREMENT TEMPLATES 3 DEFAULTS + ADD (Matches HTML #section-templates)
        _buildSectionHeader('MEASUREMENT TEMPLATES', '3', _ProfColors.green),
        const SizedBox(height: 10),
        _buildCardWrapper(
          isDark,
          children: [
            _buildTemplateRow('👔', 'Shalwar Kameez', 'Default Template · 15 fields', 'Default', isDark),
            _buildTemplateRow('👑', 'Sherwani', 'Default Template · 12 fields', 'Default', isDark),
            _buildTemplateRow('🧥', 'Waistcoat', 'Default Template · 8 fields', 'Default', isDark),
            // Add custom template row
            GestureDetector(
              onTap: () => AddTemplateModal.show(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0x1F18B887), Colors.transparent]
                        : [_ProfColors.greenBg, Colors.white],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _ProfColors.greenBg,
                        border: Border.all(color: _ProfColors.greenLine),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Center(child: Text('＋', style: TextStyle(color: _ProfColors.green, fontSize: 18, fontWeight: FontWeight.bold))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Add Custom Template', style: GoogleFonts.manrope(fontSize: 13.5, fontWeight: FontWeight.w700, color: _ProfColors.green)),
                          const SizedBox(height: 2),
                          Text('Create new measurement set', style: GoogleFonts.dmSans(fontSize: 11.5, color: _ProfColors.muted)),
                        ],
                      ),
                    ),
                    const Text('›', style: TextStyle(fontSize: 18, color: _ProfColors.faint, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ──── TAB 2: SHOP TAB VIEW ────
  Widget _buildShopTabView(
    bool isDark,
    String shopName,
    String ownerName,
    String phoneNum,
    String addressVal,
    String cardFooter,
    Box settingsBox,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Shop Profile', style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : _ProfColors.ink)),
                const SizedBox(height: 2),
                Text('Your shop identity and contact details.', style: GoogleFonts.dmSans(fontSize: 11, color: _ProfColors.muted)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(color: _ProfColors.goldBg, borderRadius: BorderRadius.circular(10)),
              child: Text('Editable', style: GoogleFonts.dmSans(fontSize: 10.5, fontWeight: FontWeight.w800, color: const Color(0xFF8B6C22))),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionHeader('SHOP IDENTITY', '', _ProfColors.gold),
        const SizedBox(height: 8),
        _buildCardWrapper(
          isDark,
          children: [
            _buildProfileRow('🏪', 'Shop Name', shopName, isDark, hint: 'e.g. Ahmed Tailors', onTap: () {
              _openFieldEdit('Shop Name', shopName, (val) => _updateShopField('name', val));
            }),
            _buildProfileRow('👤', 'Owner Name', ownerName, isDark, isLast: true, hint: 'e.g. Muhammad Ahmed', onTap: () {
              _openFieldEdit('Owner Name', ownerName, (val) => _updateProfileField('full_name', val));
            }),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionHeader('CONTACT', '', _ProfColors.blue),
        const SizedBox(height: 8),
        _buildCardWrapper(
          isDark,
          children: [
            _buildProfileRow('📞', 'Phone', phoneNum, isDark, hint: 'e.g. 0300-1234567', onTap: () {
              _openFieldEdit('Phone', phoneNum, (val) => _updateShopField('phone', val));
            }),
            _buildProfileRow('📍', 'Address', addressVal, isDark, hint: 'e.g. Main Bazaar, Lahore', onTap: () {
              _openFieldEdit('Address', addressVal, (val) => _updateShopField('address', val), maxLines: 2);
            }),
            _buildProfileRow('🪪', 'Card Footer', cardFooter, isDark, isLast: true, hint: 'e.g. Thank you for your business!', onTap: () {
              _openFieldEdit('Card Footer', cardFooter, (val) async {
                await settingsBox.put('card_footer', val);
                if (mounted) setState(() {});
              });
            }),
          ],
        ),
      ],
    );
  }

  // ──── TAB 3: TEMPLATES TAB VIEW ────
  Widget _buildTemplatesTabView(bool isDark, AsyncValue<List<Map<String, dynamic>>> templatesAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Measurement Templates', style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : _ProfColors.ink)),
                const SizedBox(height: 2),
                Text('Reusable naap sets for quick order creation.', style: GoogleFonts.dmSans(fontSize: 11, color: _ProfColors.muted)),
              ],
            ),
            ElevatedButton(
              onPressed: () => AddTemplateModal.show(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _ProfColors.gold,
                foregroundColor: const Color(0xFF211500),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('＋ Add Template', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildCardWrapper(
          isDark,
          children: [
            _buildTemplateRow('👔', 'Shalwar Kameez', '15 fields · Updated 12 Feb 2026', 'Default', isDark),
            _buildTemplateRow('👑', 'Sherwani', '12 fields · Updated 10 Feb 2026', 'Default', isDark),
            _buildTemplateRow('🧥', 'Waistcoat', '8 fields · Updated 05 Feb 2026', 'Default', isDark),
            GestureDetector(
              onTap: () => AddTemplateModal.show(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0x1F18B887), Colors.transparent]
                        : [_ProfColors.greenBg, Colors.white],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _ProfColors.greenBg,
                        border: Border.all(color: _ProfColors.greenLine),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Center(child: Text('＋', style: TextStyle(color: _ProfColors.green, fontSize: 18, fontWeight: FontWeight.bold))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Add Custom Template', style: GoogleFonts.manrope(fontSize: 13.5, fontWeight: FontWeight.w700, color: _ProfColors.green)),
                          const SizedBox(height: 2),
                          Text('Create a new measurement set', style: GoogleFonts.dmSans(fontSize: 11.5, color: _ProfColors.muted)),
                        ],
                      ),
                    ),
                    const Text('›', style: TextStyle(fontSize: 18, color: _ProfColors.faint, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ──── TAB 4: SETTINGS TAB VIEW ────
  Widget _buildSettingsTabView(bool isDark, bool isUrdu, Box settingsBox) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('App Settings', style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : _ProfColors.ink)),
            const SizedBox(height: 2),
            Text('Theme, language, and updates.', style: GoogleFonts.dmSans(fontSize: 11, color: _ProfColors.muted)),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionHeader('APPEARANCE & LANGUAGE', '', _ProfColors.gold),
        const SizedBox(height: 8),
        _buildCardWrapper(
          isDark,
          children: [
            // Theme Row with animated toggle switch
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: _ProfColors.goldBg, border: Border.all(color: _ProfColors.goldLine), borderRadius: BorderRadius.circular(11)),
                    child: Center(child: Text(isDark ? '☀️' : '🌙', style: const TextStyle(fontSize: 16))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Theme', style: _ProfStyles.rowLabel.copyWith(color: isDark ? Colors.white : _ProfColors.ink)),
                        const SizedBox(height: 2),
                        Text(isDark ? 'Dark Mode' : 'Light Mode', style: _ProfStyles.rowSub),
                      ],
                    ),
                  ),
                  // Animated switch
                  GestureDetector(
                    onTap: () {
                      final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
                      ref.read(themeModeProvider.notifier).state = newMode;
                      settingsBox.put('themeMode', isDark ? 'light' : 'dark');
                    },
                    child: Container(
                      width: 42,
                      height: 24,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isDark ? _ProfColors.gold : _ProfColors.line,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Align(
                        alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(width: 20, height: 20, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _ProfColors.line),
            // Language
            _buildProfileRow('🌐', 'Language', isUrdu ? 'اردو' : 'English', isDark, onTap: _openLangSheet),
            // Check for Updates
            _buildProfileRow('🔄', 'Check for Updates', 'Version 1.0.0', isDark, isLast: true, onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                final update = await UpdateService().checkForUpdate();
                if (!mounted) return;
                if (update != null) {
                  showDialog(context: context, builder: (_) => UpdateDialog(update: update));
                } else {
                  messenger.showSnackBar(const SnackBar(content: Text('App is up to date!'), backgroundColor: _ProfColors.green));
                }
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: _ProfColors.rose));
              }
            }),
          ],
        ),
        const SizedBox(height: 16),

        // Security Section (Blue bar)
        _buildSectionHeader('SECURITY', '', _ProfColors.blue),
        const SizedBox(height: 8),
        _buildCardWrapper(
          isDark,
          children: [
            _buildProfileRow('🔒', 'Change Password', 'Update your login password', isDark, onTap: () {
              ChangePasswordModal.show(context);
            }),
            _buildProfileRow('🛡️', 'Two-Factor Auth', 'Not enabled', isDark, isLast: true, trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: _ProfColors.blueBg, borderRadius: BorderRadius.circular(6)),
              child: Text('Setup', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w800, color: _ProfColors.blue)),
            )),
          ],
        ),
        const SizedBox(height: 16),

        // Danger Zone (Rose bar)
        _buildSectionHeader('DANGER ZONE', '', _ProfColors.rose),
        const SizedBox(height: 8),
        _buildCardWrapper(
          isDark,
          children: [
            _buildProfileRow('🚪', 'Logout', 'Sign out of your account', isDark, isDanger: true, onTap: _openLogoutModal),
            _buildProfileRow('🗑️', 'Delete My Account', 'Permanently delete all data — cannot be undone', isDark, isDanger: true, isLast: true, onTap: () {
              DeleteAccountScreen.show(context);
            }),
          ],
        ),
      ],
    );
  }

  // ──── HELPER REUSABLE WIDGETS ────
  Widget _buildStatItem(String val, String lbl) {
    return Column(
      children: [
        Text(val, style: _ProfStyles.statNum),
        const SizedBox(height: 2),
        Text(lbl, style: _ProfStyles.statLbl),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String count, Color barColor) {
    return Row(
      children: [
        Container(width: 3.5, height: 18, decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: _ProfStyles.sectionTitle),
        if (count.isNotEmpty) ...[
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _ProfColors.paper,
              border: Border.all(color: _ProfColors.line),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(count, style: GoogleFonts.ibmPlexMono(fontSize: 10, fontWeight: FontWeight.w700, color: _ProfColors.muted)),
          ),
        ],
      ],
    );
  }

  Widget _buildCardWrapper(bool isDark, {required List<Widget> children}) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? _ProfColors.darkCard : _ProfColors.white,
          border: Border.all(color: isDark ? _ProfColors.darkLine : _ProfColors.line),
          borderRadius: BorderRadius.circular(18),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    );
  }

  Widget _buildProfileRow(
    String icon,
    String label,
    String subtitle,
    bool isDark, {
    VoidCallback? onTap,
    Widget? trailing,
    bool isDanger = false,
    bool isLast = false,
    String? hint,
  }) {
    final bool isEmpty = subtitle.trim().isEmpty;
    final String displayText = isEmpty ? (hint ?? 'Tap to add...') : subtitle;

    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          HapticFeedback.lightImpact();
          onTap();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDanger
                        ? _ProfColors.roseBg
                        : (isDark ? _ProfColors.dark : _ProfColors.goldBg),
                    border: Border.all(color: isDanger ? _ProfColors.roseLine : _ProfColors.goldLine),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Center(child: Text(icon, style: const TextStyle(fontSize: 16))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: _ProfStyles.rowLabel.copyWith(
                          color: isDanger ? _ProfColors.rose : (isDark ? Colors.white : _ProfColors.ink),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        displayText,
                        style: _ProfStyles.rowSub.copyWith(
                          color: isEmpty ? _ProfColors.faint : _ProfColors.muted,
                          fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                trailing ?? const Text('›', style: TextStyle(fontSize: 18, color: _ProfColors.faint, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (!isLast) Divider(height: 1, color: isDark ? _ProfColors.darkLine : _ProfColors.line),
        ],
      ),
    );
  }

  Widget _buildTemplateRow(String icon, String label, String subtitle, String pill, bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _ProfColors.greenBg,
                  border: Border.all(color: _ProfColors.greenLine),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(child: Text(icon, style: const TextStyle(fontSize: 16))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: _ProfStyles.rowLabel.copyWith(color: isDark ? Colors.white : _ProfColors.ink)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: _ProfStyles.rowSub),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _ProfColors.greenBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(pill, style: GoogleFonts.dmSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: _ProfColors.green)),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: isDark ? _ProfColors.darkLine : _ProfColors.line),
      ],
    );
  }
}
