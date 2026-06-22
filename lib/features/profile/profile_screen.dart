import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/providers/supabase_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _shopNameController;
  late TextEditingController _ownerNameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;

  bool _isSaving = false;
  bool _isUploadingLogo = false;
  bool _isInitialized = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _shopNameController = TextEditingController();
    _ownerNameController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
  }

  void _populateFields(Map<String, dynamic>? shop, Map<String, dynamic>? profile) {
    if (shop != null) {
      _shopNameController.text = shop['name'] as String? ?? '';
      _phoneController.text = shop['phone'] as String? ?? '';
      _addressController.text = shop['address'] as String? ?? '';
    }

    if (profile != null) {
      _ownerNameController.text = profile['full_name'] as String? ?? '';
    }
    _isInitialized = true;
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadLogo() async {
    final shopId = ref.read(currentShopIdProvider);
    if (shopId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ref.read(localeProvider) == 'ur' ? '❌ ایرر: دکان کی معلومات نہیں ملیں!' : '❌ Error: Shop ID not found!',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _isUploadingLogo = true);
    try {
      final bytes = await picked.readAsBytes();
      final extension = picked.name.split('.').last.toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = '$shopId/logo_$timestamp.$extension';

      final shop = ref.read(currentShopProvider).value;
      final oldLogo = shop?['logo_url'] as String?;
      if (oldLogo != null && oldLogo.isNotEmpty) {
        try {
          await Supabase.instance.client.storage
              .from('shop-logos')
              .remove([oldLogo]);
        } catch (_) {}
      }

      await Supabase.instance.client.storage
          .from('shop-logos')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      await Supabase.instance.client
          .from('shops')
          .update({'logo_url': storagePath})
          .eq('id', shopId);

      ref.invalidate(currentShopProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ref.read(localeProvider) == 'ur' ? '✅ لوگو تبدیل ہو گیا!' : '✅ Logo updated successfully!',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            backgroundColor: AppColors.teal,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Upload failed: $e', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final shopId = ref.read(currentShopIdProvider);
    final userId = ref.read(currentUserIdProvider);
    if (shopId == null || userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ref.read(localeProvider) == 'ur' ? '❌ ایرر: دکان یا صارف کی معلومات نہیں ملیں!' : '❌ Error: Shop or User ID not found!',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client.from('shops').update({
        'name': _shopNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
      }).eq('id', shopId);

      await Supabase.instance.client.from('profiles').update({
        'full_name': _ownerNameController.text.trim(),
      }).eq('id', userId);

      ref.invalidate(currentShopProvider);
      ref.invalidate(profileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ref.read(localeProvider) == 'ur' ? '✅ معلومات محفوظ ہو گئیں!' : '✅ Profile details saved!',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            backgroundColor: AppColors.teal,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isEditing = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Save failed: $e', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showChangePasswordDialog() {
    final passwordCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? AppColors.surfDark : AppColors.surfLight;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final isUrdu = ref.read(localeProvider) == 'ur';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surf,
        title: Text(
          isUrdu ? 'پاس ورڈ تبدیل کریں' : 'Change Password',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: t1),
        ),
        content: TextField(
          controller: passwordCtrl,
          obscureText: true,
          style: GoogleFonts.inter(color: t1),
          decoration: InputDecoration(
            hintText: isUrdu ? 'نیا پاس ورڈ لکھیں' : 'Enter new password',
            labelText: isUrdu ? 'نیا پاس ورڈ' : 'New Password',
            labelStyle: GoogleFonts.inter(color: t2),
            hintStyle: GoogleFonts.inter(color: t2),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              isUrdu ? 'منسوخ' : 'Cancel',
              style: GoogleFonts.inter(
                color: t2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final newPass = passwordCtrl.text.trim();
              if (newPass.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Password must be at least 6 characters.'),
                    backgroundColor: AppColors.red,
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await Supabase.instance.client.auth.updateUser(
                  UserAttributes(password: newPass),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('✅ Password updated successfully!'),
                      backgroundColor: AppColors.teal,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Error: $e'),
                      backgroundColor: AppColors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.accent : AppColors.accentL,
              foregroundColor: const Color(0xFF1A0F00),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(isUrdu ? 'محفوظ کریں' : 'Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        context.go('/login');
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(currentShopProvider);
    final profileAsync = ref.watch(profileProvider);

    final isUrdu = ref.watch(localeProvider) == 'ur';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final surf = isDark ? AppColors.surfDark : AppColors.surfLight;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    if ((shopAsync.isLoading || profileAsync.isLoading) && !_isInitialized) {
      return Scaffold(
        backgroundColor: bg,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }

    if (!_isInitialized && shopAsync.hasValue && profileAsync.hasValue) {
      final shopData = shopAsync.value;
      final profileData = profileAsync.value;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isInitialized) {
          setState(() {
            _populateFields(shopData, profileData);
          });
        }
      });
    }

    final shop = shopAsync.value;
    final shopName = shop?['name'] as String? ?? 'SaifurRahman Tailors';
    final logoUrl = shop?['logo_url'] as String?;
    final ownerName = profileAsync.value?['full_name'] as String? ?? 'SaifurRahman';
    final phoneNum = shop?['phone'] as String? ?? '0300-1234567';

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    Widget buildViewMode() {
      return ListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Premium Hero card
          AppCard(
            gradientColors: const [Color(0x24F5A623), Color(0x08F5A623)],
            borderColor: const Color(0xFFF5A623).withValues(alpha: 0.2),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              children: [
                // Animated repeating ring avatar wrapper
                Center(
                  child: AnimatedAvatarRing(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x59F5A623),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                        gradient: logoUrl == null || logoUrl.isEmpty
                            ? const LinearGradient(
                                colors: [Color(0xFFD4791A), Color(0xFFF5A623)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        image: logoUrl != null && logoUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(logoUrl.startsWith('http') || logoUrl.startsWith('assets')
                                    ? logoUrl
                                    : 'https://ztxrkijwfnegvquoblne.supabase.co/storage/v1/object/public/shop-logos/$logoUrl'),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: logoUrl == null || logoUrl.isEmpty
                          ? Center(
                              child: Text(
                                shopName.isNotEmpty ? shopName[0].toUpperCase() : 'S',
                                style: GoogleFonts.inter(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  shopName,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  isUrdu ? 'مالک · پشاور · قائم شدہ 2020' : 'Owner · Peshawar · Est. 2020',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                // Edit Profile Glass Button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _isEditing = true);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('✏️', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 6),
                        Text(
                          isUrdu ? 'پروفائل تبدیل کریں' : 'Edit Profile',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Account Settings
          _fieldLabel(isUrdu ? 'حساب کتاب' : 'ACCOUNT', t2),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                _settingRow(
                  emoji: '👤',
                  title: isUrdu ? 'مالک کا نام' : 'Owner Name',
                  subtitle: ownerName,
                  onTap: () => setState(() => _isEditing = true),
                ),
                Divider(height: 1, color: border),
                _settingRow(
                  emoji: '📱',
                  title: isUrdu ? 'فون' : 'Phone',
                  subtitle: phoneNum,
                  onTap: () => setState(() => _isEditing = true),
                ),
                Divider(height: 1, color: border),
                _settingRow(
                  emoji: '🔒',
                  title: isUrdu ? 'پاس ورڈ تبدیل کریں' : 'Change Password',
                  subtitle: isUrdu ? 'لاگ ان کی معلومات تبدیل کریں' : 'Update login credentials',
                  onTap: _showChangePasswordDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Shop Settings
          _fieldLabel(isUrdu ? 'دکان کی ترتیبات' : 'SHOP SETTINGS', t2),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                _settingRow(
                  emoji: '🏪',
                  title: isUrdu ? 'دکان کا نام' : 'Shop Name',
                  subtitle: shopName,
                  onTap: () => setState(() => _isEditing = true),
                ),
                Divider(height: 1, color: border),
                _settingRow(
                  emoji: '📍',
                  title: isUrdu ? 'پتہ' : 'Address',
                  subtitle: shop?['address'] as String? ?? 'Saddar Bazaar, Peshawar',
                  onTap: () => setState(() => _isEditing = true),
                ),
                Divider(height: 1, color: border),
                _settingRow(
                  emoji: '🖼️',
                  title: isUrdu ? 'دکان کا لوگو' : 'Shop Logo',
                  subtitle: isUrdu ? 'کارڈ اور رسید پر لوگو لگانے کیلئے' : 'For token cards & invoices',
                  onTap: _pickAndUploadLogo,
                  trailing: _isUploadingLogo
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accent,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // App settings
          _fieldLabel(isUrdu ? 'ایپ' : 'APP', t2),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                _settingRow(
                  emoji: '🌐',
                  title: isUrdu ? 'زبان / Language' : 'Language / زبان',
                  subtitle: isUrdu ? 'اردو (Urdu)' : 'English (English)',
                  onTap: () {
                    ref.read(localeProvider.notifier).setLanguage(isUrdu ? 'en' : 'ur');
                  },
                ),
                Divider(height: 1, color: border),
                Consumer(
                  builder: (context, ref, _) {
                    final themeMode = ref.watch(themeModeProvider);
                    final isDarkMode = themeMode == ThemeMode.dark;
                    return _settingRow(
                      emoji: '🌙',
                      title: isUrdu ? 'ڈارک موڈ' : 'Dark Mode',
                      trailing: GoldSwitch(
                        value: isDarkMode,
                        onChanged: (val) {
                          ref.read(themeModeProvider.notifier).state =
                              val ? ThemeMode.dark : ThemeMode.light;
                          Hive.box('settings_box').put('themeMode', val ? 'dark' : 'light');
                        },
                      ),
                    );
                  },
                ),
                Divider(height: 1, color: border),
                _settingRow(
                  emoji: 'ℹ️',
                  title: isUrdu ? 'ورژن' : 'Version',
                  subtitle: 'Darzi Pro v1.0.0',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Logout
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: _settingRow(
              emoji: '↩️',
              title: isUrdu ? 'لاگ آؤٹ' : 'Logout',
              titleColor: AppColors.red,
              onTap: _handleLogout,
            ),
          ),
          const SizedBox(height: 20),
        ],
      );
    }

    Widget buildEditMode() {
      return Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            Text(
              isUrdu ? 'پروفائل ایڈٹ کریں' : 'Edit Profile Details',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: t1,
              ),
            ),
            const SizedBox(height: 16),

            // Shop Name field
            AppTextField(
              label: isUrdu ? 'دکان کا نام' : 'SHOP NAME',
              controller: _shopNameController,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),

            // Owner Name field
            AppTextField(
              label: isUrdu ? 'صارف کا نام' : 'OWNER NAME',
              controller: _ownerNameController,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),

            // Phone field
            AppTextField(
              label: isUrdu ? 'فون نمبر' : 'PHONE NUMBER',
              controller: _phoneController,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),

            // Address field
            AppTextField(
              label: isUrdu ? 'پتہ' : 'ADDRESS',
              controller: _addressController,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              maxLines: 2,
            ),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      onPressed: () => setState(() => _isEditing = false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: t1,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04),
                        side: BorderSide(color: border, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        isUrdu ? 'منسوخ' : 'Cancel',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          color: t1,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GoldButton(
                    height: 46,
                    borderRadius: 16,
                    onPressed: _isSaving ? null : _saveProfile,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A0F00)),
                          )
                        : Text(
                            isUrdu ? 'محفوظ کریں' : 'Save Details',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w900),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: isDesktop
                ? Container(
                    width: 500,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: surf,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      ),
                    ),
                    child: _isEditing ? buildEditMode() : buildViewMode(),
                  )
                : _isEditing
                    ? buildEditMode()
                    : buildViewMode(),
          ),
        ),
      ),
    );
  }


  Widget _fieldLabel(String label, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t3 = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.8,
          color: t3,
        ),
      ),
    );
  }

  Widget _settingRow({
    required String emoji,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? titleColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t1 = titleColor ?? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: t1,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: t2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else if (onTap != null)
              Text(
                '›',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  color: t2,
                  fontWeight: FontWeight.w300,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AnimatedAvatarRing extends StatefulWidget {
  final Widget child;

  const AnimatedAvatarRing({super.key, required this.child});

  @override
  State<AnimatedAvatarRing> createState() => _AnimatedAvatarRingState();
}

class _AnimatedAvatarRingState extends State<AnimatedAvatarRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1.0 + _controller.value * 0.15;
        final opacity = 1.0 - _controller.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFF5A623).withValues(alpha: 0.45),
                      width: 2.5,
                    ),
                  ),
                ),
              ),
            ),
            widget.child,
          ],
        );
      },
    );
  }
}

class GoldSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const GoldSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeGradient = const LinearGradient(
      colors: [Color(0xFFF5A623), Color(0xFFD4791A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final inactiveColor = isDark ? const Color(0x12FFFFFF) : const Color(0x0D000000);
    final activeGlow = const BoxShadow(
      color: Color(0x59F5A623),
      blurRadius: 10,
      spreadRadius: 1,
    );

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 24,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: value ? null : inactiveColor,
          gradient: value ? activeGradient : null,
          boxShadow: value ? [activeGlow] : null,
          border: Border.all(
            color: value ? Colors.transparent : (isDark ? const Color(0x1AFFFFFF) : const Color(0x12000000)),
            width: 1,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? const Color(0xFF1A0F00) : (isDark ? const Color(0x8CFFFFFF) : const Color(0x8C000000)),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
