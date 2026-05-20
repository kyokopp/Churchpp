import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_cajado/theme/app_theme.dart';
import 'package:o_cajado/utils/app_routes.dart';
import 'package:o_cajado/widgets/figma_primitives.dart';

void main() {
  test('Figma redesign tokens are exposed exactly', () {
    expect(AppColors.background, const Color(0xFFFDF7FF));
    expect(AppColors.primary, const Color(0xFF4F378A));
    expect(AppColors.searchSurface, const Color(0xFFE6E0E9));
    expect(AppColors.selectedSurface, const Color(0xFFE8DEF9));
    expect(AppColors.textPrimary, const Color(0xFF1D1B20));
    expect(AppColors.border, const Color(0xFFCBC4D2));
    expect(AppRadii.pill, 9999);
    expect(AppSpacing.page, 24);
    expect(AppSpacing.topBarHeight, 64);
    expect(AppSpacing.floatingDockHeight, 64);
    expect(AppSpacing.floatingDockSideMargin, 16);
    expect(AppSpacing.floatingDockBottomGap, 16);
  });

  test('Figma typography uses Inter roles from the design plan', () {
    final theme = AppTheme.lightTheme();
    expect(theme.textTheme.headlineLarge?.fontFamily, 'Inter');
    expect(theme.textTheme.headlineLarge?.fontSize, 28);
    expect(theme.textTheme.headlineLarge?.height, closeTo(36 / 28, 0.001));
    expect(theme.textTheme.displaySmall?.fontSize, 42);
    expect(theme.textTheme.displaySmall?.height, closeTo(52 / 42, 0.001));
    expect(theme.textTheme.bodyLarge?.fontSize, 18);
    expect(theme.textTheme.bodyLarge?.height, closeTo(29.25 / 18, 0.001));
  });

  test(
    'route motion uses spring-style transitions instead of cubic easing',
    () {
      expect(AppRoutes.duration, const Duration(milliseconds: 220));
      expect(AppRoutes.springCurve, isNot(Curves.easeInOutCubic));
      expect(AppSpring.stiffness, 400);
      expect(AppSpring.damping, 28);
      expect(AppSpring.mass, 1);
    },
  );

  test('theme applies Cupertino page transitions on Android', () {
    final theme = AppTheme.lightTheme();

    expect(
      theme.pageTransitionsTheme.builders[TargetPlatform.android],
      isA<AppCupertinoPageTransitionsBuilder>(),
    );
  });

  test('app route helpers use shared liquid PageRouteBuilder transitions', () {
    final slideRoute = AppRoutes.slideFromRight<void>(const SizedBox.shrink());
    expect(slideRoute, isA<PageRouteBuilder<void>>());
    expect((slideRoute as PageRouteBuilder<void>).allowSnapshotting, false);
    expect(
      AppRoutes.slideFromBottom<void>(const SizedBox.shrink()),
      isA<PageRouteBuilder<void>>(),
    );
    expect(
      AppRoutes.fade<void>(const SizedBox.shrink()),
      isA<PageRouteBuilder<void>>(),
    );
    expect(
      AppRoutes.cupertinoPage<void>(child: const SizedBox.shrink()),
      isA<AppCupertinoPage<void>>(),
    );
  });

  test('route fade removes outgoing content early in the transition', () {
    expect(AppRouteFade.outgoingOpacity(0), 1);
    expect(AppRouteFade.outgoingOpacity(0.21), closeTo(0.5, 0.01));
    expect(AppRouteFade.outgoingOpacity(0.42), 0);
    expect(AppRouteFade.outgoingOpacity(1), 0);
    expect(AppRouteFade.primaryOpacity(0), 0);
    expect(AppRouteFade.primaryOpacity(0.14), closeTo(0.5, 0.01));
    expect(AppRouteFade.primaryOpacity(0.28), 1);
  });

  test('dark theme and app gradient tokens are available', () {
    final dark = AppTheme.darkTheme();
    expect(dark.brightness, Brightness.dark);
    expect(AppTheme.gradientFor(Brightness.light).colors, const [
      Color(0xFFF0EAFF),
      Color(0xFFE8F4FF),
      Color(0xFFFFF8F0),
    ]);
    expect(AppTheme.gradientFor(Brightness.dark).colors.length, 3);
  });

  test('icon tap micro animation constants are centralized', () {
    expect(IconTap.pressedScale, 0.82);
    expect(IconTap.opacityPulseDuration, const Duration(milliseconds: 180));
    expect(IconTap.spring.stiffness, 500);
    expect(IconTap.spring.damping, 22);
    expect(IconTap.spring.mass, 1);
  });

  test('Inter is bundled as a local font asset', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('family: Inter'));
    expect(pubspec, contains('assets/fonts/Inter-VariableFont_opsz,wght.ttf'));
    expect(pubspec, isNot(contains('google_fonts')));
  });
}
