import 'package:flutter/material.dart';

import 'freshkeep_toast_card.dart';
import 'toast_overlay_host.dart';
import 'toast_state.dart';

export 'toast_state.dart' show dismissFreshKeepToast;

/// Shows a floating, automatically dismissing toast notification.
///
/// Unlike Material 3 `SnackBar` with actions, this always auto-dismisses after
/// [duration] even when [actionLabel] (such as `'Undo'`) is supplied.
void showFreshKeepToast(
  BuildContext context, {
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
  Duration? duration,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  final effectiveDuration =
      duration ??
      (actionLabel != null
          ? const Duration(seconds: 4)
          : const Duration(seconds: 3));

  late final OverlayEntry entry;
  void dismiss() {
    if (entry.mounted) entry.remove();
    clearActiveToastIfMatches(entry);
  }

  entry = OverlayEntry(
    builder: (_) => ToastOverlayHost(
      entry: entry,
      duration: effectiveDuration,
      onDismiss: dismiss,
      child: FreshKeepToastCard(
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
        onDismiss: dismiss,
      ),
    ),
  );

  setActiveToastEntry(entry);
  overlay.insert(entry);
}
