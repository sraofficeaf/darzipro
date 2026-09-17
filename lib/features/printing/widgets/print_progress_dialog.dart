import 'package:flutter/material.dart';

class PrintProgressState {
  final String step;
  final double progress; // 0.0 to 1.0

  const PrintProgressState({
    required this.step,
    required this.progress,
  });
}

class PrintProgressController {
  final ValueNotifier<PrintProgressState> state;
  BuildContext? _dialogContext;

  PrintProgressController({
    String initialStep = 'Preparing measurements...',
    double initialProgress = 0.2,
  }) : state = ValueNotifier(PrintProgressState(step: initialStep, progress: initialProgress));

  void setContext(BuildContext context) {
    _dialogContext = context;
  }

  void update({required String step, required double progress}) {
    state.value = PrintProgressState(
      step: step,
      progress: progress.clamp(0.0, 1.0),
    );
  }

  void dismiss() {
    if (_dialogContext != null && _dialogContext!.mounted) {
      Navigator.of(_dialogContext!, rootNavigator: true).pop();
      _dialogContext = null;
    }
  }
}

/// Displays an elegant progress modal with live step descriptions in English
/// and a smooth animated progress bar.
Future<PrintProgressController> showPrintProgressModal(
  BuildContext context, {
  String title = 'Printing Naap Card',
  String initialStep = 'Preparing measurements...',
}) async {
  final controller = PrintProgressController(
    initialStep: initialStep,
    initialProgress: 0.25,
  );

  // Show dialog asynchronously without blocking execution
  showDialog(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (dialogCtx) {
      controller.setContext(dialogCtx);
      return _PrintProgressDialogWidget(
        title: title,
        controller: controller,
      );
    },
  );

  // Give one microtask tick for dialog to mount
  await Future.delayed(const Duration(milliseconds: 20));
  return controller;
}

class _PrintProgressDialogWidget extends StatelessWidget {
  final String title;
  final PrintProgressController controller;

  const _PrintProgressDialogWidget({
    required this.title,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Center(
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: 380,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF3DDA8), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: const Color(0xFFE9A227).withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ValueListenableBuilder<PrintProgressState>(
              valueListenable: controller.state,
              builder: (context, state, _) {
                final percent = (state.progress * 100).toInt();

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row: Printer Icon + Title + Percent Badge
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF6E5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFF3DDA8), width: 1.2),
                          ),
                          child: const Icon(
                            Icons.print_rounded,
                            color: Color(0xFFB8860B),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'A5 Master Tailor Layout',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF7B8494),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF6E5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFF3DDA8), width: 1),
                          ),
                          child: Text(
                            '$percent%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB8860B),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Step description label
                    Row(
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE9A227)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.step,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Smooth animated progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: state.progress),
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        builder: (context, value, _) {
                          return Stack(
                            children: [
                              Container(
                                height: 8,
                                width: double.infinity,
                                color: const Color(0xFFF3F4F6),
                              ),
                              FractionallySizedBox(
                                widthFactor: value.clamp(0.01, 1.0),
                                child: Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFE9A227),
                                        Color(0xFFFFC65A),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
