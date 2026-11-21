import 'package:flutter/material.dart';

import 'data/inventory_database.dart';
import 'domain/batch.dart';
import 'domain/stock_event.dart';

Future<int?> showStockAction(
  BuildContext context, {
  required InventoryDatabase database,
  required InventoryBatch batch,
  required StockAction action,
}) {
  final sheet = MediaQuery.sizeOf(context).width < 600;
  final form = StockActionDialog(
    database: database,
    batch: batch,
    action: action,
    sheet: sheet,
  );
  if (sheet) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => form,
    );
  }
  return showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (_) => form,
  );
}

class StockActionDialog extends StatefulWidget {
  const StockActionDialog({
    super.key,
    required this.database,
    required this.batch,
    required this.action,
    this.sheet = false,
  });
  final InventoryDatabase database;
  final InventoryBatch batch;
  final StockAction action;
  final bool sheet;
  @override
  State<StockActionDialog> createState() => _StockActionDialogState();
}

class _StockActionDialogState extends State<StockActionDialog> {
  final _form = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _reason = TextEditingController();
  bool _saving = false;
  String? _error;
  bool get _correct => widget.action == StockAction.correct;
  @override
  void dispose() {
    _quantity.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = await widget.database.recordAction(
        widget.batch.id,
        widget.action,
        int.parse(_quantity.text.trim()),
        reason: _reason.text,
        expectedRemaining: widget.batch.remaining,
      );
      if (mounted) Navigator.pop(context, id);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is StockValidationException
              ? error.message
              : 'Could not save. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.action) {
      StockAction.consume => 'Use food',
      StockAction.dispose => 'Discard food',
      StockAction.correct => 'Correct stock',
    };
    final content = Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.batch.draft.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            '${quantityLabel(widget.batch.remaining, widget.batch.draft.unit)} remaining',
          ),
          const SizedBox(height: 16),
          Text(
            _correct
                ? 'How much is actually left? This does not count as waste.'
                : widget.action == StockAction.dispose
                ? 'How much did you discard? This will be recorded as waste.'
                : 'How much did you eat or use?',
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _quantity,
            enabled: !_saving,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _correct ? 'Actual amount left' : 'Quantity',
              suffixText: widget.batch.draft.unit,
              errorMaxLines: 3,
            ),
            validator: (value) {
              final quantity = int.tryParse(value?.trim() ?? '');
              if (quantity == null) return 'Enter a whole number.';
              try {
                stockDelta(widget.action, quantity, widget.batch.remaining);
              } on StockValidationException catch (error) {
                return error.message;
              }
              return null;
            },
          ),
          if (widget.action != StockAction.consume) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _reason,
              enabled: !_saving,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'Add a short note',
              ),
            ),
          ],
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
    final actions = [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('confirm-stock-action'),
        onPressed: _saving ? null : _save,
        child: Text(
          _saving
              ? 'Saving…'
              : switch (widget.action) {
                  StockAction.consume => 'Record use',
                  StockAction.dispose => 'Record waste',
                  StockAction.correct => 'Save correction',
                },
        ),
      ),
    ];
    return PopScope(
      canPop: !_saving,
      child: widget.sheet
          ? Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    content,
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 12,
                      runSpacing: 8,
                      children: actions,
                    ),
                  ],
                ),
              ),
            )
          : AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(child: content),
              ),
              actions: actions,
            ),
    );
  }
}
