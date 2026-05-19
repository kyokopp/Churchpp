import 'package:flutter/cupertino.dart';

class AppPageTransitionTiming {
  const AppPageTransitionTiming._();

  static const duration = Duration(milliseconds: 220);
}

class AppCupertinoPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppCupertinoPageTransitionsBuilder();

  @override
  Duration get transitionDuration => AppPageTransitionTiming.duration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      CupertinoPageTransition.delegatedTransition;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final cupertinoTransition =
        CupertinoRouteTransitionMixin.buildPageTransitions<T>(
          route,
          context,
          animation,
          secondaryAnimation,
          child,
        );
    return AnimatedBuilder(
      animation: Listenable.merge([animation, secondaryAnimation]),
      child: cupertinoTransition,
      builder: (context, child) {
        final opacity = (animation.value * (1 - secondaryAnimation.value))
            .clamp(0.0, 1.0);
        return Opacity(opacity: opacity, child: child);
      },
    );
  }
}

class AppCupertinoPageRoute<T> extends PageRoute<T>
    with CupertinoRouteTransitionMixin<T> {
  AppCupertinoPageRoute({
    required this.builder,
    this.title,
    super.settings,
    super.requestFocus,
    this.maintainState = true,
    super.fullscreenDialog,
    super.allowSnapshotting = true,
    super.barrierDismissible = false,
  });

  final WidgetBuilder builder;

  @override
  final String? title;

  @override
  final bool maintainState;

  @override
  Duration get transitionDuration => AppPageTransitionTiming.duration;

  @override
  Duration get reverseTransitionDuration => AppPageTransitionTiming.duration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      fullscreenDialog ? null : CupertinoPageTransition.delegatedTransition;

  @override
  Widget buildContent(BuildContext context) => builder(context);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return const AppCupertinoPageTransitionsBuilder().buildTransitions<T>(
      this,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }

  @override
  String get debugLabel => '${super.debugLabel}(${settings.name})';
}

class AppCupertinoPage<T> extends Page<T> {
  const AppCupertinoPage({
    required this.child,
    this.maintainState = true,
    this.title,
    this.fullscreenDialog = false,
    this.allowSnapshotting = true,
    super.canPop,
    super.onPopInvoked,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  final Widget child;
  final String? title;
  final bool maintainState;
  final bool fullscreenDialog;
  final bool allowSnapshotting;

  @override
  Route<T> createRoute(BuildContext context) {
    return AppCupertinoPageRoute<T>(
      builder: (_) => child,
      title: title,
      settings: this,
      maintainState: maintainState,
      fullscreenDialog: fullscreenDialog,
      allowSnapshotting: allowSnapshotting,
    );
  }
}
