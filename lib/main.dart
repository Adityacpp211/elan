// Élan — Emergency Cardiac Care System
// Entry point & splash.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 500),
    vsync: this,
  )..forward();

  @override
  void initState() {
    super.initState();
    // Brief by design: in an emergency nobody should wait on a logo.
    Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      final destination = AuthService().currentLoggedInUser != null
          ? homeForSession()
          : const LoginScreen() as Widget;

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 250),
          pageBuilder: (_, animation, __) => FadeTransition(
            opacity: animation,
            child: destination,
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.brand,
      ),
      child: Scaffold(
        backgroundColor: AppColors.brand,
        body: Center(
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite_rounded, size: 56, color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Élan',
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 40,
                    letterSpacing: -1,
                    fontWeight: FontWeight.w800,
                    fontVariations: AppFonts.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Emergency cardiac care',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontVariations: AppFonts.w600,
                    color: Color(0xFFFCE4E7),
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
