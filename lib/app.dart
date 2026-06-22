import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'shared/providers/app_providers.dart';

class DarziProApp extends ConsumerWidget {
  const DarziProApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    // Global Error Widget Fallback to handle render crashes gracefully
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return MaterialApp(
        title: 'Darzi Pro Error',
        theme: AppTheme.dark,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF111827),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('⚠️', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 16),
                  const Text(
                    'UI Render Error',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    details.exceptionAsString(),
                    style: const TextStyle(fontSize: 13, color: Colors.white60),
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      appRouter.go('/dashboard');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF5A623),
                      foregroundColor: const Color(0xFF1A0F00),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Back to Home', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    };

    final currentLocale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'Darzi Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: appRouter,
      locale: Locale(currentLocale),
      supportedLocales: const [
        Locale('en'),
        Locale('ur'),
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: currentLocale == 'ur' ? TextDirection.rtl : TextDirection.ltr,
          child: child ?? const SizedBox(),
        );
      },
    );

  }
}
