import 'package:flutter/material.dart';

import 'data/inventory_database.dart';
import 'domain/batch.dart';
import 'domain/stock_event.dart';
import 'edit_batch_dialog.dart';
import 'guidance_screen.dart';
import 'stock_action_dialog.dart';
import 'widgets/batch_date_label.dart';
import 'widgets/food_photo.dart';
import 'widgets/guidance/batch_guidance_card.dart';
import 'widgets/toast/show_freshkeep_toast.dart';

class BatchDetailsScreen extends StatefulWidget {
  const BatchDetailsScreen({
    super.key,
    required this.database,
    required this.batchId,
  });
  final InventoryDatabase database;
  final int batchId;
  @override
  State<BatchDetailsScreen> createState() => _BatchDetailsScreenState();
}

class _BatchDetailsScreenState extends State<BatchDetailsScreen> {
  InventoryBatch? _batch;
  List<StockEvent> _history = [];
  List<BatchEdit> _edits = [];
  double _waste = 0;
  bool _busy = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final batch = await widget.database.loadBatch(widget.batchId);
      final history = await widget.database.loadHistory(widget.batchId);
      final waste = await widget.database.disposedQuantity(widget.batchId);
      final edits = await widget.database.loadDetailsHistory(widget.batchId);
      if (mounted) {
        setState(() {
          _batch = batch;
          _history = history;
          _waste = waste;
          _edits = edits;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load this batch. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          EditBatchDialog(database: widget.database, batch: _batch!),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _openGuidance() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => GuidanceScreen(
          foodName: _batch!.draft.name,
          storage: _batch!.draft.storage,
          database: widget.database,
          batch: _batch,
        ),
      ),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _clearGuidance() async {
    final current = _batch!;
    setState(() => _busy = true);
    try {
      await widget.database.editBatchDetails(
        current.id,
        BatchDetailsDraft(
          name: current.draft.name,
          storage: current.draft.storage,
          category: current.draft.category,
          printedDate: current.draft.printedDate,
          printedTime: current.draft.printedTime,
        ),
        expected: current.draft,
        updateGuidance: true,
        guidance: null,
      );
      if (mounted) await _load();
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showFreshKeepToast(
          context,
          message: error is StockValidationException
              ? error.message
              : 'Could not clear suggested date. Please try again.',
        );
      }
    }
  }

  Future<void> _action(StockAction action) async {
    final saved = await showStockAction(
      context,
      database: widget.database,
      batch: _batch!,
      action: action,
    );
    if (saved != null && mounted) await _load();
  }

  Future<void> _undo(StockEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Undo this entry?'),
        content: Text(
          'This will reverse entry #${event.id}. The original and undo will stay in history. Undoing a disposal also corrects the recorded waste.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Undo entry'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.database.undoEvent(widget.batchId, event.id);
      if (mounted) await _load();
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showFreshKeepToast(
          context,
          message: error is StockValidationException
              ? error.message
              : 'Could not undo this entry. Please try again.',
        );
      }
    }
  }

  String _eventTitle(StockEvent event) {
    final label = switch (event.type) {
      'consume' => 'Consumed',
      'dispose' => 'Disposed',
      'correct' => 'Stock correction',
      _ => 'Undo',
    };
    return '#${event.id} $label · ${event.delta > 0 ? '+' : ''}${quantityLabel(event.delta, _batch!.draft.unit)}${event.reversed ? ' · Undone' : ''}';
  }

  Widget _stockHistory() => Card(
    child: ExpansionTile(
      title: const Text('Batch history'),
      subtitle: Text(
        '${_history.length} recorded ${_history.length == 1 ? 'action' : 'actions'}',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        if (_history.isEmpty) const Text('No stock actions yet.'),
        for (final event in _history)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _eventTitle(event),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  '${MaterialLocalizations.of(context).formatMediumDate(event.createdAt.toLocal())} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(event.createdAt.toLocal()))}',
                ),
                if (event.reason != null) Text(event.reason!),
                if (!event.reversed && event.type != 'reverse')
                  TextButton.icon(
                    onPressed: () => _undo(event),
                    icon: const Icon(Icons.undo),
                    label: const Text('Undo entry'),
                  ),
                const Divider(),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _detailsHistory() => Card(
    child: ExpansionTile(
      title: const Text('Details history'),
      subtitle: Text(
        '${_edits.length} saved ${_edits.length == 1 ? 'change' : 'changes'}',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        for (final edit in _edits)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Details updated'),
                if (edit.photoChange != null) Text(edit.photoChange!),
                if (edit.guidanceChange != null) Text(edit.guidanceChange!),
                if (edit.before.name != edit.after.name)
                  Text('Name: ${edit.before.name} → ${edit.after.name}'),
                if (edit.before.storage != edit.after.storage)
                  Text(
                    'Storage: ${edit.before.storage} → ${edit.after.storage}',
                  ),
                if (edit.before.category != edit.after.category)
                  Text(
                    'Category: ${edit.before.category} → ${edit.after.category}',
                  ),
                if (edit.before.printedDate != edit.after.printedDate)
                  Text(
                    'Printed date: ${edit.before.printedDate ?? 'Unknown'} → ${edit.after.printedDate ?? 'Unknown'}',
                  ),
                Text(
                  '${MaterialLocalizations.of(context).formatMediumDate(edit.createdAt.toLocal())} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(edit.createdAt.toLocal()))}',
                ),
                const Divider(),
              ],
            ),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_batch?.draft.name ?? 'Food details'),
      actions: [
        IconButton(
          onPressed: _busy || _error != null ? null : _edit,
          tooltip: 'Edit batch details',
          icon: const Icon(Icons.edit_outlined),
        ),
      ],
    ),
    body: _busy
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!),
                TextButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          )
        : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_batch!.draft.photo != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FoodPhotoView(
                          photo: _batch!.draft.photo!,
                          label: 'Photo of ${_batch!.draft.name}',
                          size: 180,
                        ),
                      ),
                    ),
                  Text(
                    '${quantityLabel(_batch!.remaining, _batch!.draft.unit)} remaining',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_batch!.draft.storage} · ${_batch!.draft.category}',
                  ),
                  if (_batch!.depleted)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Used up. Its history is saved below.'),
                    ),
                  const SizedBox(height: 12),
                 BatchDateLabel(
                   printedDate: _batch!.draft.printedDate,
                   printedTime: _batch!.draft.printedTime,
                   guidance: _batch!.draft.guidance,
                 ),
                 if (_batch!.draft.guidance != null)
                   Padding(
                     padding: const EdgeInsets.only(top: 12),
                     child: BatchGuidanceCard(
                       guidance: _batch!.draft.guidance!,
                       hasPrintedDate: _batch!.draft.printedDate != null,
                       onChange: _openGuidance,
                       onClear: _clearGuidance,
                     ),
                   ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: _batch!.depleted
                            ? null
                            : () => _action(StockAction.consume),
                        icon: const Icon(Icons.restaurant_outlined),
                        label: const Text('Use'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _batch!.depleted
                            ? null
                            : () => _action(StockAction.dispose),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Discard'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _action(StockAction.correct),
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Correct stock'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recorded waste: ${quantityLabel(_waste, _batch!.draft.unit)}',
                          ),
                          Text(
                            'Started with ${quantityLabel(_batch!.draft.quantity, _batch!.draft.unit)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: const Icon(Icons.menu_book_outlined),
                    title: const Text('Storage guidance'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _openGuidance,
                  ),
                  const SizedBox(height: 16),
                  _stockHistory(),
                  if (_edits.isNotEmpty) _detailsHistory(),
                ],
              ),
            ),
          ),
  );
}
