import 'package:flutter/material.dart';

import 'data/inventory_database.dart';
import 'domain/batch.dart';
import 'domain/food_photo.dart';
import 'widgets/food_photo.dart';
import 'domain/stock_event.dart';

class EditBatchDialog extends StatefulWidget {
  const EditBatchDialog({
    super.key,
    required this.database,
    required this.batch,
    this.pickPhoto = pickFoodPhoto,
  });
  final InventoryDatabase database;
  final InventoryBatch batch;
  final PickFoodPhoto pickPhoto;
  @override
  State<EditBatchDialog> createState() => _EditBatchDialogState();
}

class _EditBatchDialogState extends State<EditBatchDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late String _storage;
  DateTime? _date;
  TimeOfDay? _time;
  FoodPhoto? _photo;
  bool _updatePhoto = false;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.batch.draft.name);
    _storage = widget.batch.draft.storage;
    _photo = widget.batch.draft.photo;
    _date = widget.batch.draft.printedDate == null
        ? null
        : DateTime.parse(widget.batch.draft.printedDate!);
    if (widget.batch.draft.printedTime != null) {
      final parts = widget.batch.draft.printedTime!.split(':');
      if (parts.length == 2) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null) _time = TimeOfDay(hour: h, minute: m);
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.database.editBatchDetails(
        widget.batch.id,
        BatchDetailsDraft(
          name: _name.text,
          storage: _storage,
          printedDate: _date == null ? null : BatchDraft.dateOnly(_date!),
          printedTime: _date == null || _time == null
              ? null
              : BatchDraft.timeOnly(_time!.hour, _time!.minute),
        ),
        expected: widget.batch.draft,
        updatePhoto: _updatePhoto,
        photo: _photo,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is StockValidationException
              ? error.message
              : 'Could not save changes. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Edit batch details'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Starting quantity and unit stay fixed. Use Correct stock to change the amount remaining.',
                ),
                const SizedBox(height: 20),
                FoodPhotoEditor(
                  photo: _photo,
                  enabled: !_saving,
                  pick: widget.pickPhoto,
                  onChanged: (photo) => setState(() {
                    _photo = photo;
                    _updatePhoto = true;
                  }),
                ),
                TextFormField(
                  controller: _name,
                  enabled: !_saving,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Food name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a food name.'
                      : value.trim().length > 100
                      ? 'Use at most 100 characters.'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _storage,
                  decoration: const InputDecoration(labelText: 'Storage'),
                  items: BatchDraft.locations
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _storage = v!),
                ),
                const SizedBox(height: 16),
                Tooltip(
                  message: 'Use only the date printed on this batch’s packaging. Clear it if no readable date is available.',
                  child: OutlinedButton.icon(
                    onPressed: _saving
                        ? null
                        : () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _date ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100, 12, 31),
                            );
                            if (date != null && mounted) {
                              setState(() => _date = date);
                            }
                          },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      _date == null
                          ? 'Printed date (optional)'
                          : BatchDraft.dateOnly(_date!),
                    ),
                  ),
                ),
                if (_date != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _saving
                        ? null
                        : () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _time ?? TimeOfDay.now(),
                            );
                            if (picked != null && mounted) {
                              setState(() => _time = picked);
                            }
                          },
                    icon: const Icon(Icons.access_time_outlined),
                    label: Text(
                      _time == null
                          ? 'Add expiry time (optional)'
                          : BatchDraft.timeOnly(_time!.hour, _time!.minute),
                    ),
                  ),
                  if (_time != null)
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() => _time = null),
                      child: const Text('Clear time'),
                    ),
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                              _date = null;
                              _time = null;
                            }),
                    child: const Text('Clear date'),
                  ),
                ],
                const Text(
                  'Date changes update labels and reminder plans. Detail edits are kept in history.',
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save changes'),
        ),
      ],
    ),
  );
}
