import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppModal extends StatelessWidget {
  final String title;
  final Widget child;
  final double width;

  const AppModal({
    super.key,
    required this.title,
    required this.child,
    required this.width,
  });

  Future<T?> show<T>(BuildContext context) {
    return showGeneralDialog<T>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      barrierDismissible: false,
      barrierLabel: 'Modal',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: this,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.1),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bg = isDark ? const Color(0xFF0F1C30) : Colors.white;
    final border = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE5E7EB);
    final titleCol = isDark ? const Color(0xFFEDF4FF) : const Color(0xFF0F172A);
    final closeBg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05);
    final closeBorder = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);
    final closeIconCol = isDark ? const Color(0xFF5A7090) : const Color(0xFF64748B);

    return Container(
      width: width,
      constraints: BoxConstraints(
        maxWidth: width,
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
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
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: titleCol,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
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
            Flexible(
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
