import 'package:flutter/widgets.dart';

OverlayEntry? _activeToastEntry;

/// Registers a new active toast overlay entry after dismissing any previous one.
void setActiveToastEntry(OverlayEntry entry) {
  dismissFreshKeepToast();
  _activeToastEntry = entry;
}

/// Immediately removes the currently visible toast overlay, if any.
void dismissFreshKeepToast() {
  final entry = _activeToastEntry;
  _activeToastEntry = null;
  if (entry != null && entry.mounted) {
    entry.remove();
  }
}

/// Clears the active toast reference when [entry] is disposed by its host.
void clearActiveToastIfMatches(OverlayEntry entry) {
  if (identical(_activeToastEntry, entry)) {
    _activeToastEntry = null;
  }
}
