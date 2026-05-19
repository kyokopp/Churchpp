import 'package:flutter/material.dart';

/// Shows a floating [SnackBar] that auto-dismisses after [duration].
///
/// Any previously visible snackbar is hidden first so feedback never stacks.
/// If an [action] is provided (e.g. Undo) the snackbar still auto-dismisses
/// after the given duration.
void showTimedSnackBar(
  BuildContext context, {
  required String message,
  Duration duration = const Duration(seconds: 3),
  SnackBarAction? action,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  final controller = messenger.showSnackBar(
    SnackBar(content: Text(message), duration: duration, action: action),
  );
  Future<void>.delayed(duration, controller.close);
}
