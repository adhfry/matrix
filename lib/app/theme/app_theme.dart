import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

const _font = 'PlusJakartaSans';

/// Angka tabular: timer & jam kerja tidak "goyang" saat digit berganti.
const tabular = [FontFeature.tabularFigures()];

abstract final class AppTheme {
  static ThemeData light() =>
      _build(MxColors.light, MxHues.light, Brightness.light);
  static ThemeData dark() =>
      _build(MxColors.dark, MxHues.dark, Brightness.dark);

  static ThemeData _build(MxColors c, MxHues h, Brightness b) {
    final scheme = ColorScheme(
      brightness: b,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primaryContainer,
      onPrimaryContainer: c.ink,
      secondary: c.primary,
      onSecondary: c.onPrimary,
      error: c.alert,
      onError: b == Brightness.light ? Colors.white : c.canvas,
      errorContainer: c.alertContainer,
      onErrorContainer: c.ink,
      surface: c.surface,
      onSurface: c.ink,
      onSurfaceVariant: c.inkMuted,
      surfaceContainerLowest: c.canvas,
      surfaceContainerLow: c.canvas,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surface,
      surfaceContainerHighest: c.line,
      outline: c.line,
      outlineVariant: c.line,
      shadow: Colors.black,
      scrim: Colors.black54,
      inverseSurface: c.ink,
      onInverseSurface: c.canvas,
    );

    TextStyle s(
      double size,
      FontWeight w, {
      double? height,
      List<FontFeature>? f,
    }) => TextStyle(
      fontFamily: _font,
      fontSize: size,
      fontWeight: w,
      height: height,
      color: c.ink,
      fontFeatures: f,
      letterSpacing: 0,
    );

    final text = TextTheme(
      displaySmall: s(32, FontWeight.w600, height: 1.15, f: tabular),
      headlineSmall: s(22, FontWeight.w600, height: 1.25),
      titleLarge: s(19, FontWeight.w600, height: 1.3),
      titleMedium: s(17, FontWeight.w600, height: 1.3),
      titleSmall: s(15, FontWeight.w600, height: 1.35),
      bodyLarge: s(15, FontWeight.w400, height: 1.45),
      bodyMedium: s(14, FontWeight.w400, height: 1.45),
      bodySmall: s(
        12,
        FontWeight.w400,
        height: 1.4,
      ).copyWith(color: c.inkMuted),
      labelLarge: s(15, FontWeight.w600, height: 1.2),
      labelMedium: s(13, FontWeight.w500, height: 1.3),
      labelSmall: s(12, FontWeight.w500, height: 1.3),
    );

    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.control),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      fontFamily: _font,
      textTheme: text,
      scaffoldBackgroundColor: c.canvas,
      extensions: [c, h],
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        backgroundColor: c.canvas,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        systemOverlayStyle: b == Brightness.light
            ? SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
              )
            : SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
              ),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: c.line),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          disabledBackgroundColor: c.line,
          disabledForegroundColor: c.inkMuted,
          minimumSize: const Size(64, 52),
          shape: controlShape,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          side: BorderSide(color: c.line),
          minimumSize: const Size(64, 52),
          shape: controlShape,
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          minimumSize: const Size(48, 48),
          textStyle: text.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        labelStyle: text.bodyMedium?.copyWith(color: c.inkMuted),
        floatingLabelStyle: text.labelMedium?.copyWith(color: c.primary),
        hintStyle: text.bodyMedium?.copyWith(color: c.inkMuted),
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall?.copyWith(color: c.alert),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.control),
          borderSide: BorderSide(color: c.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.control),
          borderSide: BorderSide(color: c.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.control),
          borderSide: BorderSide(color: c.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.control),
          borderSide: BorderSide(color: c.alert),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.control),
          borderSide: BorderSide(color: c.alert, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.primaryContainer,
        side: BorderSide(color: c.line),
        labelStyle: text.labelMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.control),
        ),
        showCheckmark: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.primaryContainer,
        height: 68,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelSmall!.copyWith(
            color: states.contains(WidgetState.selected) ? c.ink : c.inkMuted,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? c.primary
                : c.inkMuted,
            size: 24,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.line,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.card)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        titleTextStyle: text.titleMedium,
        contentTextStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.canvas),
        actionTextColor: b == Brightness.light
            ? const Color(0xFF6EE7B7)
            : c.primaryBright,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.control),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primaryBright,
        linearTrackColor: c.line,
        circularTrackColor: c.line,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: c.surface,
          selectedBackgroundColor: c.primaryContainer,
          selectedForegroundColor: c.ink,
          foregroundColor: c.inkMuted,
          side: BorderSide(color: c.line),
          textStyle: text.labelMedium,
          minimumSize: const Size(48, 44),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onPrimary : c.inkMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : c.line,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.inkMuted,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodySmall,
        minVerticalPadding: 12,
        contentPadding: const EdgeInsets.symmetric(horizontal: Sp.lg),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
