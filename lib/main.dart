// Élan — Emergency Cardiac Care System
// Entry point & splash.

import 'package:flutter/material.dart';
import 'dart:async';

import 'models.dart';
import 'theme.dart';
import 'screens.dart';
import 'services/api_service.dart';
import 'services/connection_status.dart';

/// Lets services outside the widget tree (e.g. an expired session detected by
/// ApiService) send the user back to the login screen.
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiService().onUnauthorized = _handleExpiredSession;
  await AuthService().checkAutoLogin();
  ConnectionStatus().startMonitoring();
  runApp(const ElanApp());
}

bool _handlingExpiredSession = false;

Future<void> _handleExpiredSession() async {
  // Several in-flight requests can fail at once; only react to the first.
  if (_handlingExpiredSession) return;
  _handlingExpiredSession = true;
  try {
    await AuthService().logout();
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
          content: Text('Your session has expired. Please sign in again.')),
    );
  } finally {
    _handlingExpiredSession = false;
  }
}

class ElanApp extends StatelessWidget {
  const ElanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Élan',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      // The UI is phone-first; on wide screens (desktop web, landscape
      // tablets) keep it to a readable column instead of stretching cards
      // edge to edge.
      builder: (context, child) => ColoredBox(
        color: AppColors.ink,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: child,
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// ==================== SPLASH ====================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _ringAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _ringAnimation = Tween<double>(begin: 0.9, end: 1.35).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      final authService = AuthService();
      final destination = authService.currentLoggedInUser != null
          ? homeForSession()
          : const LoginScreen() as Widget;

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, animation, __) => FadeTransition(
            opacity: animation,
            child: destination,
          ),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: animation,
            child: child,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 132,
                  height: 132,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Expanding pulse rings that fade as they grow. Opacity
                      // is driven by the animation (it was previously read
                      // once at build time) and clamped, since the raw
                      // formulas go negative near the end of the curve.
                      AnimatedBuilder(
                        animation: _ringAnimation,
                        builder: (context, child) => Transform.scale(
                          scale: _ringAnimation.value,
                          child: Opacity(
                            opacity: (0.12 - (_ringAnimation.value - 0.9) * 0.4)
                                .clamp(0.0, 1.0),
                            child: child,
                          ),
                        ),
                        child: Container(
                          width: 132,
                          height: 132,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.brand,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _ringAnimation,
                        builder: (context, child) => Transform.scale(
                          scale: _ringAnimation.value,
                          child: Opacity(
                            opacity: (0.2 - (_ringAnimation.value - 0.9))
                                .clamp(0.0, 1.0),
                            child: child,
                          ),
                        ),
                        child: Container(
                          width: 118,
                          height: 118,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.brand.withValues(alpha: 0.18),
                          ),
                        ),
                      ),
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: const BrandMark(size: 84),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    'Élan',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          letterSpacing: 0.5,
                        ),
                  ),
                ),
                const SizedBox(height: 10),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: EyebrowLabel(
                    text: 'Emergency cardiac care',
                    color: AppColors.brand,
                  ),
                ),
                const SizedBox(height: 48),
                // Loading dots
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      return Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color:
                              AppColors.brand.withValues(alpha: 0.35 + i * 0.3),
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
