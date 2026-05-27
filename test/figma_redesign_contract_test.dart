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
      expect(AppSpring.stiffness, 380);
      expect(AppSpring.damping, 26);
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
    expect(AppRouteFade.outgoingOpacity(0.10), closeTo(0.5, 0.01));
    expect(AppRouteFade.outgoingOpacity(0.20), 0);
    expect(AppRouteFade.outgoingOpacity(1), 0);
    expect(AppRouteFade.primaryOpacity(0), 0);
    expect(AppRouteFade.primaryOpacity(0.14), closeTo(0.5, 0.01));
    expect(AppRouteFade.primaryOpacity(0.28), 1);
  });

  test('route helpers release covered screen state after transitions', () {
    final route =
        AppRoutes.slideFromRight<void>(const SizedBox.shrink()) as PageRoute<void>;
    expect(route.maintainState, false);
  });

  test('frosted glass disables blur during active route animations', () {
    expect(
      FrostedGlass.shouldDisableBlur(
        primaryStatus: AnimationStatus.forward,
        secondaryStatus: AnimationStatus.dismissed,
        secondaryValue: 0,
      ),
      true,
    );
    expect(
      FrostedGlass.shouldDisableBlur(
        primaryStatus: AnimationStatus.completed,
        secondaryStatus: AnimationStatus.forward,
        secondaryValue: 0,
      ),
      true,
    );
    expect(
      FrostedGlass.shouldDisableBlur(
        primaryStatus: AnimationStatus.completed,
        secondaryStatus: AnimationStatus.completed,
        secondaryValue: 1,
      ),
      true,
    );
    expect(
      FrostedGlass.shouldDisableBlur(
        primaryStatus: AnimationStatus.completed,
        secondaryStatus: AnimationStatus.dismissed,
        secondaryValue: 0,
      ),
      false,
    );
  });

  test('editor toolbar keeps Quill controls in dock-style frosted glass', () {
    final source = File('lib/screens/editor/editor_screen.dart').readAsStringSync();
    expect(source, contains('FrostedGlass('));
    expect(source, contains('AppSpacing.floatingDockHeight'));
    expect(source, contains('QuillSimpleToolbar('));
    expect(source, isNot(contains('_keyboardController')));
  });

  test('dark theme and app gradient tokens are available', () {
    final dark = AppTheme.darkTheme();
    expect(dark.brightness, Brightness.dark);
    expect(AppTheme.gradientFor(Brightness.light).colors, const [
      Color(0xFFF3EEFF),
      Color(0xFFFFF4EC),
      Color(0xFFFDFBFF),
    ]);
    expect(AppTheme.gradientFor(Brightness.dark).colors.length, 3);
  });

  test('icon tap micro animation constants are centralized', () {
    expect(IconTap.pressedScale, 0.96);
    expect(IconTap.opacityPulseDuration, const Duration(milliseconds: 180));
    expect(IconTap.spring.stiffness, 500);
    expect(IconTap.spring.damping, 30);
    expect(IconTap.spring.mass, 1);
  });

  test('settings screen uses liquid glass panels and staggered entry', () {
    final source = File('lib/screens/settings/settings_screen.dart').readAsStringSync();
    expect(source, contains('FrostedGlass('));
    expect(source, contains('_SettingsSectionCard'));
    expect(source, contains('LaunchFade('));
    expect(source, contains('AppMotion.sectionStaggerMs'));
    expect(source, contains('_SpringChevron'));
    expect(source, contains('_LiquidFontSizeSegmentedControl'));
    expect(source, contains('_LiquidThemeModeRow'));
    expect(source, isNot(contains('=> SectionCard(')));
    expect(source, isNot(contains('AnimatedContainer(')));
  });

  test('dashboard title and search use liquid glass treatment', () {
    final source = File('lib/screens/dashboard/dashboard_screen.dart').readAsStringSync();
    expect(source, contains('_DashboardTitle'));
    expect(source, contains('_LiquidSearchBar'));
    expect(source, contains('FrostedGlass('));
    expect(source, contains('SearchGlassFocus'));
    expect(source, isNot(contains('fillColor: tokens.searchSurface')));
  });

  test('Inter is bundled as a local font asset', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('family: Inter'));
    expect(pubspec, contains('assets/fonts/Inter-VariableFont_opsz,wght.ttf'));
    expect(pubspec, isNot(contains('google_fonts')));
  });
}
