import 'package:flutter/material.dart';

class StepIndicator extends StatelessWidget {
  final int totalSteps;
  final int currentStep; // 1-based
  final List<String> labels;

  const StepIndicator({
    super.key,
    required this.totalSteps,
    required this.currentStep,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveBg = isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF3F4F6);
    final inactiveBorder = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE5E7EB);
    final inactiveText = isDark ? const Color(0xFF3D5470) : const Color(0xFF94A3B8);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        children: [
          Row(
            children: List.generate(totalSteps * 2 - 1, (i) {
              if (i.isOdd) {
                // Connector line
                final stepIndex = (i ~/ 2) + 1;
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 2,
                    color: stepIndex < currentStep
                        ? const Color(0xFF10CBA0)
                        : inactiveBg,
                  ),
                );
              }
              final stepNum = (i ~/ 2) + 1;
              final isDone = stepNum < currentStep;
              final isActive = stepNum == currentStep;
              return Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone
                          ? const Color(0xFF10CBA0)
                          : isActive
                              ? null
                              : inactiveBg,
                      gradient: isActive
                          ? const LinearGradient(
                              colors: [Color(0xFFF5A623), Color(0xFFD97706)],
                            )
                          : null,
                      border: (!isDone && !isActive)
                          ? Border.all(color: inactiveBorder)
                          : null,
                      boxShadow: isActive
                          ? const [
                              BoxShadow(
                                color: Color(0x66F5A623),
                                blurRadius: 12,
                              )
                            ]
                          : null,
                    ),
                    child: Center(
                      child: isDone
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : Text(
                              '$stepNum',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isActive
                                    ? const Color(0xFF1A0A00)
                                    : inactiveText,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[stepNum - 1],
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: isDone
                          ? const Color(0xFF10CBA0)
                          : isActive
                              ? const Color(0xFFF5A623)
                              : inactiveText,
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 10),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(1),
            child: LinearProgressIndicator(
              value: currentStep / totalSteps,
              backgroundColor: inactiveBg,
              valueColor: const AlwaysStoppedAnimation(Color(0xFFF5A623)),
              minHeight: 2,
            ),
          ),
        ],
      ),
    );
  }
}
