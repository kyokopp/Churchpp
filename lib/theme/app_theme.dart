import 'package:flutter/material.dart';

import '../utils/app_page_transitions.dart';

@immutable
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  const AppThemeTokens({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.primary,
    required this.primaryTint,
    required this.selectedSurface,
    required this.searchSurface,
    required this.secondarySurface,
    required this.textPrimary,
    required this.textSecondary,
    required this.mutedText,
    required this.outline,
    required this.border,
    required this.destructive,
    required this.ready,
    required this.delivered,
    required this.gradient,
  });

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color primary;
  final Color primaryTint;
  final Color selectedSurface;
  final Color searchSurface;
  final Color secondarySurface;
  final Color textPrimary;
  final Color textSecondary;
  final Color mutedText;
  final Color outline;
  final Color border;
  final Color destructive;
  final Color ready;
  final Color delivered;
  final LinearGradient gradient;

  @override
  AppThemeTokens copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? primary,
    Color? primaryTint,
    Color? selectedSurface,
    Color? searchSurface,
    Color? secondarySurface,
    Color? textPrimary,
    Color? textSecondary,
    Color? mutedText,
    Color? outline,
    Color? border,
    Color? destructive,
    Color? ready,
    Color? delivered,
    LinearGradient? gradient,
  }) {
    return AppThemeTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      primary: primary ?? this.primary,
      primaryTint: primaryTint ?? this.primaryTint,
      selectedSurface: selectedSurface ?? this.selectedSurface,
      searchSurface: searchSurface ?? this.searchSurface,
      secondarySurface: secondarySurface ?? this.secondarySurface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      mutedText: mutedText ?? this.mutedText,
      outline: outline ?? this.outline,
      border: border ?? this.border,
      destructive: destructive ?? this.destructive,
      ready: ready ?? this.ready,
      delivered: delivered ?? this.delivered,
      gradient: gradient ?? this.gradient,
    );
  }

  @override
  AppThemeTokens lerp(ThemeExtension<AppThemeTokens>? other, double t) {
    if (other is! AppThemeTokens) return this;
    return AppThemeTokens(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryTint: Color.lerp(primaryTint, other.primaryTint, t)!,
      selectedSurface: Color.lerp(selectedSurface, other.selectedSurface, t)!,
      searchSurface: Color.lerp(searchSurface, other.searchSurface, t)!,
      secondarySurface: Color.lerp(
        secondarySurface,
        other.secondarySurface,
        t,
      )!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      border: Color.lerp(border, other.border, t)!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
      ready: Color.lerp(ready, other.ready, t)!,
      delivered: Color.lerp(delivered, other.delivered, t)!,
      gradient: t < 0.5 ? gradient : other.gradient,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppThemeTokens get tokens {
    return Theme.of(this).extension<AppThemeTokens>()!;
  }
}

class AppColors {
  const AppColors._();

  static const background = Color(0xFFFDF7FF);
  static const white = Color(0xFFFFFFFF);
  static const primary = Color(0xFF4F378A);
  static const primaryBase = Color(0xFF6750A4);
  static const selectedSurface = Color(0xFFE8DEF9);
  static const searchSurface = Color(0xFFE6E0E9);
  static const secondarySurface = Color(0xFFF2ECF4);
  static const textPrimary = Color(0xFF1D1B20);
  static const textSecondary = Color(0xFF494551);
  static const muted = Color(0xFF686177);
  static const mutedText = muted;
  static const outline = Color(0xFF79747E);
  static const border = Color(0xFFCBC4D2);
  static const destructive = Color(0xFFBA1A1A);
  static const ready = Color(0xFFEAB308);
  static const delivered = Color(0xFF22C55E);
}

class AppSpacing {
  const AppSpacing._();

  static const double page = 24;
  static const double topBarHeight = 64;
  static const double dashboardTop = 96;
  static const double settingsTop = 80;
  static const double sectionGap = 32;
  static const double dashboardHeadingGap = 16;
  static const double settingsHeadingGap = 8;
  static const double cardPadding = 16;
  static const double floatingDockHeight = 64;
  static const double floatingDockSideMargin = 16;
  static const double floatingDockBottomGap = 16;

  static double floatingDockBottomPadding(BuildContext context) {
    return floatingDockHeight +
        floatingDockBottomGap +
        MediaQuery.paddingOf(context).bottom;
  }
}

class AppRadii {
  const AppRadii._();

  static const double pill = 9999;
  static const double card = 12;
  static const double toolbarButton = 8;
  static const double compact = 6;
  static const double segmented = compact;
}

class AppTheme {
  // Font size scale factors
  static const Map<String, double> fontScales = {
    'small': 0.85,
    'medium': 1.0,
    'large': 1.2,
  };

  // Pulpit mode extra scale on top of user preference
  static const double pulpitExtraScale = 1.6;

  static const AppThemeTokens lightTokens = AppThemeTokens(
    background: AppColors.background,
    surface: AppColors.white,
    surfaceElevated: AppColors.white,
    primary: AppColors.primary,
    primaryTint: AppColors.primaryBase,
    selectedSurface: AppColors.selectedSurface,
    searchSurface: AppColors.searchSurface,
    secondarySurface: AppColors.secondarySurface,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    mutedText: AppColors.muted,
    outline: AppColors.outline,
    border: AppColors.border,
    destructive: AppColors.destructive,
    ready: AppColors.ready,
    delivered: AppColors.delivered,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF0EAFF), Color(0xFFE8F4FF), Color(0xFFFFF8F0)],
      stops: [0, 0.55, 1],
    ),
  );

  static const AppThemeTokens darkTokens = AppThemeTokens(
    background: Color(0xFF151218),
    surface: Color(0xFF211D26),
    surfaceElevated: Color(0xFF2A2530),
    primary: Color(0xFFD0BCFF),
    primaryTint: Color(0xFFD0BCFF),
    selectedSurface: Color(0xFF3B3150),
    searchSurface: Color(0xFF2F2935),
    secondarySurface: Color(0xFF27222D),
    textPrimary: Color(0xFFF2ECF4),
    textSecondary: Color(0xFFCAC4D0),
    mutedText: Color(0xFF938F99),
    outline: Color(0xFF938F99),
    border: Color(0xFF49454F),
    destructive: Color(0xFFFFB4AB),
    ready: Color(0xFFFACC15),
    delivered: Color(0xFF86EFAC),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1A0A2E), Color(0xFF0D0D1A), Color(0xFF2D1B4E)],
      stops: [0, 0.5, 1],
    ),
  );

  static LinearGradient gradientFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? darkTokens.gradient
        : lightTokens.gradient;
  }

  static ThemeData lightTheme({double fontScale = 1.0}) {
    const tokens = lightTokens;
    final colorScheme = ColorScheme.light(
      primary: tokens.primary,
      onPrimary: tokens.surface,
      primaryContainer: tokens.selectedSurface,
      onPrimaryContainer: tokens.primary,
      secondary: tokens.textSecondary,
      onSecondary: tokens.surface,
      tertiary: tokens.outline,
      error: tokens.destructive,
      surface: tokens.background,
      onSurface: tokens.textPrimary,
      surfaceContainer: tokens.background,
      surfaceContainerHighest: tokens.searchSurface,
      outline: tokens.outline,
      outlineVariant: tokens.border,
    );
    return _buildTheme(colorScheme, tokens, fontScale);
  }

  static ThemeData darkTheme({double fontScale = 1.0}) {
    const tokens = darkTokens;
    final colorScheme = ColorScheme.dark(
      primary: tokens.primary,
      onPrimary: Color(0xFF251247),
      primaryContainer: tokens.selectedSurface,
      onPrimaryContainer: tokens.primary,
      secondary: tokens.textSecondary,
      onSecondary: Color(0xFF1D1B20),
      tertiary: tokens.outline,
      error: tokens.destructive,
      surface: tokens.background,
      onSurface: tokens.textPrimary,
      surfaceContainer: tokens.background,
      surfaceContainerHighest: tokens.searchSurface,
      outline: tokens.outline,
      outlineVariant: tokens.border,
    );
    return _buildTheme(colorScheme, tokens, fontScale);
  }

  static ThemeData _buildTheme(
    ColorScheme colorScheme,
    AppThemeTokens tokens,
    double fontScale,
  ) {
    final textTheme = _buildTextTheme(fontScale);
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      extensions: [tokens],
      textTheme: textTheme,
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: 'Inter',
      fontFamilyFallback: const ['Helvetica'],
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: AppCupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: AppCupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: AppCupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: AppCupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: AppCupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: AppSpacing.topBarHeight,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      cardTheme: CardThemeData(
        color: tokens.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: tokens.border),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        selectedColor: tokens.selectedSurface,
        backgroundColor: Colors.transparent,
        side: BorderSide(color: tokens.outline),
        labelStyle: textTheme.labelLarge?.copyWith(color: tokens.textSecondary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.searchSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: tokens.textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: tokens.surface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.toolbarButton),
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme(double fontScale) {
    TextStyle style(
      double size,
      FontWeight weight,
      double lineHeight, {
      double letterSpacing = 0,
    }) {
      return TextStyle(
        fontFamily: 'Inter',
        fontSize: size * fontScale,
        fontWeight: weight,
        height: lineHeight / size,
        letterSpacing: letterSpacing,
      );
    }

    return TextTheme(
      displaySmall: style(42, FontWeight.w700, 52),
      headlineLarge: style(28, FontWeight.w700, 36),
      headlineMedium: style(28, FontWeight.w600, 36),
      headlineSmall: style(22, FontWeight.w500, 28),
      titleLarge: style(22, FontWeight.w500, 28),
      titleMedium: style(18, FontWeight.w400, 26),
      titleSmall: style(16, FontWeight.w400, 24),
      bodyLarge: style(18, FontWeight.w400, 29.25),
      bodyMedium: style(16, FontWeight.w400, 24),
      bodySmall: style(11, FontWeight.w500, 16, letterSpacing: 0.5),
      labelLarge: style(14, FontWeight.w500, 20, letterSpacing: 0.1),
      labelMedium: style(14, FontWeight.w500, 20, letterSpacing: 0.1),
      labelSmall: style(11, FontWeight.w500, 16, letterSpacing: 0.5),
    );
  }

  /// Returns the color for a given SermonStatus
  static Color statusColor(String status, ColorScheme colorScheme) {
    switch (status) {
      case 'draft':
        return AppColors.outline;
      case 'ready':
        return AppColors.ready;
      case 'delivered':
        return AppColors.delivered;
      default:
        return AppColors.outline;
    }
  }
}
