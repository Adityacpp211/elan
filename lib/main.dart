// Élan — Emergency Cardiac Care System
// Entry point & splash.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import 'models.dart';
import 'theme.dart';
import 'screens.dart';
import 'disclaimer_screen.dart';
import 'services/api_service.dart';
import 'services/connection_status.dart';

/// Lets services outside the widget tree (e.g. an expired session detected by
/// ApiService) send the user back to the login screen.
final navigatorKey = GlobalKey<NavigatorState>();

/// The first frame is held back until the splash logo is decoded, so the
/// native launch screen hands over to an identical frame (see SplashScreen).
bool _firstFrameDeferred = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized().deferFirstFrame();
  _firstFrameDeferred = true;
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
  /// Same size and position as the Android launch-screen mark, so the
  /// hand-off from the system splash to this one is invisible.
  static const _markSize = 132.0;

  late final AnimationController _c = AnimationController(
    duration: const Duration(milliseconds: 1100),
    vsync: this,
  );

  // The mark glides up to make room for the wordmark: the logo lockup forms.
  late final Animation<double> _rise = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _word = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.25, 0.75, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _tagline = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.45, 0.95, curve: Curves.easeOut),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    // Decode the logo before showing anything: otherwise the first frame is
    // blank and the system splash fades out over nothing (a visible blink).
    precacheImage(const AssetImage(BrandMark.asset), context)
        .whenComplete(() {
      if (_firstFrameDeferred) {
        _firstFrameDeferred = false;
        WidgetsBinding.instance.allowFirstFrame();
      }
      if (!mounted) return;
      // Respect the system "reduce motion" setting: show the final lockup.
      if (MediaQuery.of(context).disableAnimations) {
        _c.value = 1;
      } else {
        _c.forward();
      }
      // Brief by design: in an emergency nobody should wait on a logo.
      Timer(const Duration(milliseconds: 1300), _goHome);
    });
  }

  Future<void> _goHome() async {
    if (!mounted) return;
    final home = AuthService().currentLoggedInUser != null
        ? homeForSession()
        : const LoginScreen() as Widget;
    // First launch: the safety notice comes before anything else.
    final accepted = await DisclaimerScreen.isAccepted();
    if (!mounted) return;
    final destination = accepted ? home : DisclaimerScreen(next: home);

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: destination,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            // Fill the screen so "center" is the screen's centre, where the
            // system splash left the mark (a bare Stack hugs its content
            // and sits top-left).
            return SizedBox.expand(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Logo mark: starts exactly where the system splash left it
                  Transform.translate(
                    offset: Offset(0, -46 * _rise.value),
                    child: Transform.scale(
                      scale: 1 - 0.12 * _rise.value,
                      child: const BrandMark(size: _markSize),
                    ),
                  ),
                  // Wordmark rises into place beneath it
                  Transform.translate(
                    offset: Offset(0, 62 + 12 * (1 - _word.value)),
                    child: Opacity(
                      opacity: _word.value,
                      child: const BrandWordmark(size: 40),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(0, 104 + 8 * (1 - _tagline.value)),
                    child: Opacity(
                      opacity: _tagline.value,
                      child: const Text(
                        'Emergency cardiac care',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontVariations: AppFonts.w600,
                          letterSpacing: 0.2,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
