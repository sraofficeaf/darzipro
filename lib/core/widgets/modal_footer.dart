import 'package:flutter/material.dart';

class ModalFooter extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final String nextLabel;
  final bool isLoading;

  const ModalFooter({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.onNext,
    this.onBack,
    required this.nextLabel,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F1C30) : Colors.white;
    final border = isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF3F4F6);
    final textCol = isDark ? const Color(0xFF3D5470) : const Color(0xFF64748B);
    final backBtnColor = isDark ? const Color(0xFF8AA0B8) : const Color(0xFF4B5563);
    final backBtnBorder = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          top: BorderSide(
            color: border,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Step $currentStep of $totalSteps',
            style: TextStyle(fontSize: 11, color: textCol),
          ),
          const Spacer(),
          if (currentStep > 1)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton(
                onPressed: onBack,
                style: OutlinedButton.styleFrom(
                  foregroundColor: backBtnColor,
                  side: BorderSide(color: backBtnBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.arrow_back_rounded, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Back',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          // Next/Save button
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: currentStep == totalSteps - 1
                    ? [const Color(0xFF10CBA0), const Color(0xFF059669)]
                    : [const Color(0xFFF5A623), const Color(0xFFD97706)],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: currentStep == totalSteps - 1
                      ? const Color(0x5910CBA0)
                      : const Color(0x59F5A623),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: ElevatedButton(
              onPressed: isLoading ? null : onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: const Color(0xFF1A0A00),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF1A0A00),
                      ),
                    )
                  : Text(
                      nextLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
