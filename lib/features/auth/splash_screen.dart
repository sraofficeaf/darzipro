import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/services/update_service.dart';
import '../../core/widgets/update_dialog.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _scaleUp;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.6)),
    );
    _scaleUp = Tween<double>(begin: 0.85, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();

    // Auto navigate after 3500ms if user does not press "Get Started"
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) _checkUpdateAndNavigate();
    });
  }

  Future<void> _checkUpdateAndNavigate() async {
    if (_navigated) return;
    final update = await UpdateService().checkForUpdate();
    if (update != null && mounted) {
      await showDialog(
        context: context,
        barrierDismissible: !update.isMandatory,
        builder: (_) => UpdateDialog(update: update),
      );
      if (!update.isMandatory && mounted) {
        _navigateToNext();
      }
    } else {
      if (mounted) {
        _navigateToNext();
      }
    }
  }

  void _navigateToNext() {
    if (_navigated) return;
    _navigated = true;
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        context.go('/dashboard');
      } else {
        context.go('/login');
      }
    } catch (e) {
      debugPrint('Splash authentication check error: $e');
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text3 = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: Stack(
        children: [
          // Background radial glow centered behind rings
          Center(
            child: Container(
              width: 320,
              height: 320,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x1AF5A623),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.7],
                ),
              ),
            ),
          ),
          
          // Main content
          FadeTransition(
            opacity: _fadeIn,
            child: ScaleTransition(
              scale: _scaleUp,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SplashRings(),
                    const SizedBox(height: 30),

                    // Title
                    GradientText(
                      'Darzi Pro',
                      style: GoogleFonts.outfit(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                      colors: const [Color(0xFFF5A623), Color(0xFFFFD080)],
                    ),
                    const SizedBox(height: 8),
                    
                    // Subtitle
                    Text(
                      'TAILOR SHOP MANAGEMENT',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: text3,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 38),

                    // Loading dots
                    const LoadingDots(),
                    const SizedBox(height: 48),

                    // Get Started Button
                    GoldButton(
                      width: 220,
                      height: 48,
                      borderRadius: 24,
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _checkUpdateAndNavigate();
                      },
                      child: Text(
                        'GET STARTED',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: const Color(0xFF1A0F00),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.only(bottom: 24),
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Version 1.0.0',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: text3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SplashRings extends StatefulWidget {
  const SplashRings({super.key});

  @override
  State<SplashRings> createState() => _SplashRingsState();
}

class _SplashRingsState extends State<SplashRings>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _ring1;
  late Animation<double> _ring2;
  late Animation<double> _ring3;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _ring1 = Tween<double>(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    _ring2 = Tween<double>(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    _ring3 = Tween<double>(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ring 3 (Outer, Color(0x08F5A623))
          ScaleTransition(
            scale: _ring3,
            child: FadeTransition(
              opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
                CurvedAnimation(
                  parent: _controller,
                  curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
                ),
              ),
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x08F5A623), width: 1.5),
                ),
              ),
            ),
          ),
          
          // Ring 2 (Middle, Color(0x15F5A623))
          ScaleTransition(
            scale: _ring2,
            child: FadeTransition(
              opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
                CurvedAnimation(
                  parent: _controller,
                  curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
                ),
              ),
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x15F5A623), width: 1.5),
                ),
              ),
            ),
          ),
          
          // Ring 1 (Inner, Color(0x25F5A623))
          ScaleTransition(
            scale: _ring1,
            child: FadeTransition(
              opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
                CurvedAnimation(
                  parent: _controller,
                  curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
                ),
              ),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x25F5A623), width: 1.5),
                ),
              ),
            ),
          ),
          
          // Core scissors
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF5A623).withValues(alpha: 0.1),
              border: Border.all(
                color: const Color(0xFFF5A623).withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF5A623).withValues(alpha: 0.15),
                  blurRadius: 24,
                ),
              ],
            ),
            child: const Center(
              child: Text('✂️', style: TextStyle(fontSize: 38)),
            ),
          ),
        ],
      ),
    );
  }
}

class LoadingDots extends StatefulWidget {
  const LoadingDots({super.key});

  @override
  State<LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dotColor = isDark ? AppColors.accent : AppColors.accentL;
    final inactiveColor = isDark ? AppColors.surf3Dark : AppColors.surf3Light;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final staggerOffset = index * 0.2; // 200ms stagger offset
            final progress = (_controller.value - staggerOffset) % 1.0;
            
            double scale = 1.0;
            double opacity = 0.3;
            
            if (progress < 0.4) {
              final t = progress / 0.4;
              scale = 1.0 + t * 0.3;
              opacity = 0.3 + t * 0.7;
            } else if (progress < 0.8) {
              final t = (progress - 0.4) / 0.4;
              scale = 1.3 - t * 0.3;
              opacity = 1.0 - t * 0.7;
            }

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.lerp(inactiveColor, dotColor, opacity),
                boxShadow: opacity > 0.6
                    ? [
                        BoxShadow(
                          color: dotColor.withValues(alpha: 0.3),
                          blurRadius: 6 * scale,
                        )
                      ]
                    : [],
              ),
            );
          },
        );
      }),
    );
  }
}

class GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final List<Color> colors;

  const GradientText(
    this.text, {
    super.key,
    required this.style,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & bounds.size),
      child: Text(
        text,
        style: style.copyWith(color: Colors.white),
      ),
    );
  }
}
