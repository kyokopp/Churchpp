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
    return AppCupertinoPageRoute<T>(builder: (_) => page);
  }

  static Route<T> slideFromBottom<T>(Widget page) {
    return AppCupertinoPageRoute<T>(builder: (_) => page);
  }

  static Route<T> fade<T>(Widget page) {
    return AppCupertinoPageRoute<T>(builder: (_) => page);
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
          curve: springCurve,
          reverseCurve: springCurve,
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
