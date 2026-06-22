import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/responsive/responsive.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/providers/supabase_providers.dart';
import '../../shared/providers/license_provider.dart';
import '../../core/services/update_service.dart';
import '../../core/widgets/update_dialog.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final surf = isDark ? AppColors.surfDark : AppColors.surfLight;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final t3 = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
    final isDesktop = Responsive.isDesktop(context);
    final shopAsync = ref.watch(currentShopProvider);
    final shopName = shopAsync.value?['name'] as String? ?? 'SaifurRahman Tailors';
    final license = ref.watch(licenseProvider);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surf,
        automaticallyImplyLeading: false,
        leading: !isDesktop && context.canPop()
            ? IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: t1),
                onPressed: () => context.pop(),
              )
            : null,
        title: Text(
          'Settings',
          style: GoogleFonts.inter(
              fontSize: 20, fontWeight: FontWeight.w900, color: t1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Shop Profile
          _SectionLabel('SHOP PROFILE', t2),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsTile(
                  emoji: '🏪',
                  title: 'Shop Name',
                  subtitle: 'SaifurRahman Tailors',
                  onTap: () => _showEditDialog(context, 'Shop Name', 'SaifurRahman Tailors'),
                ),
                _divider(isDark),
                _SettingsTile(
                  emoji: '📍',
                  title: 'Address',
                  subtitle: 'Saddar, Peshawar',
                  onTap: () => _showEditDialog(context, 'Address', 'Saddar, Peshawar'),
                ),
                _divider(isDark),
                _SettingsTile(
                  emoji: '📞',
                  title: 'Phone Number',
                  subtitle: '0300-1234567',
                  onTap: () => _showEditDialog(context, 'Phone', '0300-1234567'),
                ),
                _divider(isDark),
                _SettingsTile(
                  emoji: '🖼️',
                  title: 'Shop Logo',
                  subtitle: 'Tap to change logo',
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Appearance
          _SectionLabel(isDark ? 'APPEARANCE' : 'APPEARANCE', t2),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    final themeMode = ref.watch(themeModeProvider);
                    final isDarkMode = themeMode == ThemeMode.dark;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Text(isDarkMode ? '🌙' : '☀️',
                              style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dark Mode',
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: t1),
                                ),
                                Text(
                                  isDarkMode ? 'Currently dark' : 'Currently light',
                                  style: GoogleFonts.inter(
                                      fontSize: 12, color: t2),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: isDarkMode,
                            activeThumbColor: AppColors.accent,
                            onChanged: (val) {
                              ref.read(themeModeProvider.notifier).state =
                                  val ? ThemeMode.dark : ThemeMode.light;
                              Hive.box('settings_box').put('themeMode', val ? 'dark' : 'light');
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
                _divider(isDark),
                Consumer(
                  builder: (context, ref, _) {
                    final currentLang = ref.watch(localeProvider);
                    final isUrdu = currentLang == 'ur';
                    return _SettingsTile(
                      emoji: '🌐',
                      title: isUrdu ? 'زبان / Language' : 'Language / زبان',
                      subtitle: isUrdu ? 'اردو (Urdu)' : 'English (English)',
                      onTap: () {
                        ref.read(localeProvider.notifier).setLanguage(isUrdu ? 'en' : 'ur');
                      },
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Measurement Templates
          _SectionLabel('MEASUREMENT TEMPLATES', t2),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsTile(
                  emoji: '👔',
                  title: 'Men\'s Template',
                  subtitle: '14 fields · Shalwar Kameez default',
                  onTap: () {},
                ),
                _divider(isDark),
                _SettingsTile(
                  emoji: '👗',
                  title: 'Women\'s Template',
                  subtitle: '16 fields · Suit default',
                  onTap: () {},
                ),
                _divider(isDark),
                _SettingsTile(
                  emoji: '👕',
                  title: 'Children\'s Template',
                  subtitle: '10 fields · Kameez default',
                  onTap: () {},
                ),
                _divider(isDark),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? AppColors.accent : AppColors.accentL,
                        backgroundColor: isDark
                            ? AppColors.accent.withValues(alpha: 0.12)
                            : AppColors.accentL.withValues(alpha: 0.08),
                        side: BorderSide(color: (isDark ? AppColors.accent : AppColors.accentL).withValues(alpha: 0.3), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('＋  ', style: TextStyle(fontSize: 16, color: isDark ? AppColors.accent : AppColors.accentL)),
                          Text(
                            'Add Custom Template',
                            style: TextStyle(
                              color: isDark ? AppColors.accent : AppColors.accentL,
                              fontWeight: FontWeight.bold,
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
          const SizedBox(height: 16),

          // Printing
          _SectionLabel('PRINTING', t2),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsTile(
                  emoji: '🖨️',
                  title: 'Default Print Size',
                  subtitle: 'A4 (Change to Thermal)',
                  onTap: () {},
                ),
                _divider(isDark),
                _SettingsTile(
                  emoji: '📋',
                  title: 'Card Footer Text',
                  subtitle: 'Generated by Darzi Pro',
                  onTap: () => _showEditDialog(
                      context, 'Footer Text', 'Generated by Darzi Pro'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // License & System
          _SectionLabel('LICENSE & SYSTEM', t2),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsTile(
                  emoji: '🔑',
                  title: license.isFree ? 'Free Plan' : 'Pro Plan Active',
                  subtitle: license.isFree
                      ? 'Upgrade for cloud sync & backup'
                      : 'Expires: ${license.expiresAt != null ? DateFormat('dd MMM yyyy').format(license.expiresAt!) : "Never"}',
                  trailing: license.isFree
                      ? SizedBox(
                          width: 80,
                          height: 32,
                          child: GoldButton(
                            onPressed: () => context.push('/upgrade'),
                            height: 32,
                            borderRadius: 16,
                            child: Text(
                              'Upgrade',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1A0F00),
                              ),
                            ),
                          ),
                        )
                      : null,
                  onTap: license.isFree ? () => context.push('/upgrade') : null,
                ),
                if (!license.isFree) ...[
                  _divider(isDark),
                  _SettingsTile(
                    emoji: '🔓',
                    title: 'Deactivate License',
                    subtitle: 'Switch back to local-only mode',
                    titleColor: AppColors.red,
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: isDark ? AppColors.surfDark : AppColors.surfLight,
                          title: Text('Deactivate License?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: t1)),
                          content: Text('Are you sure you want to deactivate your license? This will switch the app back to local-only mode.', style: GoogleFonts.inter(color: t2)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text('Cancel', style: GoogleFonts.inter(color: t2)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text('Deactivate', style: GoogleFonts.inter(color: AppColors.red, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref.read(licenseProvider.notifier).deactivate();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('License deactivated successfully.', style: GoogleFonts.inter()),
                              backgroundColor: AppColors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
                _divider(isDark),
                FutureBuilder<String>(
                  future: UpdateService().getCurrentVersion(),
                  builder: (context, snapshot) {
                    final currentVersion = snapshot.data ?? '1.0.0';
                    return _SettingsTile(
                      emoji: '🔄',
                      title: 'Check for Updates',
                      subtitle: 'Current version: $currentVersion',
                      onTap: () async {
                        final update = await UpdateService().checkForUpdate();
                        if (update != null) {
                          if (context.mounted) {
                            showDialog(
                              context: context,
                              barrierDismissible: !update.isMandatory,
                              builder: (_) => UpdateDialog(update: update),
                            );
                          }
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✓ App is up to date', style: GoogleFonts.inter(color: Colors.white)),
                                backgroundColor: AppColors.teal,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          }
                        }
                      },
                    );
                  }
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Account
          _SectionLabel('ACCOUNT', t2),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsTile(
                  emoji: '👤',
                  title: 'Owner Name',
                  subtitle: 'SaifurRahman',
                  onTap: () {},
                ),
                _divider(isDark),
                _SettingsTile(
                  emoji: '🔑',
                  title: 'Change Password',
                  subtitle: 'Update login credentials',
                  onTap: () {},
                ),
                _divider(isDark),
                _SettingsTile(
                  emoji: '🔴',
                  title: 'Logout',
                  subtitle: 'Sign out of this device',
                  titleColor: AppColors.red,
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // App info
          Center(
            child: Column(
              children: [
                Text(
                  '$shopName\nVersion 1.0.0 · Made with ❤️ for tailors',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: t3,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Divider(
      height: 1,
      color: isDark ? AppColors.borderDark : AppColors.borderLight,
      indent: 16,
    );
  }

  void _showEditDialog(
      BuildContext context, String label, String currentValue) {
    final ctrl = TextEditingController(text: currentValue);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? AppColors.surfDark : AppColors.surfLight;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surf,
        title: Text(label,
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: t1)),
        content: TextField(
          controller: ctrl,
          style: GoogleFonts.inter(color: t1),
          decoration: InputDecoration(
            hintText: label,
            hintStyle: GoogleFonts.inter(color: t2),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: t2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ $label updated!',
                      style:
                          GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  backgroundColor: AppColors.teal,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.accent : AppColors.accentL,
              foregroundColor: const Color(0xFF1A0F00),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Save',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionLabel(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: color,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color? titleColor;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.titleColor,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t1 = titleColor ??
        (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);
    final t2 = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: t1)),
                  Text(subtitle,
                      style: GoogleFonts.inter(fontSize: 12, color: t2)),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(Icons.chevron_right,
                  color: t2, size: 20),
          ],
        ),
      ),
    );
  }
}
