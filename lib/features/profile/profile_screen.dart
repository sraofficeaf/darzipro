import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/build_info.dart';
import '../../core/utils/image_compressor.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/providers/supabase_providers.dart';
import '../../shared/providers/subscription_provider.dart';
import '../settings/add_template_modal.dart';
import 'change_password_modal.dart';
import 'delete_account_screen.dart';

// ── COLOR CONSTANTS ─────────────────────────────────────────────────────────
class _ProfColors {
  static const ink = Color(0xFF111827);
  static const muted = Color(0xFF7B8494);
  static const faint = Color(0xFFAAB2BF);
  static const line = Color(0xFFE8EAF0);
  static const paper = Color(0xFFF7F8FA);
  static const white = Color(0xFFFFFFFF);
  static const dark = Color(0xFF151922);
  static const darkCard = Color(0xFF1B202B);
  static const darkLine = Color(0xFF2E3544);

  static const gold = Color(0xFFE9A227);
  static const gold2 = Color(0xFFFFC65A);
  static const goldBg = Color(0xFFFFF6E5);
  static const goldLine = Color(0xFFF3DDA8);

  static const green = Color(0xFF18B887);
  static const greenBg = Color(0xFFEAFBF5);
  static const greenLine = Color(0xFFCFEFE3);

  static const rose = Color(0xFFEF5261);
  static const roseLine = Color(0xFFFFD9DE);

  static const blue = Color(0xFF5478E8);
}

// ── PROFILE SCREEN ──────────────────────────────────────────────────────────
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUploadingLogo = false;
  String _activeTab = 'shop'; // 'shop', 'plan', 'templates', 'settings'

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
        return 'Enter shop name';
      case 'owner name':
        return 'Enter owner name';
      case 'phone':
        return '03XX-XXXXXXX';
      case 'address':
        return 'Enter shop address';
      case 'card footer':
        return 'e.g. Thank you for your business!';
      default:
        return 'Enter $label';
    }
  }

  // ──── Helper: Resolve Logo URL ────
  String? _resolveLogoUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final clean = raw.trim();
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return clean;
    }
    return Supabase.instance.client.storage.from('shop-logos').getPublicUrl(clean);
  }

  // ──── Helper: Build Logo / Initials Avatar ────
  Widget _buildAvatar({
    required String? logoUrl,
    required String shopName,
    required double size,
    required double radius,
    double fontSize = 24,
  }) {
    final resolvedUrl = _resolveLogoUrl(logoUrl);
    if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF1D222D),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: const Color(0x80FFC65A), width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          resolvedUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildInitialsFallback(shopName, size, radius, fontSize);
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: size,
              height: size,
              color: const Color(0xFF1D222D),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(_ProfColors.gold),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
    return _buildInitialsFallback(shopName, size, radius, fontSize);
  }

  Widget _buildInitialsFallback(String shopName, double size, double radius, double fontSize) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_ProfColors.gold2, Color(0xFFD97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0x80FFC65A), width: 2),
      ),
      child: Center(
        child: Text(
          _getInitials(shopName),
          style: GoogleFonts.manrope(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
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
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final rawBytes = await picked.readAsBytes();
    if (rawBytes.length > ImageCompressor.maxUploadSizeBytes) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(isUrdu ? '⚠️ فائل بہت بڑی ہے (30 MB سے زیادہ)' : '⚠️ File too large (exceeds 30 MB).'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    setState(() => _isUploadingLogo = true);
    try {
      final compressed = await ImageCompressor.compressGarmentPhoto(rawBytes);
      final bytes = compressed.bytes;
      final storagePath = '$shopId/logo_${DateTime.now().millisecondsSinceEpoch}.jpg';

      debugPrint('[LogoUpload] Uploading $storagePath (${bytes.length} bytes)');

      final shop = ref.read(currentShopProvider).value;
      final oldLogo = shop?['logo_url'] as String?;
      if (oldLogo != null && oldLogo.isNotEmpty) {
        try {
          final oldPath = oldLogo.contains('shop-logos/')
              ? oldLogo.split('shop-logos/').last.split('?').first
              : oldLogo;
          if (!oldPath.startsWith('http')) {
            await Supabase.instance.client.storage.from('shop-logos').remove([oldPath]);
          }
        } catch (_) {}
      }

      await Supabase.instance.client.storage.from('shop-logos').uploadBinary(
        storagePath,
        bytes,
        fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
      );

      final publicUrl = Supabase.instance.client.storage.from('shop-logos').getPublicUrl(storagePath);
      await Supabase.instance.client.from('shops').update({'logo_url': publicUrl}).eq('id', shopId);

      ref.invalidate(currentShopProvider);
      ref.invalidate(profileProvider);

      messenger.showSnackBar(
        SnackBar(
          content: Text(isUrdu ? '✅ لوگو تبدیل ہو گیا!' : '✅ Logo updated successfully!'),
          backgroundColor: _ProfColors.green,
        ),
      );
    } catch (e) {
      debugPrint('[LogoUpload] Failed: $e');
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

  // ──── Save Shop Field ────
  Future<void> _updateShopField(String key, String value) async {
    final messenger = ScaffoldMessenger.of(context);
    final isUrdu = ref.read(localeProvider) == 'ur';

    final resolved = await _getResolvedShopAndUserId();
    final shopId = resolved.shopId;

    if (shopId == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(isUrdu ? '❌ ایرر: دکان کا اکاؤنٹ نہیں ملا!' : '❌ Error: Shop ID not found!'),
          backgroundColor: _ProfColors.rose,
        ),
      );
      return;
    }

    try {
      await Supabase.instance.client
          .from('shops')
          .update({key: value})
          .eq('id', shopId);

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

  // ──── Edit Single Field Modal ────
  void _openFieldEdit(String label, String initialValue, Future<void> Function(String) onSave, {int maxLines = 1, String? hintText}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController(text: initialValue);
    bool saving = false;
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit $label',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : _ProfColors.ink,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      maxLines: maxLines,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : _ProfColors.ink,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? _ProfColors.dark : _ProfColors.paper,
                        hintText: resolvedHint,
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

  // ──── Edit Profile Modal (Full) ────
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
            constraints: const BoxConstraints(maxWidth: 480),
            child: Dialog(
              backgroundColor: isDark ? _ProfColors.darkCard : _ProfColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
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
                                'Edit Shop Profile',
                                style: GoogleFonts.manrope(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : _ProfColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Update your shop and owner details.',
                                style: GoogleFonts.dmSans(fontSize: 12, color: _ProfColors.muted),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
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
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
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
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF211500)),
                                    )
                                  : Text(
                                      'Save Profile',
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
      ),
    );
  }

  Widget _buildFieldInput(String label, TextEditingController controller, bool isDark, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: _ProfColors.muted,
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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

  // ──── Logout Confirmation Modal ────
  void _openLogoutModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Dialog(
            backgroundColor: isDark ? _ProfColors.darkCard : _ProfColors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sign Out',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : _ProfColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Are you sure you want to sign out? Your business data remains safely synced in the cloud.',
                    style: GoogleFonts.dmSans(fontSize: 13, color: _ProfColors.muted, height: 1.5),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Sign Out', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
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

  // ═════════════════════════════════════════════════════════════════════════
  // MAIN BUILD METHOD
  // ═════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUrdu = ref.watch(localeProvider) == 'ur';

    // Watched Providers (Targeted & Reactive)
    final shopAsync = ref.watch(currentShopProvider);
    final profileAsync = ref.watch(profileProvider);
    final subAsync = ref.watch(subscriptionStateProvider);
    final templatesAsync = ref.watch(measurementTemplatesProvider);
    final baseStorageMb = ref.watch(baseStorageLimitMbProvider).valueOrNull ?? 1000;

    final shop = shopAsync.valueOrNull;
    final profile = profileAsync.valueOrNull;
    final sub = subAsync.valueOrNull;

    // Derived values
    final shopName = (shop?['name'] as String?)?.trim().isNotEmpty == true
        ? shop!['name'] as String
        : 'Darzi Pro Tailor Shop';
    final ownerName = (profile?['full_name'] as String?)?.trim().isNotEmpty == true
        ? profile!['full_name'] as String
        : 'Tailor Master';
    final phoneNum = (shop?['phone'] as String?) ?? '';
    final addressVal = (shop?['address'] as String?) ?? '';
    final logoUrl = shop?['logo_url'] as String?;

    final Box settingsBox = Hive.box('settings_box');
    final cardFooter = settingsBox.get('card_footer', defaultValue: '') as String;

    final planName = sub?.planNameEn ?? (subAsync.isLoading ? 'Loading...' : 'Free Trial');

    // Storage Calculations
    final usedBytes = (shop?['storage_used_bytes'] as int?) ?? 0;
    final double usedMb = (usedBytes / (1024 * 1024));
    final isAddonActive = shop?['storage_addon_active'] == true;
    final totalStorageBytes = baseStorageMb * 1024 * 1024;
    final double storageProgress = (usedBytes / totalStorageBytes).clamp(0.0, 1.0);
    final String baseStorageDisplay = baseStorageMb >= 1024 && baseStorageMb % 1024 == 0
        ? '${baseStorageMb ~/ 1024} GB'
        : (baseStorageMb >= 1000 && baseStorageMb % 1000 == 0
            ? '${baseStorageMb ~/ 1000} GB'
            : '$baseStorageMb MB');

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 960;

    return Directionality(
      textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: isDark ? _ProfColors.dark : _ProfColors.paper,
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 32 : 16,
              vertical: isDesktop ? 24 : 16,
            ),
            children: [
              // 1. TOP HERO HEADER (Single source of identity & branding)
              _buildHeroHeader(
                isDark: isDark,
                shopName: shopName,
                ownerName: ownerName,
                phone: phoneNum,
                address: addressVal,
                logoUrl: logoUrl,
                planName: planName,
                isDesktop: isDesktop,
              ),
              const SizedBox(height: 20),

              // 2. SEGMENTED TAB SELECTOR (Clean pill bar)
              _buildSegmentedTabBar(isDark),
              const SizedBox(height: 20),

              // 3. TAB CONTENT
              if (_activeTab == 'shop')
                _buildShopDetailsTab(
                  isDark: isDark,
                  shopName: shopName,
                  ownerName: ownerName,
                  phone: phoneNum,
                  address: addressVal,
                  cardFooter: cardFooter,
                  settingsBox: settingsBox,
                )
              else if (_activeTab == 'plan')
                _buildPlanAndStorageTab(
                  isDark: isDark,
                  sub: sub,
                  planName: planName,
                  usedMb: usedMb,
                  baseStorageDisplay: baseStorageDisplay,
                  storageProgress: storageProgress,
                  isAddonActive: isAddonActive,
                )
              else if (_activeTab == 'templates')
                _buildTemplatesTab(
                  isDark: isDark,
                  templatesAsync: templatesAsync,
                )
              else
                _buildSettingsAndSecurityTab(
                  isDark: isDark,
                  isUrdu: isUrdu,
                  settingsBox: settingsBox,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // SECTION 1: TOP HERO HEADER
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildHeroHeader({
    required bool isDark,
    required String shopName,
    required String ownerName,
    required String phone,
    required String address,
    required String? logoUrl,
    required String planName,
    required bool isDesktop,
  }) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 28 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF221A0F), const Color(0xFF161B24)]
              : [_ProfColors.goldBg, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _ProfColors.goldLine.withValues(alpha: 0.6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: isDesktop
          ? Row(
              children: [
                _buildAvatarSection(logoUrl, shopName, 80),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              shopName,
                              style: GoogleFonts.manrope(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : _ProfColors.ink,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _ProfColors.greenBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _ProfColors.greenLine),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: _ProfColors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Active Shop',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: _ProfColors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Owner: $ownerName ${phone.isNotEmpty ? "· $phone" : ""}',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _ProfColors.muted,
                        ),
                      ),
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          address,
                          style: GoogleFonts.dmSans(fontSize: 12, color: _ProfColors.muted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _buildHeroActionButtons(shopName, ownerName, phone, address, isDark),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildAvatarSection(logoUrl, shopName, 64),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shopName,
                            style: GoogleFonts.manrope(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : _ProfColors.ink,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ownerName,
                            style: GoogleFonts.dmSans(fontSize: 12.5, color: _ProfColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildHeroActionButtons(shopName, ownerName, phone, address, isDark),
              ],
            ),
    );
  }

  Widget _buildAvatarSection(String? logoUrl, String shopName, double size) {
    return Stack(
      children: [
        _buildAvatar(
          logoUrl: logoUrl,
          shopName: shopName,
          size: size,
          radius: size * 0.28,
          fontSize: size * 0.35,
        ),
        if (_isUploadingLogo)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(size * 0.28),
              ),
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: _ProfColors.gold),
                ),
              ),
            ),
          )
        else
          Positioned(
            right: 0,
            bottom: 0,
            child: InkWell(
              onTap: _pickAndUploadLogo,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: _ProfColors.gold,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.camera_alt_rounded, size: 13, color: Color(0xFF211500)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeroActionButtons(String sName, String oName, String phone, String address, bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: _pickAndUploadLogo,
          icon: const Icon(Icons.image_outlined, size: 16),
          label: Text('Change Logo', style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? Colors.white : _ProfColors.ink,
            side: BorderSide(color: isDark ? _ProfColors.darkLine : _ProfColors.line),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _openEditProfileModal(sName, oName, phone, address),
          icon: const Icon(Icons.edit_rounded, size: 16),
          label: Text('Edit Profile', style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w800)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _ProfColors.gold,
            foregroundColor: const Color(0xFF211500),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // SECTION 2: SEGMENTED TAB SELECTOR
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildSegmentedTabBar(bool isDark) {
    final tabs = [
      {'id': 'shop', 'label': 'Shop Details', 'icon': Icons.storefront_rounded},
      {'id': 'plan', 'label': 'Plan & Storage', 'icon': Icons.cloud_done_rounded},
      {'id': 'templates', 'label': 'Naap Templates', 'icon': Icons.straighten_rounded},
      {'id': 'settings', 'label': 'Settings & Security', 'icon': Icons.tune_rounded},
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? _ProfColors.darkCard : const Color(0xFFECEEF2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.map((tab) {
            final isActive = _activeTab == tab['id'];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                onTap: () => setState(() => _activeTab = tab['id'] as String),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isActive
                        ? (isDark ? const Color(0xFF2B3242) : Colors.white)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        tab['icon'] as IconData,
                        size: 16,
                        color: isActive
                            ? _ProfColors.gold
                            : (isDark ? _ProfColors.faint : _ProfColors.muted),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tab['label'] as String,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                          color: isActive
                              ? (isDark ? Colors.white : _ProfColors.ink)
                              : (isDark ? _ProfColors.faint : _ProfColors.muted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // SECTION 3: TAB 1 — SHOP DETAILS
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildShopDetailsTab({
    required bool isDark,
    required String shopName,
    required String ownerName,
    required String phone,
    required String address,
    required String cardFooter,
    required Box settingsBox,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildContentCard(
          isDark: isDark,
          title: 'Shop Information',
          subtitle: 'Core contact details printed on tokens, cards, and receipts.',
          children: [
            _buildDetailRow(
              isDark: isDark,
              icon: Icons.store_rounded,
              label: 'Shop Name',
              value: shopName,
              onEdit: () => _openFieldEdit('Shop Name', shopName, (val) => _updateShopField('name', val)),
            ),
            const Divider(height: 1),
            _buildDetailRow(
              isDark: isDark,
              icon: Icons.person_rounded,
              label: 'Owner Name',
              value: ownerName,
              onEdit: () => _openFieldEdit('Owner Name', ownerName, (val) => _updateProfileField('full_name', val)),
            ),
            const Divider(height: 1),
            _buildDetailRow(
              isDark: isDark,
              icon: Icons.phone_rounded,
              label: 'Phone Number',
              value: phone.isNotEmpty ? phone : 'Not specified',
              onEdit: () => _openFieldEdit('Phone', phone, (val) => _updateShopField('phone', val)),
            ),
            const Divider(height: 1),
            _buildDetailRow(
              isDark: isDark,
              icon: Icons.location_on_rounded,
              label: 'Shop Address',
              value: address.isNotEmpty ? address : 'Not specified',
              onEdit: () => _openFieldEdit('Address', address, (val) => _updateShopField('address', val), maxLines: 2),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildContentCard(
          isDark: isDark,
          title: 'Invoice & Print Settings',
          subtitle: 'Text printed at the bottom of customer slips and token cards.',
          children: [
            _buildDetailRow(
              isDark: isDark,
              icon: Icons.receipt_long_rounded,
              label: 'Card Footer Note',
              value: cardFooter.isNotEmpty ? cardFooter : 'e.g. Thank you for choosing us!',
              onEdit: () => _openFieldEdit(
                'Card Footer',
                cardFooter,
                (val) async {
                  await settingsBox.put('card_footer', val);
                  if (mounted) setState(() {});
                },
              ),
            ),
            const Divider(height: 1),
            _buildDetailRow(
              isDark: isDark,
              icon: Icons.payments_rounded,
              label: 'Operating Currency',
              value: 'PKR (Rs.) · Pakistani Rupee',
            ),
          ],
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // SECTION 4: TAB 2 — PLAN & CLOUD STORAGE
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildPlanAndStorageTab({
    required bool isDark,
    required SubscriptionState? sub,
    required String planName,
    required double usedMb,
    required String baseStorageDisplay,
    required double storageProgress,
    required bool isAddonActive,
  }) {
    final expiryDate = sub?.cycleEnd != null
        ? DateFormat.yMMMMd().format(sub!.cycleEnd!)
        : (sub?.trialStartedAt != null
            ? DateFormat.yMMMMd().format(sub!.trialStartedAt!.add(const Duration(days: 60)))
            : 'Active');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Subscription Card
        _buildContentCard(
          isDark: isDark,
          title: 'Subscription Status',
          subtitle: 'Current plan gating, renewal lifecycle, and feature access.',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_ProfColors.gold2, _ProfColors.gold]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      planName.toUpperCase(),
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF211500),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sub?.isLifetime == true ? 'Lifetime Access License' : 'Active Subscription · Darzi Pro',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : _ProfColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sub?.isLifetime == true ? 'No renewal required' : 'Cycle valid until $expiryDate',
                          style: GoogleFonts.dmSans(fontSize: 12, color: _ProfColors.muted),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => context.push('/subscription'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF2B3242) : _ProfColors.paper,
                      foregroundColor: isDark ? Colors.white : _ProfColors.ink,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Change Plan', style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Storage Quota Meter
        _buildContentCard(
          isDark: isDark,
          title: 'Cloud Storage Quota',
          subtitle: 'Dynamic storage utilized for measurements, garment photos, and cloth swatches.',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${usedMb.toStringAsFixed(2)} MB used of $baseStorageDisplay',
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : _ProfColors.ink,
                        ),
                      ),
                      Text(
                        '${(storageProgress * 100).toStringAsFixed(1)}%',
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: storageProgress > 0.9 ? _ProfColors.rose : _ProfColors.gold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: storageProgress,
                      minHeight: 10,
                      backgroundColor: isDark ? const Color(0xFF2B3242) : _ProfColors.line,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        storageProgress > 0.9 ? _ProfColors.rose : _ProfColors.gold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isAddonActive ? _ProfColors.greenBg : (isDark ? const Color(0xFF232A38) : _ProfColors.paper),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isAddonActive ? '✓ Storage Add-on Active (+5 GB)' : 'Standard Plan Quota',
                          style: GoogleFonts.dmSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isAddonActive ? _ProfColors.green : _ProfColors.muted,
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => context.push('/subscription'),
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                        label: Text('Upgrade Storage', style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w700)),
                        style: TextButton.styleFrom(foregroundColor: _ProfColors.gold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // SECTION 5: TAB 3 — NAAP TEMPLATES
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildTemplatesTab({
    required bool isDark,
    required AsyncValue<List<Map<String, dynamic>>> templatesAsync,
  }) {
    final templates = templatesAsync.valueOrNull ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildContentCard(
          isDark: isDark,
          title: 'Measurement Profiles (Naap Templates)',
          subtitle: 'Pre-configured measurement fields used when taking customer orders.',
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${templates.length} Active Templates',
                  style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: _ProfColors.muted),
                ),
                ElevatedButton.icon(
                  onPressed: () => AddTemplateModal.show(context),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text('Add Template', style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _ProfColors.gold,
                    foregroundColor: const Color(0xFF211500),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (templates.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No custom templates created yet. Default templates are available.',
                    style: GoogleFonts.dmSans(fontSize: 13, color: _ProfColors.muted),
                  ),
                ),
              )
            else
              ...templates.map((tpl) {
                final name = tpl['name'] as String? ?? 'Custom Template';
                final category = tpl['category'] as String? ?? 'General';
                final isDef = tpl['is_default'] == true;
                final fields = tpl['fields'] is List ? (tpl['fields'] as List).length : 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF222836) : _ProfColors.paper,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? _ProfColors.darkLine : _ProfColors.line),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _ProfColors.goldBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Icon(Icons.straighten_rounded, size: 20, color: _ProfColors.gold),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  name,
                                  style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : _ProfColors.ink,
                                  ),
                                ),
                                if (isDef) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _ProfColors.greenBg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Default',
                                      style: GoogleFonts.dmSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: _ProfColors.green),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Category: $category · $fields Measurement Fields',
                              style: GoogleFonts.dmSans(fontSize: 12, color: _ProfColors.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // SECTION 6: TAB 4 — SETTINGS & SECURITY
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildSettingsAndSecurityTab({
    required bool isDark,
    required bool isUrdu,
    required Box settingsBox,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // App Preferences
        _buildContentCard(
          isDark: isDark,
          title: 'Preferences',
          subtitle: 'Display appearance and localization.',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, size: 20, color: _ProfColors.gold),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Theme Mode', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : _ProfColors.ink)),
                        Text(isDark ? 'Dark theme active' : 'Light theme active', style: GoogleFonts.dmSans(fontSize: 12, color: _ProfColors.muted)),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: isDark,
                    activeTrackColor: _ProfColors.gold,
                    onChanged: (val) {
                      final newMode = val ? ThemeMode.dark : ThemeMode.light;
                      ref.read(themeModeProvider.notifier).state = newMode;
                      settingsBox.put('themeMode', val ? 'dark' : 'light');
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.language_rounded, size: 20, color: _ProfColors.blue),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('App Language', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : _ProfColors.ink)),
                        Text(isUrdu ? 'اردو (Urdu)' : 'English', style: GoogleFonts.dmSans(fontSize: 12, color: _ProfColors.muted)),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      final newLang = isUrdu ? 'en' : 'ur';
                      ref.read(localeProvider.notifier).setLanguage(newLang);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(isUrdu ? 'Switch to English' : 'اردو میں تبدیل کریں', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Security & Account
        _buildContentCard(
          isDark: isDark,
          title: 'Account Security',
          subtitle: 'Authentication and active sessions.',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.lock_reset_rounded, size: 20, color: _ProfColors.gold),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Change Password', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : _ProfColors.ink)),
                        Text('Update your login password regularly', style: GoogleFonts.dmSans(fontSize: 12, color: _ProfColors.muted)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => ChangePasswordModal.show(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF2B3242) : _ProfColors.paper,
                      foregroundColor: isDark ? Colors.white : _ProfColors.ink,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Change', style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.logout_rounded, size: 20, color: _ProfColors.rose),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sign Out', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : _ProfColors.ink)),
                        Text('Log out of this device', style: GoogleFonts.dmSans(fontSize: 12, color: _ProfColors.muted)),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _openLogoutModal,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ProfColors.rose,
                      side: const BorderSide(color: _ProfColors.roseLine),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Sign Out', style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Danger Zone
        _buildContentCard(
          isDark: isDark,
          title: 'Danger Zone',
          subtitle: 'Permanent account deletion and data removal.',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 20, color: _ProfColors.rose),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Delete Account', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: _ProfColors.rose)),
                        Text('Permanently delete your shop, orders, and customer records', style: GoogleFonts.dmSans(fontSize: 12, color: _ProfColors.muted)),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => DeleteAccountScreen.show(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ProfColors.rose,
                      side: const BorderSide(color: _ProfColors.rose),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Delete Account', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Build Info Badge
        Center(
          child: Text(
            BuildInfo.fullBuildTag,
            style: GoogleFonts.ibmPlexMono(fontSize: 11, color: _ProfColors.muted),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // REUSABLE CARD & ROW HELPERS
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildContentCard({
    required bool isDark,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? _ProfColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? _ProfColors.darkLine : _ProfColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : _ProfColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.dmSans(fontSize: 12, color: _ProfColors.muted),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required bool isDark,
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onEdit,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _ProfColors.gold),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _ProfColors.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.dmSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : _ProfColors.ink,
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            TextButton(
              onPressed: onEdit,
              style: TextButton.styleFrom(
                foregroundColor: _ProfColors.gold,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              child: Text(
                'Edit',
                style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }
}
