import 'package:flutter/material.dart';

import 'app_page_transitions.dart';
import '../widgets/figma_primitives.dart';

export 'app_page_transitions.dart';

class AppRoutes {
  const AppRoutes._();

  static const duration = AppPageTransitionTiming.duration;
  static const springCurve = AppSpring.curve;

  static AppCupertinoPage<T> cupertinoPage<T>({
    required Widget child,
    LocalKey? key,
    String? name,
    Object? arguments,
    String? restorationId,
    bool fullscreenDialog = false,
    bool maintainState = true,
  }) {
    return AppCupertinoPage<T>(
      key: key,
      name: name,
      arguments: arguments,
      restorationId: restorationId,
      fullscreenDialog: fullscreenDialog,
      maintainState: maintainState,
      child: child,
    );
  }

  static Route<T> slideFromRight<T>(Widget page) {
    return _liquidRoute<T>(
      page,
      begin: const Offset(1, 0),
      parallax: const Offset(-0.28, 0),
    );
  }

  static Route<T> slideFromBottom<T>(Widget page) {
    return _liquidRoute<T>(
      page,
      begin: const Offset(0, 1),
      parallax: const Offset(0, -0.10),
      overlayMaxOpacity: 0.14,
    );
  }

  static Route<T> fade<T>(Widget page) {
    return _liquidRoute<T>(
      page,
      begin: Offset.zero,
      scaleBegin: 0.96,
      overlayMaxOpacity: 0,
    );
  }

  static Route<T> _liquidRoute<T>(
    Widget page, {
    required Offset begin,
    Offset parallax = Offset.zero,
    double scaleBegin = 1,
    double overlayMaxOpacity = 0,
  }) {
    return PageRouteBuilder<T>(
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      allowSnapshotting: false,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final incomingCurved = CurvedAnimation(
          parent: animation,
          curve: AppSpring.softCurve,
          reverseCurve: AppSpring.softCurve,
        );
        final incomingSlide = Tween<Offset>(
          begin: begin,
          end: Offset.zero,
        ).animate(incomingCurved);
        final outgoingSlide = Tween<Offset>(
          begin: Offset.zero,
          end: parallax,
        ).animate(secondaryAnimation);

        return AnimatedBuilder(
          animation: Listenable.merge([animation, secondaryAnimation]),
          child: RepaintBoundary(child: child),
          builder: (context, child) {
            final overlayOpacity =
                overlayMaxOpacity *
                (1 - AppRouteFade.outgoingOpacity(secondaryAnimation.value));
            final scale =
                scaleBegin + ((1 - scaleBegin) * incomingCurved.value);
            final transitionedChild = SlideTransition(
              position: incomingSlide,
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: AppRouteFade.routeOpacity(
                    animation,
                    secondaryAnimation,
                  ),
                  child: child,
                ),
              ),
            );
            if (overlayMaxOpacity <= 0 && parallax == Offset.zero) {
              return transitionedChild;
            }
            return Stack(
              children: [
                if (overlayMaxOpacity > 0)
                  RepaintBoundary(
                    child: ColoredBox(
                      color: Color.fromRGBO(0, 0, 0, overlayOpacity),
                      child: const SizedBox.expand(),
                    ),
                  ),
                SlideTransition(
                  position: outgoingSlide,
                  child: transitionedChild,
                ),
              ],
            );
          },
        );
      },
    );
  }

  static Future<T?> showSpringDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    final theme = Theme.of(context);
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: duration,
      pageBuilder: (dialogContext, _, _) {
        return Theme(
          data: theme,
          child: Builder(builder: builder),
        );
      },
      transitionBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: AppSpring.softCurve,
          reverseCurve: AppSpring.softCurve,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  static Future<T?> showSpringBottomSheet<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    final theme = Theme.of(context);
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: duration,
      pageBuilder: (dialogContext, _, _) {
        return Theme(
          data: theme,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: Colors.transparent,
              child: Builder(builder: builder),
            ),
          ),
        );
      },
      transitionBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: springCurve,
          reverseCurve: springCurve,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }
}
