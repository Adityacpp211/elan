// CardioAid Design System
// Typography: Space Grotesk (display) + Manrope (body)

import 'package:flutter/material.dart';

// ==================== COLOR TOKENS ====================

abstract final class AppColors {
  // Canvas
  static const ink = Color(0xFF070A13);
  static const surface = Color(0xFF0D1220);
  static const surfaceRaised = Color(0xFF141B2E);
  static const hairline = Color(0xFF232C49);

  // Text
  static const textPrimary = Color(0xFFF4F6FB);
  static const textSecondary = Color(0xFF9AA3BF);
  static const textMuted = Color(0xFF5E6784);

  // Semantics
  static const brand = Color(0xFFFF4D5E); // emergency
  static const brandSoft = Color(0xFF3A1520);
  static const alert = Color(0xFF6C7CFF); // hospital alerts
  static const success = Color(0xFF3DDC97);
  static const warning = Color(0xFFF5B856);
  static const sky = Color(0xFF39B6F0);
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
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
}

abstract final class AppFonts {
  static const display = 'SpaceGrotesk';
  static const body = 'Manrope';
}

// ==================== THEME ====================

class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      brightness: Brightness.dark,
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
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.ink,
      fontFamily: AppFonts.body,
      splashFactory: InkSparkle.splashFactory,
    );

    final textTheme = base.textTheme.copyWith(
      // Display — Space Grotesk
      displayLarge: const TextStyle(
          fontFamily: AppFonts.display, fontSize: 40, height: 1.05,
          fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      displayMedium: const TextStyle(
          fontFamily: AppFonts.display, fontSize: 32, height: 1.1,
          fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      headlineLarge: const TextStyle(
          fontFamily: AppFonts.display, fontSize: 28, height: 1.15,
          fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      headlineMedium: const TextStyle(
          fontFamily: AppFonts.display, fontSize: 24, height: 1.2,
          fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      headlineSmall: const TextStyle(
          fontFamily: AppFonts.display, fontSize: 20, height: 1.25,
          fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      titleLarge: const TextStyle(
          fontFamily: AppFonts.display, fontSize: 18, height: 1.3,
          fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      titleMedium: const TextStyle(
          fontSize: 16, height: 1.35, fontWeight: FontWeight.w600,
          color: AppColors.textPrimary),
      titleSmall: const TextStyle(
          fontSize: 14, height: 1.4, fontWeight: FontWeight.w700,
          color: AppColors.textSecondary),
      // Body — Manrope
      bodyLarge: const TextStyle(
          fontSize: 15, height: 1.55, fontWeight: FontWeight.w500,
          color: AppColors.textPrimary),
      bodyMedium: const TextStyle(
          fontSize: 13.5, height: 1.55, fontWeight: FontWeight.w500,
          color: AppColors.textSecondary),
      bodySmall: const TextStyle(
          fontSize: 12, height: 1.5, fontWeight: FontWeight.w500,
          color: AppColors.textMuted),
      labelLarge: const TextStyle(
          fontSize: 14.5, letterSpacing: 0.1, fontWeight: FontWeight.w700,
          color: AppColors.textPrimary),
      labelMedium: const TextStyle(
          fontSize: 12, letterSpacing: 0.3, fontWeight: FontWeight.w700),
      labelSmall: const TextStyle(
          fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceRaised,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: const TextStyle(
            fontSize: 14, color: AppColors.textMuted, fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(
            fontSize: 14, color: AppColors.textMuted, fontWeight: FontWeight.w400),
        errorStyle: const TextStyle(fontSize: 12, color: AppColors.brand),
        prefixIconColor: AppColors.textMuted,
        suffixIconColor: AppColors.textMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: AppColors.hairline.withValues(alpha: 0.8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.brand, width: 1.6),
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
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
          textStyle: const TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: AppColors.brand.withValues(alpha: 0.5),
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
          textStyle: const TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.hairline),
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
          textStyle: const TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 15,
              fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brand,
          textStyle: const TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 14,
              fontWeight: FontWeight.w700),
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
        backgroundColor: AppColors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.hairline),
        ),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceRaised,
        contentTextStyle: const TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 13.5,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: const BorderSide(color: AppColors.hairline),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}

// ==================== SHARED WIDGETS ====================

/// Full-screen canvas with a subtle aurora glow in the top-left corner.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child, this.glow});
  final Widget child;
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.ink,
        gradient: RadialGradient(
          center: const Alignment(-0.9, -1.1),
          radius: 1.6,
          colors: [
            (glow ?? AppColors.brand).withValues(alpha: 0.07),
            (glow ?? AppColors.brand).withValues(alpha: 0.0),
          ],
        ),
      ),
      child: child,
    );
  }
}

/// The CardioAid brand mark — a rounded tile with a soft glow.
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
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.95), accent.withValues(alpha: 0.55)],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.35),
            blurRadius: size * 0.6,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: size * 0.2,
            offset: Offset(0, size * 0.08),
          ),
        ],
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
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: color.withValues(alpha: 0.25)),
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
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              if (onBack != null)
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceRaised,
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.hairline),
                  ),
                ),
              if (onBack != null) const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (eyebrow != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: EyebrowLabel(text: eyebrow!),
                      ),
                    if (title != null)
                      Text(title!, style: Theme.of(context).textTheme.headlineSmall),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

/// Small uppercase spaced label used above section titles.
class EyebrowLabel extends StatelessWidget {
  const EyebrowLabel({super.key, required this.text, this.color = AppColors.textMuted});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
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
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                EyebrowLabel(text: eyebrow!, color: color ?? AppColors.textMuted),
                const SizedBox(height: 6),
              ],
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fill
            ? color.withValues(alpha: 0.12)
            : AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
            color: fill ? color.withValues(alpha: 0.35) : AppColors.hairline),
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
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
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
      height: 56,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
          elevation: enabled ? 6 : 0,
          shadowColor: color.withValues(alpha: 0.5),
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
          backgroundColor: color.withValues(alpha: 0.14),
          foregroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.08),
          minimumSize: const Size(0, 52),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 19), const SizedBox(width: 9)],
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
        color: AppColors.brand.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.brand, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  color: AppColors.brand.withValues(alpha: 0.95),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
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
            IconTile(icon: icon, color: color, size: 84, iconSize: 38),
            const SizedBox(height: 22),
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
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
            ],
            Text(
              value,
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 22,
                height: 1.1,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}