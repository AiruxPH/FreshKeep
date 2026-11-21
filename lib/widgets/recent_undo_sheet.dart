import 'package:flutter/material.dart';

import '../data/inventory_database.dart';
import '../domain/recent_stock_action.dart';
import '../domain/stock_event.dart';
import 'toast/show_freshkeep_toast.dart';

/// Opens a persistent bottom sheet listing recent unreversed stock actions so
/// users can undo mistaken Use, Discard, or Correct actions even after the
/// toast disappears or an item leaves the active list.
Future<bool> showRecentUndoSheet(
  BuildContext context, {
  required InventoryDatabase database,
  VoidCallback? onUndone,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        _RecentUndoSheet(database: database, onUndone: onUndone),
  );
  return result ?? false;
}

class _RecentUndoSheet extends StatefulWidget {
  const _RecentUndoSheet({required this.database, this.onUndone});

  final InventoryDatabase database;
  final VoidCallback? onUndone;

  @override
  State<_RecentUndoSheet> createState() => _RecentUndoSheetState();
}

class _RecentUndoSheetState extends State<_RecentUndoSheet> {
  List<RecentStockAction> _actions = [];
  bool _loading = true;
  bool _busy = false;
  bool _failed = false;
  bool _undoneAny = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final actions = await widget.database.loadRecentUndoableEvents();
      if (mounted) setState(() => _actions = actions);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _undo(RecentStockAction action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.database.undoEvent(action.batchId, action.eventId);
      _undoneAny = true;
      widget.onUndone?.call();
      if (mounted) {
        showFreshKeepToast(
          context,
          message: 'Undone · ${action.food} restored.',
        );
        await _load();
      }
    } catch (error) {
      if (mounted) {
        showFreshKeepToast(
          context,
          message: error is StockValidationException
              ? error.message
              : 'Could not undo this entry. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Undo recent actions',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context, _undoneAny),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Text(
                'Reverse a mistaken use, discard, or stock correction. Original entries stay in history.',
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_failed)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text(
                          'Could not load recent actions. Please retry.',
                        ),
                        TextButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              else if (_actions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No recent actions to undo.')),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _actions.length,
                    itemBuilder: (context, index) {
                      final action = _actions[index];
                      final local = action.createdAt.toLocal();
                      final timestamp =
                          '${localizations.formatMediumDate(local)} · ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
                      final detailLine = action.reason == null
                          ? '${action.actionSummary}\n$timestamp'
                          : '${action.actionSummary} · ${action.reason}\n$timestamp';
                      return Card(
                        child: ListTile(
                          title: Text(action.food),
                          subtitle: Text(detailLine),
                          isThreeLine: true,
                          trailing: OutlinedButton.icon(
                            onPressed: _busy ? null : () => _undo(action),
                            icon: const Icon(Icons.undo, size: 18),
                            label: const Text('Undo'),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
