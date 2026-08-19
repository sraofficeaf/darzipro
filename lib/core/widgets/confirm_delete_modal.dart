import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ConfirmDeleteModal extends StatelessWidget {
  final String title;
  final String itemName;
  final String description;

  const ConfirmDeleteModal._({
    required this.title,
    required this.itemName,
    required this.description,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String itemName,
    required String description,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      barrierDismissible: false,
      barrierLabel: 'ConfirmDeleteModal',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: ConfirmDeleteModal._(
            title: title,
            itemName: itemName,
            description: description,
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const double width = 500.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? const Color(0xFF0F1C30) : Colors.white;
    final borderCol = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE5E7EB);
    final titleCol = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF1F2937);
    final closeBg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05);
    final closeBorder = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);
    final closeIconCol = isDark ? const Color(0xFF5A7090) : const Color(0xFF64748B);

    final nameCol = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0F172A);
    final descCol = isDark ? const Color(0xFF8AA0B8) : const Color(0xFF4B5563);

    final cardBg = isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF9FAFB);
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF3F4F6);
    final deleteIconBg = isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0x0FFF3A58);

    final footerBg = isDark ? const Color(0xFF0F1C30) : Colors.white;
    final footerBorderTop = isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF3F4F6);

    final cancelBtnText = isDark ? const Color(0xFF10CBA0) : const Color(0xFF4B5563);
    final cancelBtnBorder = isDark ? const Color(0x3310CBA0) : const Color(0xFFE5E7EB);

    return Container(
      width: width,
      constraints: const BoxConstraints(
        maxWidth: width,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.7 : 0.15),
            blurRadius: isDark ? 80 : 36,
            offset: Offset(0, isDark ? 32 : 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: titleCol,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: closeBg,
                        border: Border.all(color: closeBorder),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: closeIconCol,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Warning icon
                  const Text(
                    '⚠️',
                    style: TextStyle(fontSize: 40),
                  ),
                  const SizedBox(height: 16),
                  
                  // Title: "Delete [itemName]?"
                  Text(
                    'Delete $itemName?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: nameCol,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Sub text / description
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.5,
                      color: descCol,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Preview Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      border: Border.all(color: cardBorder),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: deleteIconBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.delete_sweep_rounded,
                            size: 18,
                            color: Color(0xFFFF3A58),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            itemName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: nameCol,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
              decoration: BoxDecoration(
                color: footerBg,
                border: Border(
                  top: BorderSide(
                    color: footerBorderTop,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Cancel Outline Button
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cancelBtnText,
                      side: BorderSide(color: cancelBtnBorder, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Yes, Delete Button
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33DC2626),
                          blurRadius: 14,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      ),
                      child: Text(
                        'Yes, Delete',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
