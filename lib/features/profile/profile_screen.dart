import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/plan_utils.dart';
import '../../core/constants/app_enums.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/providers/supabase_providers.dart';
import '../../shared/providers/license_provider.dart';
import '../../core/services/update_service.dart';
import '../../core/widgets/update_dialog.dart';
import '../settings/add_template_modal.dart';
import 'change_password_modal.dart';
import 'delete_account_screen.dart';
import '../upgrade/upgrade_request_screen.dart';
import '../storage/storage_addon_modal.dart';


// ─────────────────────────────────────────────────────────────────
// ✨ REDESIGNED PREMIUM PROFILE SCREEN
// ─────────────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with TickerProviderStateMixin {
  bool _isUploadingLogo = false;
  bool _isInitialized = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
    _isInitialized = true;
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
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

    if (shopId == null && userId != null) {
      try {
        final shopRes = await Supabase.instance.client
            .from('shops')
            .select('id')
            .eq('owner_id', userId)
            .maybeSingle();
        shopId = shopRes?['id'] as String?;
      } catch (_) {}
    }

    if (shopId == null) {
      final shop = ref.read(currentShopProvider).value;
      shopId = shop?['id'] as String?;
    }

    return (shopId: shopId, userId: userId);
  }

  // ──── Logo upload ────
  Future<void> _pickAndUploadLogo() async {
    final messenger = ScaffoldMessenger.of(context);
    final isUrdu = ref.read(localeProvider) == 'ur';

    final resolved = await _getResolvedShopAndUserId();
    final shopId = resolved.shopId;
    if (shopId == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isUrdu
                ? '❌ ایرر: دکان کی معلومات نہیں ملیں!'
                : '❌ Error: Shop ID not found!',
          ),
          backgroundColor: AppColors.red,
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
      final storagePath =
          '$shopId/logo_${DateTime.now().millisecondsSinceEpoch}.$extension';

      final shop = ref.read(currentShopProvider).value;
      final oldLogo = shop?['logo_url'] as String?;
      if (oldLogo != null && oldLogo.isNotEmpty && !oldLogo.startsWith('http')) {
        try {
          await Supabase.instance.client.storage.from('shop-logos').remove([
            oldLogo,
          ]);
        } catch (_) {}
      }

      await Supabase.instance.client.storage
          .from('shop-logos')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: 'image/$extension'),
          );

      await Supabase.instance.client
          .from('shops')
          .update({'logo_url': storagePath})
          .eq('id', shopId);

      ref.invalidate(currentShopProvider);
      ref.invalidate(profileProvider);

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isUrdu ? '✅ لوگو تبدیل ہو گیا!' : '✅ Logo updated successfully!',
          ),
          backgroundColor: AppColors.teal,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('❌ Upload failed: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
    }
  }

  // ──── Save profile field updates ────
  Future<void> _updateShopField(String key, String value) async {
    final messenger = ScaffoldMessenger.of(context);
    final isUrdu = ref.read(localeProvider) == 'ur';

    final resolved = await _getResolvedShopAndUserId();
    final shopId = resolved.shopId;
    if (shopId == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(isUrdu ? '❌ ایرر: دکان کا اکاؤنٹ نہیں ملا!' : '❌ Error: Shop account not found!'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    try {
      await Supabase.instance.client
          .from('shops')
          .update({key: value})
          .eq('id', shopId);

      if (key == 'name') {
        try {
          await Supabase.instance.client
              .from('licenses')
              .update({'shop_name': value})
              .eq('shop_id', shopId);
        } catch (_) {}
      }

      ref.invalidate(currentShopProvider);
      ref.invalidate(profileProvider);

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isUrdu ? '✅ معلومات محفوظ ہو گئیں!' : '✅ Field updated successfully!',
          ),
          backgroundColor: AppColors.teal,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('❌ Save failed: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  Future<void> _updateProfileField(String key, String value) async {
    final messenger = ScaffoldMessenger.of(context);
    final isUrdu = ref.read(localeProvider) == 'ur';

    final resolved = await _getResolvedShopAndUserId();
    final userId = resolved.userId;
    final shopId = resolved.shopId;

    if (userId == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(isUrdu ? '❌ ایرر: یوزر اکاؤنٹ نہیں ملا!' : '❌ Error: User account not found!'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    try {
      await Supabase.instance.client
          .from('profiles')
          .update({key: value})
          .eq('id', userId);

      // Also try to update owner_name in shops table if shop exists
      if (shopId != null && key == 'full_name') {
        try {
          await Supabase.instance.client
              .from('shops')
              .update({'owner_name': value})
              .eq('id', shopId);
        } catch (_) {}
      }

      ref.invalidate(profileProvider);
      ref.invalidate(currentShopProvider);

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isUrdu ? '✅ معلومات محفوظ ہو گئیں!' : '✅ Profile updated successfully!',
          ),
          backgroundColor: AppColors.teal,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('❌ Save failed: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }







  // ──── Edit dialog for a single field ────
  void _showSingleFieldEditDialog({
    required String title,
    required String label,
    required String initialValue,
    required Future<void> Function(String) onSave,
    int maxLines = 1,
  }) {
    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? AppColors.surfDark : AppColors.surfLight;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final isUrdu = ref.read(localeProvider) == 'ur';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: surf,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: const EdgeInsets.all(20),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      color: t1,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppTextField(
                    label: label,
                    controller: controller,
                    maxLines: maxLines,
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AppOutlineButton(
                        label: isUrdu ? 'منسوخ' : 'Cancel',
                        textColor: t2,
                        borderColor: border,
                        onTap: () => Navigator.pop(ctx),
                      ),
                      const SizedBox(width: 12),
                      GoldButton(
                        onPressed: saving
                            ? null
                            : () async {
                                if (formKey.currentState?.validate() != true) return;
                                setDialogState(() => saving = true);
                                final navigator = Navigator.of(ctx);
                                try {
                                  await onSave(controller.text.trim());
                                  if (ctx.mounted) navigator.pop();
                                } catch (_) {
                                } finally {
                                  setDialogState(() => saving = false);
                                }
                              },
                        child: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF1A0F00),
                                ),
                              )
                            : Text(
                                isUrdu ? 'محفوظ کریں' : 'Save',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
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

  // ──── Edit Profile Dialog (combining all fields) ────
  void _showEditProfileDialog(
    String currentShopName,
    String currentOwnerName,
    String currentPhone,
    String currentAddress,
  ) {
    final shopCtrl = TextEditingController(text: currentShopName);
    final ownerCtrl = TextEditingController(text: currentOwnerName);
    final phoneCtrl = TextEditingController(text: currentPhone);
    final addressCtrl = TextEditingController(text: currentAddress);
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? AppColors.surfDark : AppColors.surfLight;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final isUrdu = ref.read(localeProvider) == 'ur';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: surf,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: const EdgeInsets.all(20),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isUrdu ? 'پروفائل ایڈٹ کریں' : 'Edit Profile',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w900,
                        color: t1,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 20),
                    AppTextField(
                      label: isUrdu ? 'دکان کا نام' : 'Shop Name',
                      controller: shopCtrl,
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    AppTextField(
                      label: isUrdu ? 'مالک کا نام' : 'Owner Name',
                      controller: ownerCtrl,
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    AppTextField(
                      label: isUrdu ? 'فون نمبر' : 'Phone',
                      controller: phoneCtrl,
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    AppTextField(
                      label: isUrdu ? 'پتہ' : 'Address',
                      controller: addressCtrl,
                      maxLines: 2,
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AppOutlineButton(
                          label: isUrdu ? 'منسوخ' : 'Cancel',
                          textColor: t2,
                          borderColor: border,
                          onTap: () => Navigator.pop(ctx),
                        ),
                        const SizedBox(width: 12),
                        GoldButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  if (formKey.currentState?.validate() != true) return;
                                  setDialogState(() => saving = true);

                                  final messenger = ScaffoldMessenger.of(context);
                                  final navigator = Navigator.of(ctx);

                                  try {
                                    final resolved = await _getResolvedShopAndUserId();
                                    final shopId = resolved.shopId;
                                    final userId = resolved.userId;

                                    if (shopId == null) {
                                      throw Exception(isUrdu ? 'دکان کی معلومات نہیں ملیں' : 'Shop account not found');
                                    }

                                    final sName = shopCtrl.text.trim();
                                    final oName = ownerCtrl.text.trim();
                                    final sPhone = phoneCtrl.text.trim();
                                    final sAddr = addressCtrl.text.trim();

                                    // 1. Update shops table
                                    await Supabase.instance.client
                                        .from('shops')
                                        .update({
                                          'name': sName,
                                          'phone': sPhone,
                                          'address': sAddr,
                                        })
                                        .eq('id', shopId);

                                    // 2. Update owner_name in shops table if present
                                    try {
                                      await Supabase.instance.client
                                          .from('shops')
                                          .update({'owner_name': oName})
                                          .eq('id', shopId);
                                    } catch (_) {}

                                    // 3. Update profiles table
                                    if (userId != null) {
                                      await Supabase.instance.client
                                          .from('profiles')
                                          .update({'full_name': oName})
                                          .eq('id', userId);
                                    }

                                    // 4. Update licenses table
                                    try {
                                      await Supabase.instance.client
                                          .from('licenses')
                                          .update({
                                            'shop_name': sName,
                                            'phone': sPhone,
                                          })
                                          .eq('shop_id', shopId);
                                    } catch (_) {}

                                    ref.invalidate(currentShopProvider);
                                    ref.invalidate(profileProvider);
                                    ref.invalidate(licenseProvider);

                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          isUrdu
                                              ? '✅ معلومات محفوظ ہو گئیں!'
                                              : '✅ Profile saved successfully!',
                                        ),
                                        backgroundColor: AppColors.teal,
                                      ),
                                    );
                                    navigator.pop();
                                  } catch (e) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('❌ Save failed: $e'),
                                        backgroundColor: AppColors.red,
                                      ),
                                    );
                                  } finally {
                                    setDialogState(() => saving = false);
                                  }
                                },
                          child: saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF1A0F00),
                                  ),
                                )
                              : Text(
                                  isUrdu ? 'محفوظ کریں' : 'Save',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold),
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

  // ──── Language Selector Dialog ────
  void _showLanguagePickerDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? AppColors.surfDark : AppColors.surfLight;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final isUrdu = ref.read(localeProvider) == 'ur';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          isUrdu ? 'زبان منتخب کریں' : 'Select Language',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: t1, fontSize: 20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('English', style: GoogleFonts.inter(color: t1, fontWeight: FontWeight.w600)),
              trailing: !isUrdu ? const Icon(Icons.check_rounded, color: Color(0xFFD97706)) : null,
              onTap: () {
                Navigator.pop(ctx);
                ref.read(localeProvider.notifier).setLanguage('en');
              },
            ),
            ListTile(
              title: Text('اردو', style: GoogleFonts.inter(color: t1, fontWeight: FontWeight.w600)),
              trailing: isUrdu ? const Icon(Icons.check_rounded, color: Color(0xFFD97706)) : null,
              onTap: () {
                Navigator.pop(ctx);
                ref.read(localeProvider.notifier).setLanguage('ur');
              },
            ),
          ],
        ),
      ),
    );
  }

  // ──── Logout Confirmation Dialog ────
  void _showLogoutConfirmationDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? AppColors.surfDark : AppColors.surfLight;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final isUrdu = ref.read(localeProvider) == 'ur';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          isUrdu ? 'لاگ آؤٹ تصدیق' : 'Logout Confirmation',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: t1, fontSize: 20),
        ),
        content: Text(
          isUrdu ? 'کیا آپ واقعی لاگ آؤٹ کرنا چاہتے ہیں؟' : 'Are you sure you want to logout?',
          style: GoogleFonts.inter(color: t2),
        ),
        actions: [
          AppOutlineButton(
            label: isUrdu ? 'منسوخ' : 'Cancel',
            textColor: t2,
            borderColor: border,
            onTap: () => Navigator.pop(ctx),
          ),
          const SizedBox(width: 12),
          GoldButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _handleLogout();
            },
            child: Text(
              isUrdu ? 'لاگ آؤٹ' : 'Logout',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) context.go('/login');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(currentShopProvider);
    final profileAsync = ref.watch(profileProvider);
    final isUrdu = ref.watch(localeProvider) == 'ur';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF060C18) : AppColors.bgLight;

    if ((shopAsync.isLoading || profileAsync.isLoading) && !_isInitialized) {
      return const _ProfileSkeleton();
    }
    if (shopAsync.hasError || profileAsync.hasError) {
      return _ProfileError(
        message: (shopAsync.error ?? profileAsync.error).toString(),
        onRetry: () {
          ref.invalidate(currentShopProvider);
          ref.invalidate(profileProvider);
        },
      );
    }

    final shop = shopAsync.value;
    final shopName = shop?['name'] as String? ?? 'SaifurRahman Tailors';
    final logoUrl = shop?['logo_url'] as String?;
    final ownerName =
        profileAsync.value?['full_name'] as String? ?? 'SaifurRahman';
    final phoneNum = shop?['phone'] as String? ?? '0300-1234567';
    final addressVal = shop?['address'] as String? ?? 'Saddar Bazaar, Peshawar';
    final templatesAsync = ref.watch(measurementTemplatesProvider);

    final Box settingsBox = Hive.box('settings_box');
    final cardFooter = settingsBox.get(
      'card_footer',
      defaultValue: 'Thank you for your business!',
    ) as String;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 1024;

    // SECTION 1: Shop Profile Card
    final section1 = _ProfileSection(
      title: isUrdu ? 'دکان کی پروفائل' : 'Shop Profile',
      children: [
        _ProfileRow(
          icon: Text('🏪', style: GoogleFonts.inter(fontSize: 15)),
          label: isUrdu ? 'دکان کا نام' : 'Shop Name',
          subtitle: shopName,
          onTap: () => _showSingleFieldEditDialog(
            title: isUrdu ? 'دکان کا نام ایڈٹ کریں' : 'Edit Shop Name',
            label: isUrdu ? 'دکان کا نام' : 'Shop Name',
            initialValue: shopName,
            onSave: (val) => _updateShopField('name', val),
          ),
        ),
        _ProfileRow(
          icon: Text('👤', style: GoogleFonts.inter(fontSize: 15)),
          label: isUrdu ? 'مالک کا نام' : 'Owner Name',
          subtitle: ownerName,
          onTap: () => _showSingleFieldEditDialog(
            title: isUrdu ? 'مالک کا نام ایڈٹ کریں' : 'Edit Owner Name',
            label: isUrdu ? 'مالک کا نام' : 'Owner Name',
            initialValue: ownerName,
            onSave: (val) => _updateProfileField('full_name', val),
          ),
        ),
        _ProfileRow(
          icon: Text('📞', style: GoogleFonts.inter(fontSize: 15)),
          label: isUrdu ? 'فون نمبر' : 'Phone',
          subtitle: phoneNum,
          onTap: () => _showSingleFieldEditDialog(
            title: isUrdu ? 'فون نمبر ایڈٹ کریں' : 'Edit Phone',
            label: isUrdu ? 'فون نمبر' : 'Phone',
            initialValue: phoneNum,
            onSave: (val) => _updateShopField('phone', val),
          ),
        ),
        _ProfileRow(
          icon: Text('📍', style: GoogleFonts.inter(fontSize: 15)),
          label: isUrdu ? 'پتہ' : 'Address',
          subtitle: addressVal,
          onTap: () => _showSingleFieldEditDialog(
            title: isUrdu ? 'پتہ ایڈٹ کریں' : 'Edit Address',
            label: isUrdu ? 'پتہ' : 'Address',
            initialValue: addressVal,
            maxLines: 2,
            onSave: (val) => _updateShopField('address', val),
          ),
        ),
        _ProfileRow(
          icon: Text('🪪', style: GoogleFonts.inter(fontSize: 15)),
          label: isUrdu ? 'کارڈ فوٹر' : 'Card Footer',
          subtitle: cardFooter,
          showBorder: false,
          onTap: () => _showSingleFieldEditDialog(
            title: isUrdu ? 'کارڈ فوٹر ایڈٹ کریں' : 'Edit Card Footer',
            label: isUrdu ? 'کارڈ فوٹر' : 'Card Footer',
            initialValue: cardFooter,
            onSave: (val) async {
              await settingsBox.put('card_footer', val);
              if (mounted) setState(() {});
            },
          ),
        ),
      ],
    );

    // SECTION 2: Measurement Templates Card
    final section2 = _ProfileSection(
      title: isUrdu ? 'ناپ کے ٹیمپلیٹ' : 'Measurement Templates',
      children: [
        ...templatesAsync.when(
          data: (templates) {
            return templates.map((t) {
              final tName = t['name'] as String? ?? '';
              final isWomen = tName.toLowerCase().contains('women') ||
                  tName.toLowerCase().contains('kurti') ||
                  tName.toLowerCase().contains('suit');
              return _ProfileRow(
                icon: Text(isWomen ? '👗' : '👔', style: GoogleFonts.inter(fontSize: 15)),
                label: tName,
                subtitle: isUrdu ? 'ڈیفالٹ ٹیمپلیٹ' : 'Default Template',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x2610CBA0) : AppColors.lightTealBg,
                    border: Border.all(color: isDark ? const Color(0x4D10CBA0) : AppColors.lightTealBorder, width: 1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isUrdu ? 'ڈیفالٹ' : 'Default',
                    style: GoogleFonts.inter(
                      color: isDark ? const Color(0xFF10CBA0) : AppColors.lightTeal,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                onTap: () {},
              );
            }).toList();
          },
          loading: () => [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          ],
          error: (e, s) => [
            ListTile(
              title: Text(isUrdu ? 'ٹیمپلیٹس لوڈ نہیں ہوسکے' : 'Failed to load templates'),
            )
          ],
        ),
        _ProfileRow(
          icon: Text('➕', style: GoogleFonts.inter(fontSize: 15)),
          label: isUrdu ? 'نیا ٹیمپلیٹ بنائیں' : 'Add Custom Template',
          subtitle: isUrdu ? 'نیا ماپ کا ٹیمپلیٹ بنائیں' : 'Create new measurement set',
          iconBoxBg: isDark ? const Color(0x1A10CBA0) : AppColors.lightTealBg,
          iconBoxBorder: isDark ? const Color(0x3310CBA0) : AppColors.lightTealBorder,
          labelColor: isDark ? const Color(0xFF10CBA0) : AppColors.lightTeal,
          showBorder: false,
          trailing: const SizedBox(),
          onTap: () {
            AddTemplateModal.show(context);
          },
        ),
      ],
    );

    // SECTION 3: App Settings Card
    final section3 = _ProfileSection(
      title: isUrdu ? 'ایپ کی سیٹنگز' : 'App Settings',
      children: [
        _ProfileRow(
          icon: Text(isDark ? '☀️' : '🌙', style: GoogleFonts.inter(fontSize: 15)),
          label: isUrdu ? 'تھیم' : 'Theme',
          subtitle: isDark
              ? (isUrdu ? 'لائٹ موڈ' : 'Light Mode')
              : (isUrdu ? 'ڈارک موڈ' : 'Dark Mode'),
          trailing: _CustomToggle(
            value: isDark,
            onChanged: (val) {
              final newMode = val ? ThemeMode.dark : ThemeMode.light;
              ref.read(themeModeProvider.notifier).state = newMode;
              Hive.box('settings_box').put('themeMode', val ? 'dark' : 'light');
            },
          ),
          onTap: () {
            final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
            ref.read(themeModeProvider.notifier).state = newMode;
            Hive.box('settings_box').put('themeMode', isDark ? 'light' : 'dark');
          },
        ),
        _ProfileRow(
          icon: Text('🌐', style: GoogleFonts.inter(fontSize: 15)),
          label: isUrdu ? 'زبان' : 'Language',
          subtitle: isUrdu ? 'اردو' : 'English',
          onTap: _showLanguagePickerDialog,
        ),
        _ProfileRow(
          icon: Text('🔄', style: GoogleFonts.inter(fontSize: 15)),
          label: isUrdu ? 'اپڈیٹ چیک کریں' : 'Check for Updates',
          subtitle: isUrdu ? 'ورژن 1.0.0' : 'Version 1.0.0',
          showBorder: false,
          onTap: () async {
            final scaffoldMessenger = ScaffoldMessenger.of(context);
            final currentContext = context;
            try {
              final updateService = UpdateService();
              final updateInfo = await updateService.checkForUpdate();
              if (updateInfo != null) {
                if (currentContext.mounted) {
                  showDialog(
                    context: currentContext,
                    builder: (_) => UpdateDialog(update: updateInfo),
                  );
                }
              } else {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      isUrdu ? 'ایپ اپ ٹو ڈیٹ ہے!' : 'App is up to date!',
                    ),
                    backgroundColor: AppColors.teal,
                  ),
                );
              }
            } catch (e) {
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text('Failed: $e'),
                  backgroundColor: AppColors.red,
                ),
              );
            }
          },
        ),
      ],
    );

    // SECTION 4: Security & Danger Zone Card
    final section4 = Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0x08FFFFFF) : context.surface,
        border: Border.all(color: isDark ? const Color(0x12FFFFFF) : context.border, width: 1),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : context.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Security Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: isDark ? const Color(0x0DFFFFFF) : context.border, width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5B72F5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  (isUrdu ? 'سیکیورٹی' : 'Security').toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF5A7090),
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          _ProfileRow(
            icon: Text('🔒', style: GoogleFonts.inter(fontSize: 15)),
            label: isUrdu ? 'پاس ورڈ تبدیل کریں' : 'Change Password',
            subtitle: isUrdu ? 'لاگ ان پاس ورڈ اپ ڈیٹ کریں' : 'Update your login password',
            iconBoxBg: const Color(0x1F5B72F5),
            iconBoxBorder: const Color(0x335B72F5),
             onTap: () => ChangePasswordModal.show(context),
          ),
          // License Key row removed — not meaningful in the 3-tier plan model.
          // Plan is shown via the dedicated '⭐ License Plan' row above.
          // Danger Zone Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: isDark ? const Color(0x0DFFFFFF) : context.border, width: 1),
                bottom: BorderSide(color: isDark ? const Color(0x0DFFFFFF) : context.border, width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3A58),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  (isUrdu ? 'خطرناک زون' : 'Danger Zone').toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFFF3A58),
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          _ProfileRow(
            icon: Text('🚪', style: GoogleFonts.inter(fontSize: 15)),
            label: isUrdu ? 'لاگ آؤٹ' : 'Logout',
            subtitle: isUrdu ? 'ایپ سے سائن آؤٹ کریں' : 'Sign out of your account',
            iconBoxBg: const Color(0x1AFF3A58), // rgba(255,58,88,0.1)
            iconBoxBorder: const Color(0x33FF3A58), // rgba(255,58,88,0.2)
            labelColor: const Color(0xFFFF3A58),
            hoverColor: const Color(0x0DFF3A58), // rgba(255,58,88,0.05)
            trailing: const SizedBox(),
            onTap: _showLogoutConfirmationDialog,
          ),
          _ProfileRow(
            icon: Text('🗑️', style: GoogleFonts.inter(fontSize: 15)),
            label: isUrdu ? 'اکاؤنٹ ڈیلیٹ کریں' : 'Delete My Account',
            subtitle: isUrdu
                ? 'تمام ڈیٹا مستقل طور پر ڈیلیٹ ہو جائے گا'
                : 'Permanently delete all data — cannot be undone',
            iconBoxBg: const Color(0x1AFF3A58),
            iconBoxBorder: const Color(0x33FF3A58),
            labelColor: const Color(0xFFFF3A58),
            hoverColor: const Color(0x0DFF3A58),
            showBorder: false,
            trailing: const SizedBox(),
            onTap: () => DeleteAccountScreen.show(context),
          ),
        ],
      ),
    );

    final planStorageSection = _buildPlanStorageSection(context, ref);

    Widget buildGrid() {
      if (isDesktop) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  section1,
                  const SizedBox(height: 16),
                  planStorageSection,
                  const SizedBox(height: 16),
                  section2,
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  section3,
                  const SizedBox(height: 16),
                  section4,
                ],
              ),
            ),
          ],
        );
      } else {
        return Column(
          children: [
            section1,
            const SizedBox(height: 16),
            planStorageSection,
            const SizedBox(height: 16),
            section2,
            const SizedBox(height: 16),
            section3,
            const SizedBox(height: 16),
            section4,
          ],
        );
      }
    }

    return Directionality(
      textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,

      child: Scaffold(
        backgroundColor: bg,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [const Color(0xFF060C18), const Color(0xFF060C18)]
                  : [const Color(0xFFF8F9FA), const Color(0xFFE9ECEF)],
            ),
          ),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProfileHero(
                    shopName: shopName,
                    logoUrl: logoUrl,
                    ownerName: ownerName,
                    phoneNum: phoneNum,
                    addressVal: addressVal,
                    isUploadingLogo: _isUploadingLogo,
                    onEditProfile: () => _showEditProfileDialog(
                      shopName,
                      ownerName,
                      phoneNum,
                      addressVal,
                    ),
                    onChangeLogo: _pickAndUploadLogo,
                  ),
                  const SizedBox(height: 24),
                  buildGrid(),
                  const SizedBox(height: 24),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text.rich(
                        TextSpan(
                          text: isUrdu ? 'درزی پرو · ورژن 1.0.0 · ' : 'Darzi Pro · v1.0.0 · ',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF2A3E58),
                            fontWeight: FontWeight.w600,
                          ),
                          children: [
                            TextSpan(
                              text: isUrdu
                                  ? 'پشاور کے درزیوں کے لیے پیار سے تیار کردہ ❤️'
                                  : 'Made with ❤️ for tailors in Peshawar',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF3A5070),
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
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

  Widget _buildPlanStorageSection(BuildContext context, WidgetRef ref) {
    final isDark = context.isDark;
    final isUrdu = ref.watch(localeProvider) == 'ur';
    final shop = ref.watch(currentShopProvider).value;
    // Read plan from licenseProvider (correctly synced from DB via currentShopIdProvider)
    // Never fall back to shop['licenses']['plan'] — shops table has no plan column and
    // currentShopProvider does not embed licenses.
    final license = ref.watch(licenseProvider);
    final plan = license.plan.toLowerCase();
    final (planLabel, planColor) = AppPlanUtils.getDisplayInfo(plan, isUrdu: isUrdu);

    final isAddonActive = shop?['storage_addon_active'] == true;
    final bundledStorageExp = shop?['bundled_storage_expires_at'] as String?;
    final is3YrActive = bundledStorageExp != null &&
        DateTime.tryParse(bundledStorageExp) != null &&
        DateTime.now().isBefore(DateTime.parse(bundledStorageExp));
    final isUnlimited = isAddonActive || is3YrActive;

    final usedBytes = (shop?['storage_used_bytes'] as int?) ?? 0;
    final double progress = isUnlimited ? 1.0 : (usedBytes / 1500000).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x08FFFFFF) : context.surface,
        border: Border.all(color: isDark ? const Color(0x12FFFFFF) : context.border, width: 1),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : context.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                (isUrdu ? 'پلان اور سٹوریج کی معلومات' : 'Plan & Storage Management').toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF5A7090),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Plan Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isUrdu ? 'موجودہ لائسنس پلان' : 'Current Plan',
                    style: GoogleFonts.inter(fontSize: 12, color: context.text2),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    planLabel,
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: context.text1),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: planColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: planColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  planLabel,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: planColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: isDark ? const Color(0x0DFFFFFF) : context.border, height: 1),
          const SizedBox(height: 16),

          // Storage Usage & Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isUrdu ? 'کلاؤڈ سٹوریج' : 'Cloud Storage',
                style: GoogleFonts.inter(fontSize: 12, color: context.text2),
              ),
              Text(
                isUnlimited
                    ? (isUrdu ? 'لامحدود سٹوریج (فعال)' : 'Unlimited Storage (Active)')
                    : (isUrdu ? 'محدود سٹوریج' : 'Limited Storage'),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isUnlimited ? const Color(0xFF10B981) : context.text1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                isUnlimited ? const Color(0xFF10B981) : (progress >= 0.8 ? Colors.orange : AppColors.accent),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // TWO PERSISTENT ACTION BUTTONS
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const UpgradeRequestScreen(),
                    );
                  },
                  icon: const Icon(Icons.upgrade_rounded, size: 16),
                  label: Text(isUrdu ? 'پلان اپ گریڈ کریں' : 'Upgrade Plan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => StorageAddonModal.show(context),
                  icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                  label: Text(isUrdu ? 'سٹوریج خریدیں' : 'Buy Storage'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                    side: const BorderSide(color: Color(0xFF10B981)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────

// 🧩 REDESIGNED INTERNAL PROFILE WIDGETS
// ─────────────────────────────────────────────────────────────────

class _ProfileHero extends ConsumerWidget {
  final String shopName;
  final String? logoUrl;
  final String ownerName;
  final String phoneNum;
  final String addressVal;
  final bool isUploadingLogo;
  final VoidCallback onEditProfile;
  final VoidCallback onChangeLogo;

  const _ProfileHero({
    required this.shopName,
    required this.logoUrl,
    required this.ownerName,
    required this.phoneNum,
    required this.addressVal,
    required this.isUploadingLogo,
    required this.onEditProfile,
    required this.onChangeLogo,
  });

  String getInitials(String name) {
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

  Widget _buildStatItem(BuildContext context, String value, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? const Color(0xFFEDF4FF) : context.text1,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: context.text2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logo = logoUrl;
    final isUrdu = ref.watch(localeProvider) == 'ur';
    final license = ref.watch(licenseProvider);
    final customersAsync = ref.watch(customersProvider);
    final ordersAsync = ref.watch(ordersProvider);

    final clientsCount = customersAsync.value?.length ?? 0;
    final activeOrdersCount = ordersAsync.value?.where((o) =>
        o.status == OrderStatus.pending ||
        o.status == OrderStatus.cutting ||
        o.status == OrderStatus.stitching ||
        o.status == OrderStatus.ready).length ?? 0;
    final planLabel = AppPlanUtils.getLabel(license.plan, isUrdu: isUrdu);

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 680;
    final logoSize = isCompact ? 68.0 : 88.0;

    // LEFT: Logo/Avatar Stack
    final logoWidget = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isCompact ? 16 : 20),
            border: Border.all(color: isDark ? const Color(0x66D97706) : AppColors.lightAccentBorder, width: 1.5),
            color: isDark ? const Color(0x14D97706) : AppColors.lightAccentBg,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isCompact ? 13 : 16),
            child: logo == null || logo.isEmpty
                ? Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFD97706), Color(0xFFB45309)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        getInitials(shopName),
                        style: GoogleFonts.outfit(
                          fontSize: isCompact ? 22 : 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                : Image.network(
                    logo.startsWith('http') || logo.startsWith('assets')
                        ? logo
                        : '${SupabaseConfig.shopLogosUrl}/$logo',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFD97706), Color(0xFFB45309)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          getInitials(shopName),
                          style: GoogleFonts.outfit(
                            fontSize: isCompact ? 22 : 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        Positioned(
          bottom: 2,
          right: 2,
          child: Container(
            width: isCompact ? 10 : 12,
            height: isCompact ? 10 : 12,
            decoration: BoxDecoration(
              color: const Color(0xFF10CBA0),
              shape: BoxShape.circle,
              border: Border.all(color: isDark ? const Color(0xFF060C18) : context.surface, width: 1.5),
            ),
          ),
        ),
      ],
    );

    // Subtitle text (Dynamic owner + location or tailor suite)
    final subtitleText = ownerName.isNotEmpty
        ? (addressVal.isNotEmpty ? '$ownerName · ${addressVal.split(',').first.trim()}' : ownerName)
        : (isUrdu ? 'درزی پرو ٹیلر شاپ' : 'Darzi Pro Tailor Shop');

    // CENTER: Info
    final infoWidget = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          isDark
              ? ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFF5A623), Color(0xFFFFD080)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Text(
                    shopName,
                    style: GoogleFonts.outfit(
                      fontSize: isCompact ? 20 : 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              : Text(
                  shopName,
                  style: GoogleFonts.outfit(
                    fontSize: isCompact ? 20 : 26,
                    fontWeight: FontWeight.w900,
                    color: context.text1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          const SizedBox(height: 3),
          Text(
            subtitleText,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: context.text2,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (!isCompact) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0x10FFFFFF) : const Color(0x08000000),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0x14FFFFFF) : const Color(0x10000000)),
              ),
              child: Row(
                children: [
                  Expanded(child: _buildStatItem(context, '$clientsCount', isUrdu ? 'کلائنٹس' : 'Clients')),
                  Container(width: 1, height: 20, color: isDark ? const Color(0x18FFFFFF) : const Color(0x14000000)),
                  Expanded(child: _buildStatItem(context, '$activeOrdersCount', isUrdu ? 'سرگرم' : 'Active')),
                  Container(width: 1, height: 20, color: isDark ? const Color(0x18FFFFFF) : const Color(0x14000000)),
                  Expanded(child: _buildStatItem(context, planLabel, isUrdu ? 'پلان' : 'Plan')),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    // RIGHT: Action buttons
    final buttonsWidget1 = GestureDetector(
      onTap: onEditProfile,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 18, vertical: isCompact ? 9 : 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(
            colors: [Color(0xFFD97706), Color(0xFFB45309)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isUrdu ? '✏️ پروفائل تبدیل' : '✏️ Edit Profile',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );

    final buttonsWidget2 = GestureDetector(
      onTap: isUploadingLogo ? () {} : onChangeLogo,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 18, vertical: isCompact ? 9 : 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isDark ? const Color(0x0DFFFFFF) : context.surface2,
          border: Border.all(color: isDark ? const Color(0x1AFFFFFF) : context.border, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isUploadingLogo)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF8AA0B8)),
              )
            else
              Text(
                isUrdu ? '🖼 لوگو تبدیل' : '🖼 Change Logo',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: context.text2,
                ),
              ),
          ],
        ),
      ),
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0x33D97706) : AppColors.lightAccentBorder, width: 1),
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0x1FD97706), Color(0x0AD97706)]
              : [AppColors.lightAccentBg, AppColors.lightAccentBg.withValues(alpha: 0.5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Glow decoration
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x26D97706),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: EdgeInsets.all(isCompact ? 14 : 24),
            child: isCompact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header with Avatar & Shop Info
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          logoWidget,
                          const SizedBox(width: 14),
                          infoWidget,
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Stats Row inside compact container
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x12FFFFFF) : const Color(0x08000000),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0x10FFFFFF) : const Color(0x0E000000)),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: _buildStatItem(context, '$clientsCount', isUrdu ? 'کلائنٹس' : 'Clients')),
                            Container(width: 1, height: 20, color: isDark ? const Color(0x18FFFFFF) : const Color(0x14000000)),
                            Expanded(child: _buildStatItem(context, '$activeOrdersCount', isUrdu ? 'سرگرم' : 'Active')),
                            Container(width: 1, height: 20, color: isDark ? const Color(0x18FFFFFF) : const Color(0x14000000)),
                            Expanded(child: _buildStatItem(context, planLabel, isUrdu ? 'پلان' : 'Plan')),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Side-by-side action buttons on mobile
                      Row(
                        children: [
                          Expanded(child: buttonsWidget1),
                          const SizedBox(width: 8),
                          Expanded(child: buttonsWidget2),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      logoWidget,
                      const SizedBox(width: 24),
                      infoWidget,
                      const SizedBox(width: 24),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          buttonsWidget1,
                          const SizedBox(height: 8),
                          buttonsWidget2,
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {



  final String title;
  final List<Widget> children;

  const _ProfileSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0x08FFFFFF) : context.surface,
        border: Border.all(color: isDark ? const Color(0x12FFFFFF) : context.border, width: 1),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : context.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: isDark ? const Color(0x0DFFFFFF) : context.border, width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 3.5,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: context.text2,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _ProfileRow extends StatefulWidget {
  final Widget icon;
  final String label;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconBoxBg;
  final Color? iconBoxBorder;
  final Color? labelColor;
  final Color? hoverColor;
  final bool showBorder;

  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.iconBoxBg,
    this.iconBoxBorder,
    this.labelColor,
    this.hoverColor,
    this.showBorder = true,
  });

  @override
  State<_ProfileRow> createState() => _ProfileRowState();
}

class _ProfileRowState extends State<_ProfileRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultIconBg = isDark ? const Color(0x1FD97706) : AppColors.lightAccentBg;
    final defaultIconBorder = isDark ? const Color(0x33D97706) : AppColors.lightAccentBorder;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _isHovered
                ? (widget.hoverColor ?? (isDark ? const Color(0x08FFFFFF) : context.surfaceHover))
                : Colors.transparent,
            border: widget.showBorder
                ? Border(
                    bottom: BorderSide(
                      color: isDark ? const Color(0x0AFFFFFF) : context.border,
                      width: 1,
                    ),
                  )
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          child: Row(
            children: [
              // Icon Box
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: widget.iconBoxBg ?? defaultIconBg,
                  border: Border.all(
                    color: widget.iconBoxBorder ?? defaultIconBorder,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(fontSize: 17),
                    child: widget.icon,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Info Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: widget.labelColor ?? (isDark ? const Color(0xFFEDF4FF) : context.text1),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: context.text2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Trailing
              widget.trailing ??
                  Text(
                    '›',
                    style: GoogleFonts.inter(
                      color: context.text3,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CustomToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 38,
        height: 22,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          color: value ? const Color(0xFFD97706) : (isDark ? const Color(0x1AFFFFFF) : context.border),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              top: 2,
              bottom: 2,
              left: value ? null : 2,
              right: value ? 2 : null,
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
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

// ─── Skeleton / Error (modernized) ─────────────────────────────
class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.white10 : Colors.black12;
    final highlight = isDark ? Colors.white24 : Colors.black26;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF060C18) : AppColors.bgLight,
      body: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          _ShimmerBox(
            width: double.infinity,
            height: 160,
            borderRadius: 20,
            baseColor: base,
            highlightColor: highlight,
          ),
          const SizedBox(height: 24),
          _ShimmerBox(
            width: double.infinity,
            height: 300,
            borderRadius: 16,
            baseColor: base,
            highlightColor: highlight,
          ),
          const SizedBox(height: 16),
          _ShimmerBox(
            width: double.infinity,
            height: 240,
            borderRadius: 16,
            baseColor: base,
            highlightColor: highlight,
          ),
        ],
      ),
    );
  }
}

class _ProfileError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ProfileError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF060C18) : AppColors.bgLight,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0x08FFFFFF),
              border: Border.all(color: const Color(0x12FFFFFF)),
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  size: 48,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
                const SizedBox(height: 16),
                Text(
                  'Could not load profile',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 24),
                GoldButton(
                  onPressed: onRetry,
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double width, height, borderRadius;
  final Color baseColor, highlightColor;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.borderRadius = 8,
    required this.baseColor,
    required this.highlightColor,
  });

  @override
  _ShimmerBoxState createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          gradient: LinearGradient(
            colors: [widget.baseColor, widget.highlightColor, widget.baseColor],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }
}
