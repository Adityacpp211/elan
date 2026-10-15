// Élan Design System
//
// A calm, clinical look: warm paper canvas, ink text, flat white cards with
// hairline borders, and a single signal red reserved for emergency actions.
// No glows, gradients or decorative shadows. One typeface (Manrope).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/api_service.dart';
import 'services/connection_status.dart';

// ==================== COLOR TOKENS ====================

abstract final class AppColors {
  // Canvas
  static const ink = Color(0xFFF4F2ED); // page background (warm paper)
  static const surface = Color(0xFFFFFFFF); // cards
  static const surfaceRaised = Color(0xFFF0EDE7); // inset areas
  static const hairline = Color(0xFFDDD8CF);

  // Text (all at least 4.5:1 on surface and canvas)
  static const textPrimary = Color(0xFF16181D);
  static const textSecondary = Color(0xFF474C57);
  static const textMuted = Color(0xFF6B707A);

  // Semantics: muted, print-like hues that stay legible as text on white
  static const brand = Color(0xFFC8102E); // emergency / critical only
  static const brandSoft = Color(0xFFFBE9EB);
  static const alert = Color(0xFF1F4E8C); // hospitals, informational
  static const success = Color(0xFF1C7A47);
  static const warning = Color(0xFF9A5B00);
  static const sky = Color(0xFF256D8F);
}

abstract final class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
  static const huge = 40.0;
}

abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 10.0;
  static const lg = 12.0;
  static const xl = 16.0;
}

abstract final class AppFonts {
  // One family throughout; hierarchy comes from size and weight.
  static const display = 'Manrope';
  static const body = 'Manrope';

  // Manrope ships as a variable font whose default instance is ExtraLight,
  // and Flutter does not map `fontWeight` onto the variable 'wght' axis.
  // Every weighted style therefore pairs its fontWeight with one of these.
  static const w200 = [FontVariation('wght', 200)];
  static const w300 = [FontVariation('wght', 300)];
  static const w400 = [FontVariation('wght', 400)];
  static const w500 = [FontVariation('wght', 500)];
  static const w600 = [FontVariation('wght', 600)];
  static const w700 = [FontVariation('wght', 700)];
  static const w800 = [FontVariation('wght', 800)];
  static const w900 = [FontVariation('wght', 800)]; // axis tops out at 800

  /// The axis value for [weight], for styles built without an explicit one.
  static List<FontVariation> forWeight(FontWeight? weight) =>
      [FontVariation('wght', ((weight ?? FontWeight.w400).value).clamp(200, 800).toDouble())];
}

// ==================== THEME ====================

class AppTheme {
  AppTheme._();

  /// Give every text style the variable-font axis for its weight (see
  /// [AppFonts]); slots inherited from Material's defaults have none.
  static TextTheme _withWeightAxes(TextTheme t) {
    TextStyle? fix(TextStyle? s) => s == null || s.fontVariations != null
        ? s
        : s.copyWith(fontVariations: AppFonts.forWeight(s.fontWeight));
    return TextTheme(
      displayLarge: fix(t.displayLarge),
      displayMedium: fix(t.displayMedium),
      displaySmall: fix(t.displaySmall),
      headlineLarge: fix(t.headlineLarge),
      headlineMedium: fix(t.headlineMedium),
      headlineSmall: fix(t.headlineSmall),
      titleLarge: fix(t.titleLarge),
      titleMedium: fix(t.titleMedium),
      titleSmall: fix(t.titleSmall),
      bodyLarge: fix(t.bodyLarge),
      bodyMedium: fix(t.bodyMedium),
      bodySmall: fix(t.bodySmall),
      labelLarge: fix(t.labelLarge),
      labelMedium: fix(t.labelMedium),
      labelSmall: fix(t.labelSmall),
    );
  }

  /// Kept under the old name so call sites don't change; the app now has a
  /// single light theme.
  static ThemeData dark() => light();

  static ThemeData light() {
    const colorScheme = ColorScheme.light(
      brightness: Brightness.light,
      primary: AppColors.brand,
      onPrimary: Colors.white,
      secondary: AppColors.alert,
      onSecondary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.brand,
      onError: Colors.white,
      surfaceContainerHighest: AppColors.surfaceRaised,
      outline: AppColors.hairline,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.ink,
      fontFamily: AppFonts.body,
      splashFactory: InkRipple.splashFactory,
    );

    final textTheme = base.textTheme.copyWith(
      // Display — Space Grotesk
      displayLarge: const TextStyle(
          fontFamily: AppFonts.display,
          fontSize: 34,
          height: 1.1,
          letterSpacing: -0.8,
          fontWeight: FontWeight.w800,
          fontVariations: AppFonts.w800,
          color: AppColors.textPrimary),
      displayMedium: const TextStyle(
          fontFamily: AppFonts.display,
          fontSize: 28,
          height: 1.15,
          letterSpacing: -0.6,
          fontWeight: FontWeight.w800,
          fontVariations: AppFonts.w800,
          color: AppColors.textPrimary),
      headlineLarge: const TextStyle(
          fontFamily: AppFonts.display,
          fontSize: 24,
          height: 1.2,
          letterSpacing: -0.4,
          fontWeight: FontWeight.w800,
          fontVariations: AppFonts.w800,
          color: AppColors.textPrimary),
      headlineMedium: const TextStyle(
          fontFamily: AppFonts.display,
          fontSize: 22,
          height: 1.25,
          letterSpacing: -0.3,
          fontWeight: FontWeight.w800,
          fontVariations: AppFonts.w800,
          color: AppColors.textPrimary),
      headlineSmall: const TextStyle(
          fontFamily: AppFonts.display,
          fontSize: 19,
          height: 1.3,
          letterSpacing: -0.2,
          fontWeight: FontWeight.w700,
          fontVariations: AppFonts.w700,
          color: AppColors.textPrimary),
      titleLarge: const TextStyle(
          fontFamily: AppFonts.display,
          fontSize: 17,
          height: 1.3,
          fontWeight: FontWeight.w700,
          fontVariations: AppFonts.w700,
          color: AppColors.textPrimary),
      titleMedium: const TextStyle(
          fontSize: 16,
          height: 1.35,
          fontWeight: FontWeight.w600,
          fontVariations: AppFonts.w600,
          color: AppColors.textPrimary),
      titleSmall: const TextStyle(
          fontSize: 14,
          height: 1.4,
          fontWeight: FontWeight.w700,
          fontVariations: AppFonts.w700,
          color: AppColors.textSecondary),
      // Body — Manrope
      bodyLarge: const TextStyle(
          fontSize: 15,
          height: 1.55,
          fontWeight: FontWeight.w500,
          fontVariations: AppFonts.w500,
          color: AppColors.textPrimary),
      bodyMedium: const TextStyle(
          fontSize: 14,
          height: 1.5,
          fontWeight: FontWeight.w500,
          fontVariations: AppFonts.w500,
          color: AppColors.textSecondary),
      bodySmall: const TextStyle(
          fontSize: 12,
          height: 1.5,
          fontWeight: FontWeight.w500,
          fontVariations: AppFonts.w500,
          color: AppColors.textMuted),
      labelLarge: const TextStyle(
          fontSize: 14.5,
          letterSpacing: 0.1,
          fontWeight: FontWeight.w700,
          fontVariations: AppFonts.w700,
          color: AppColors.textPrimary),
      labelMedium: const TextStyle(
          fontSize: 12, letterSpacing: 0.3, fontWeight: FontWeight.w700,fontVariations: AppFonts.w700,),
      labelSmall: const TextStyle(
          fontSize: 11.5, letterSpacing: 0.3, fontWeight: FontWeight.w700,fontVariations: AppFonts.w700,),
    );

    return base.copyWith(
      textTheme: _withWeightAxes(textTheme),
      appBarTheme: const AppBarTheme(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: const TextStyle(
            fontSize: 14,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,fontVariations: AppFonts.w500,),
        hintStyle: const TextStyle(
            fontSize: 14,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w400,fontVariations: AppFonts.w400,),
        errorStyle: const TextStyle(fontSize: 12, color: AppColors.brand),
        prefixIconColor: AppColors.textMuted,
        suffixIconColor: AppColors.textMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide:
              const BorderSide(color: AppColors.textPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.brand),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm)),
          textStyle: const TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              fontVariations: AppFonts.w700,
              letterSpacing: 0.3),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm)),
          textStyle: const TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              fontVariations: AppFonts.w700,
              letterSpacing: 0.3),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.hairline),
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm)),
          textStyle: const TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 15,
              fontWeight: FontWeight.w700,fontVariations: AppFonts.w700,),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brand,
          textStyle: const TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 14,
              fontWeight: FontWeight.w700,fontVariations: AppFonts.w700,),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.hairline,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.hairline),
        ),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),
      // Dark snackbars stand out against the light canvas
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 13.5,
            color: Colors.white,
            fontWeight: FontWeight.w600,fontVariations: AppFonts.w600,),
        actionTextColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.textPrimary),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}

// ==================== SHARED WIDGETS ====================

/// Full-screen page canvas. [glow] is accepted for compatibility but no
/// longer drawn: pages are flat paper.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child, this.glow});
  final Widget child;
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    // Every screen renders inside this, so the Scaffold lives here: it is what
    // ScaffoldMessenger attaches SnackBars to.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Dark status-bar icons on the light canvas
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.ink,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: SizedBox.expand(child: child),
      ),
    );
  }
}

/// The Élan brand mark: a flat signal-red tile.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 56, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.brand;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.2),
        child: Icon(
          Icons.favorite_rounded,
          size: size * 0.55,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// A tiled icon container that keeps icon treatment consistent.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.color = AppColors.brand,
    this.size = 44,
    this.iconSize,
  });
  final IconData icon;
  final Color color;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(size * 0.24),
      ),
      child: Icon(icon, size: iconSize ?? size * 0.48, color: color),
    );
  }
}

/// AppBar replacement for inner screens with a consistent composition.
class ScreenHeader extends StatelessWidget implements PreferredSizeWidget {
  const ScreenHeader({
    super.key,
    this.title,
    this.eyebrow,
    this.onBack,
    this.trailing,
    this.subtitle,
  });

  final String? title;
  final String? eyebrow;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Size get preferredSize => const Size.fromHeight(ScreenHeader.height);

  /// Tall enough for the eyebrow + title + subtitle stack without clipping.
  static const double height = 76;

  @override
  Widget build(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(height),
      child: SafeArea(
        bottom: false,
        child: Container(
          height: height,
          // Align with the 20px content gutter. The back button's visible
          // circle sits 4px inside its 48px tap target, hence the smaller
          // left inset when it is shown.
          padding: EdgeInsets.only(
            left: onBack != null ? AppSpace.lg : AppSpace.xl,
            right: AppSpace.xl,
          ),
          child: Row(
            children: [
              if (onBack != null)
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.hairline),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm)),
                  ),
                ),
              if (onBack != null) const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // [eyebrow] is intentionally not rendered: a kicker
                    // above every title was noise.
                    if (title != null)
                      Text(title!,
                          style: Theme.of(context).textTheme.headlineSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpace.sm),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Small uppercase spaced label used above section titles.
class EyebrowLabel extends StatelessWidget {
  const EyebrowLabel(
      {super.key,
      required this.text,
      this.color = AppColors.textMuted,
      this.textAlign});
  final String text;
  final Color color;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      textAlign: textAlign,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            fontVariations: AppFonts.w700,
            letterSpacing: 0.8,
          ),
    );
  }
}

/// Section block: eyebrow + title + optional trailing.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.color,
    this.trailing,
  });
  final String title;
  final String? eyebrow;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // [eyebrow] is kept in the API but not rendered.
              Text(title, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Status pill with a dot indicator.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.color = AppColors.success,
    this.fill = true,
  });
  final String label;
  final Color color;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fill ? color.withValues(alpha: 0.10) : AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fill ? color : AppColors.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              fontVariations: AppFonts.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Live backend connectivity indicator. Pings the server on a timer and lets
/// the user force a re-check by tapping.
class ServerStatusPill extends StatelessWidget {
  const ServerStatusPill({super.key, this.syncing = false});

  /// Whether a backend session is active (shown when the server is online).
  final bool syncing;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ServerStatus>(
      valueListenable: ConnectionStatus(),
      builder: (context, status, _) {
        final (label, color) = switch (status) {
          ServerStatus.checking => ('Checking…', AppColors.sky),
          ServerStatus.online => (
              syncing ? 'Online · synced' : 'Server online',
              AppColors.success
            ),
          ServerStatus.offline => ('Server offline', AppColors.brand),
        };

        return GestureDetector(
          onTap: () async {
            final messenger = ScaffoldMessenger.maybeOf(context);
            await ConnectionStatus().refresh();
            if (!ConnectionStatus().isOnline) {
              // Say what is unreachable: the usual cause in development is
              // a backend that isn't running, or an API_BASE_URL that points
              // at the wrong host.
              messenger?.showSnackBar(SnackBar(
                content: Text(kDebugMode
                    ? 'Cannot reach ${ApiService.baseUrl}. Is the backend '
                        'running (cd backend && npm start)?'
                    : 'Cannot reach the Élan server. Check your internet '
                        'connection.'),
              ));
            }
          },
          child: StatusBadge(label: label, color: color),
        );
      },
    );
  }
}

/// Elevated surface with hairline border — the app's standard card.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.borderColor,
    this.radius = AppRadius.lg,
    this.margin,
    this.child,
  });
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final EdgeInsetsGeometry? margin;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final contents = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? AppColors.hairline),
      ),
      child: child,
    );
    if (onTap == null) return contents;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: contents,
    );
  }
}

/// Primary call-to-action button.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.color = AppColors.brand,
    this.loading = false,
    this.suffix,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final bool loading;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.3),
          disabledForegroundColor: Colors.white,
          elevation: 0,
        ),
        child: loading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withValues(alpha: 0.9)),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 10),
                  ],
                  Text(label),
                  if (suffix != null) ...[const SizedBox(width: 8), suffix!],
                ],
              ),
      ),
    );
  }
}

/// Press-and-hold action for irreversible, high-stakes sends (the SOS).
///
/// Holding fills the button over [holdDuration]; letting go early cancels
/// and the fill drains back. This replaces a confirm dialog: it guards
/// against accidental taps without adding a step in an emergency.
class HoldToSendButton extends StatefulWidget {
  const HoldToSendButton({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.caption,
    this.color = AppColors.brand,
    this.loading = false,
    this.loadingLabel = 'Sending…',
    this.holdDuration = const Duration(milliseconds: 1500),
  });

  final String label;
  final String? caption;
  final VoidCallback? onConfirmed;
  final Color color;
  final bool loading;
  final String loadingLabel;
  final Duration holdDuration;

  @override
  State<HoldToSendButton> createState() => _HoldToSendButtonState();
}

class _HoldToSendButtonState extends State<HoldToSendButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fill =
      AnimationController(vsync: this, duration: widget.holdDuration)
        ..addStatusListener(_onStatus);

  bool get _enabled => widget.onConfirmed != null && !widget.loading;

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    HapticFeedback.heavyImpact();
    widget.onConfirmed?.call();
    _fill.value = 0;
  }

  void _start() {
    if (!_enabled) return;
    HapticFeedback.selectionClick();
    _fill.forward();
  }

  void _cancel() {
    if (_fill.isCompleted || _fill.value == 0) return;
    _fill.animateBack(0,
        duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = _enabled ? widget.color : widget.color.withValues(alpha: 0.35);
    final dark = Color.lerp(widget.color, Colors.black, 0.28)!;

    return Semantics(
      button: true,
      enabled: _enabled,
      label: '${widget.label}. Press and hold to send.',
      onLongPress: _enabled ? widget.onConfirmed : null,
      child: GestureDetector(
        onTapDown: (_) => _start(),
        onTapUp: (_) => _cancel(),
        onTapCancel: _cancel,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: SizedBox(
            height: 60,
            child: AnimatedBuilder(
              animation: _fill,
              builder: (context, _) {
                final holding = _fill.value > 0;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: base),
                    // Progress fill sweeps left to right while held
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _fill.value,
                      child: ColoredBox(color: dark),
                    ),
                    Center(
                      child: widget.loading
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.2, color: Colors.white),
                                ),
                                const SizedBox(width: 12),
                                Text(widget.loadingLabel,
                                    style: _labelStyle),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.sos_rounded,
                                        color: Colors.white, size: 22),
                                    const SizedBox(width: 10),
                                    Text(
                                      holding ? 'Keep holding…' : widget.label,
                                      style: _labelStyle,
                                    ),
                                  ],
                                ),
                                if (widget.caption != null && !holding)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      widget.caption!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        fontVariations: AppFonts.w600,
                                        color: Color(0xFFFCE4E7),
                                      ),
                                    ),
                                  ),
                              ],
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

  static const _labelStyle = TextStyle(
    fontSize: 16.5,
    fontWeight: FontWeight.w800,
    fontVariations: AppFonts.w800,
    color: Colors.white,
  );
}

/// Tonal secondary button.
class TonalButton extends StatelessWidget {
  const TonalButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.color = AppColors.alert,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.09),
          foregroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.05),
          minimumSize: const Size(0, 52),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 19),
              const SizedBox(width: 9)
            ],
            Text(label),
          ],
        ),
      ),
    );
  }
}

/// Error banner for form feedback.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.brand, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  color: AppColors.brand,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontVariations: AppFonts.w600,
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty-state composition.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.color = AppColors.alert,
  });
  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconTile(icon: icon, color: color, size: 64, iconSize: 30),
            const SizedBox(height: 18),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Consistent info row for profile/detail screens.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color = AppColors.alert,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconTile(icon: icon, color: color, size: 40, iconSize: 19),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 2),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ],
    );
  }
}

/// Labeled value used in stat rows (numbers render in Space Grotesk).
class StatValue extends StatelessWidget {
  const StatValue({
    super.key,
    required this.label,
    required this.value,
    this.color = AppColors.textPrimary,
    this.icon,
  });
  final String label;
  final String value;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
            ],
            // Large values (e.g. a five-digit balance) shrink rather than
            // overflow narrow columns.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                // Values stay ink; colour lives on the icon only, so a count
                // doesn't read as a warning just because its icon is red.
                child: Text(
                  value,
                  style: const TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 22,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    fontVariations: AppFonts.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
