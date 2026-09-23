// CardioAid — Emergency Cardiac Care System
// Entry point & splash.

import 'package:flutter/material.dart';
import 'dart:async';

import 'models.dart';
import 'theme.dart';
import 'screens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService().checkAutoLogin();
  runApp(const CardioAidApp());
}

class CardioAidApp extends StatelessWidget {
  const CardioAidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CardioAid',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
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
          ? const Dashboard() as Widget
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
                      // Expanding pulse ring
                      ScaleTransition(
                        scale: _ringAnimation,
                        child: Opacity(
                          opacity: 0.12 - (_ringAnimation.value - 0.9) * 0.4,
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
                      ),
                      ScaleTransition(
                        scale: _ringAnimation,
                        child: Opacity(
                          opacity: 0.2 - (_ringAnimation.value - 0.9),
                          child: Container(
                            width: 118,
                            height: 118,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.brand.withValues(alpha: 0.18),
                            ),
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
                    'CardioAid',
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
                          color: AppColors.brand.withValues(
                              alpha: 0.35 + i * 0.3),
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