import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:darzi_pro/core/constants/app_colors.dart';
import 'package:darzi_pro/core/widgets/shared_widgets.dart';
import 'package:darzi_pro/core/services/update_service.dart';

class UpdateDialog extends StatelessWidget {
  final UpdateInfo update;
  const UpdateDialog({required this.update, super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Star icon with gold glow
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentS,
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                  boxShadow: const [BoxShadow(color: AppColors.accentGlow, blurRadius: 20)],
                ),
                child: const Center(child: Text('✨', style: TextStyle(fontSize: 28))),
              ),
              const SizedBox(height: 16),
              // Title gradient
              GoldGradientText(
                'Update Available!',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'Version ${update.version} is ready',
                style: GoogleFonts.inter(fontSize: 13, color: t2),
              ),
              const SizedBox(height: 16),
              // Release notes box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.accentSS,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.15)),
                ),
                child: Text(
                  update.releaseNotes,
                  style: GoogleFonts.inter(fontSize: 12.5, color: t1, height: 1.5),
                ),
              ),
              const SizedBox(height: 20),
              // Buttons
              GoldButton(
                onPressed: () {
                  Navigator.pop(context);
                  UpdateService().openDownload(update.downloadUrl);
                },
                child: Text(
                  '⬇ Update Now',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A0F00),
                  ),
                ),
              ),
              if (!update.isMandatory) ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Later',
                    style: GoogleFonts.inter(fontSize: 13, color: t2),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
