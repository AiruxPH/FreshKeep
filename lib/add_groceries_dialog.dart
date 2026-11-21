import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'data/inventory_database.dart';
import 'domain/batch.dart';
import 'domain/food_photo.dart';
import 'domain/ocr/ocr_models.dart';
import 'ocr/ocr_service.dart';
import 'ocr/pick_scan_image.dart';
import 'ocr/scan_label_screen.dart';
import 'widgets/food_photo.dart';

class AddGroceriesScreen extends StatefulWidget {
  const AddGroceriesScreen({
    super.key,
    required this.database,
    this.pickPhoto = pickFoodPhoto,
    this.takePhoto = takeFoodPhoto,
    this.initialDrafts = const [],
    this.ocrService,
    this.pickScanImage,
  });
  final InventoryDatabase database;
  final PickFoodPhoto pickPhoto;
  final PickFoodPhoto takePhoto;
  final List<OcrGroceryDraft> initialDrafts;
  final OcrService? ocrService;
  final PickScanImage? pickScanImage;
  @override
  State<AddGroceriesScreen> createState() => _AddGroceriesScreenState();
}

class _DraftRow {
  final key = GlobalKey();
  final name = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final focus = FocusNode();
  String unit = 'pieces';
  String storage = 'Pantry';
  DateTime? date;
  TimeOfDay? time;
  FoodPhoto? photo;

  BatchDraft toBatch() => BatchDraft(
    photo: photo,
    name: name.text,
    quantity: int.parse(quantity.text.trim()),
    unit: unit,
    storage: storage,
    printedDate: date == null ? null : BatchDraft.dateOnly(date!),
    printedTime: date == null || time == null
        ? null
        : BatchDraft.timeOnly(time!.hour, time!.minute),
  );
  void dispose() {
    name.dispose();
    quantity.dispose();
    focus.dispose();
  }
}

class _AddGroceriesScreenState extends State<AddGroceriesScreen> {
  final _form = GlobalKey<FormState>();
  final _rows = <_DraftRow>[];
  // Retire removed controllers only after their fields leave the tree.
  final _retired = <_DraftRow>[];
  List<String> _names = [];
  bool _saving = false;
  bool _ocrDrafted = false;
  String? _error;
  bool _namesFailed = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialDrafts.isEmpty) {
      _rows.add(_DraftRow());
    } else {
      _ocrDrafted = true;
      for (final draft in widget.initialDrafts) {
        final row = _DraftRow();
        row.name.text = draft.name;
        row.date = draft.printedDate == null
            ? null
            : DateTime.tryParse(draft.printedDate!);
        row.photo = draft.photo;
        _rows.add(row);
      }
    }
    _loadNames();
    if (widget.pickPhoto == pickFoodPhoto && widget.takePhoto == takeFoodPhoto) {
      _recoverLost();
    }
  }

  Future<void> _recoverLost() async {
    final recovered = await recoverLostPhoto();
    if (recovered != null &&
        mounted &&
        _rows.isNotEmpty &&
        _rows.first.photo == null) {
      setState(() => _rows.first.photo = recovered);
    }
  }

  Future<void> _loadNames() async {
    try {
      final names = await widget.database.previousFoodNames();
      if (mounted) {
        setState(() {
          _names = names;
          _namesFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _namesFailed = true);
    }
  }

  @override
  void dispose() {
    for (final row in [..._rows, ..._retired]) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_form.currentState!.validate()) {
      setState(
        () => _error = 'Check the highlighted rows. Nothing has been saved.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final drafts = _rows.map((row) => row.toBatch()).toList();
      await widget.database.addBatches(drafts);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save your groceries. No rows were saved. Please try again.';
        });
      }
    }
  }

  Widget _foodName(_DraftRow row, int index) => RawAutocomplete<String>(
    textEditingController: row.name,
    focusNode: row.focus,
    optionsBuilder: (value) => _saving || value.text.trim().isEmpty
        ? const Iterable<String>.empty()
        : _names
              .where(
                (name) => name.toLowerCase().contains(
                  value.text.trim().toLowerCase(),
                ),
              )
              .take(8),
    fieldViewBuilder: (context, controller, focus, submit) => TextFormField(
      key: ValueKey('name-${row.key}'),
      controller: controller,
      focusNode: focus,
      enabled: !_saving,
      autofocus: index == 0 && widget.initialDrafts.isEmpty,
      maxLength: 100,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'Food name',
        hintText: 'e.g. Eggs',
        counterText: '',
        suffixIcon: _FieldHelp(
          'Search names you have saved before. Reusing a name does not copy an old quantity or date.',
        ),
      ),
      validator: (value) => value == null || value.trim().isEmpty
          ? 'Enter a food name.'
          : value.trim().length > 100
          ? 'Use at most 100 characters.'
          : null,
      onFieldSubmitted: (_) => submit(),
    ),
    optionsViewBuilder: (context, select, options) => Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: 200,
            maxWidth: math.min(380, MediaQuery.sizeOf(context).width - 64),
          ),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: options
                .map(
                  (name) =>
                      ListTile(title: Text(name), onTap: () => select(name)),
                )
                .toList(),
          ),
        ),
      ),
    ),
  );

  Widget _entry(_DraftRow row, int index) => Card(
    key: row.key,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Food ${index + 1}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Remove grocery ${index + 1}',
                onPressed: _saving || _rows.length == 1
                    ? null
                    : () => setState(() {
                        _rows.remove(row);
                        _retired.add(row);
                      }),
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ],
          ),
          _foodName(row, index),
          FoodPhotoEditor(
            photo: row.photo,
            enabled: !_saving,
            pick: widget.pickPhoto,
            capture: widget.takePhoto,
            onChanged: (photo) => setState(() => row.photo = photo),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final quantity = TextFormField(
                controller: row.quantity,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  errorMaxLines: 3,
                  suffixIcon: _FieldHelp(
                    'Use whole numbers. For 0.5 kg, enter 500 and choose g.',
                  ),
                ),
                validator: (value) {
                  final quantity = int.tryParse(value?.trim() ?? '');
                  return quantity == null ||
                          quantity < 1 ||
                          quantity > 1000000000
                      ? 'Enter a whole number from 1 to 1,000,000,000.'
                      : null;
                },
              );
              final unit = DropdownButtonFormField<String>(
                initialValue: row.unit,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Unit'),
                items: BatchDraft.units
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => row.unit = value!),
              );
              if (constraints.maxWidth < 280 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.5) {
                return Column(
                  children: [quantity, const SizedBox(height: 12), unit],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: quantity),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: unit),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            maintainState: true,
            initiallyExpanded: row.date != null,
            title: const Text('Storage & date'),
            subtitle: Text(
              '${row.storage} · ${row.date == null ? 'Date unknown' : row.date != null && row.time != null ? '${BatchDraft.dateOnly(row.date!)} ${BatchDraft.timeOnly(row.time!.hour, row.time!.minute)}' : BatchDraft.dateOnly(row.date!)}',
            ),
            children: [
              DropdownButtonFormField<String>(
                initialValue: row.storage,
                decoration: const InputDecoration(labelText: 'Storage'),
                items: BatchDraft.locations
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => row.storage = value!),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: row.date ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100, 12, 31),
                        );
                        if (date != null && mounted) {
                          setState(() => row.date = date);
                        }
                      },
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  row.date == null
                      ? 'Add printed date'
                      : BatchDraft.dateOnly(row.date!),
                ),
              ),
              if (row.date != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: row.time ?? TimeOfDay.now(),
                          );
                          if (picked != null && mounted) {
                            setState(() => row.time = picked);
                          }
                        },
                  icon: const Icon(Icons.access_time_outlined),
                  label: Text(
                    row.time == null
                        ? 'Add expiry time (optional)'
                        : BatchDraft.timeOnly(row.time!.hour, row.time!.minute),
                  ),
                ),
                if (row.time != null)
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() => row.time = null),
                    child: const Text('Clear time'),
                  ),
              ],
              if (row.date != null)
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                            row.date = null;
                            row.time = null;
                          }),
                  child: const Text('Clear date'),
                ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'No readable date? Leave it unknown. Use only the date on this packaging.',
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  void _addRow() {
    final row = _DraftRow();
    setState(() => _rows.add(row));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = row.key.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 250),
          alignment: 0.05,
        );
      }
      row.focus.requestFocus();
    });
  }

  Future<void> _scanLabel() async {
    if (_saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final draft = await Navigator.of(context).push<OcrGroceryDraft>(
      MaterialPageRoute<OcrGroceryDraft>(
        fullscreenDialog: true,
        builder: (_) => ScanLabelScreen(
          returnDraftOnly: true,
          ocrService: widget.ocrService,
          pickImage: widget.pickScanImage ?? pickScanImageFromSource,
        ),
      ),
    );
    if (!mounted || draft == null) return;
    setState(() {
      _error = null;
      _ocrDrafted = true;
      final last = _rows.last;
      final lastUntouched =
          last.name.text.trim().isEmpty &&
          last.quantity.text.trim() == '1' &&
          last.date == null &&
          last.photo == null;
      final target = lastUntouched ? last : _DraftRow();
      target.name.text = draft.name;
      target.date = draft.printedDate == null
          ? null
          : DateTime.tryParse(draft.printedDate!);
      target.photo = draft.photo;
      if (!lastUntouched) {
        _rows.add(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: const Text('Add groceries')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Use separate entries for different foods or printed dates.',
                  ),
                  if (_ocrDrafted) ...[
                    const SizedBox(height: 10),
                    Card(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Drafted from label scan. Review name, quantity, storage, and printed date before saving.',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_namesFailed)
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Name suggestions are unavailable. You can still type.',
                          ),
                        ),
                        TextButton(
                          onPressed: _saving ? null : _loadNames,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  for (var index = 0; index < _rows.length; index++)
                    _entry(_rows[index], index),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const ValueKey('add-grocery-row'),
                    onPressed: _saving ? null : _addRow,
                    icon: const Icon(Icons.add),
                    label: const Text('Add another food'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const ValueKey('scan-label-button'),
                    onPressed: _saving ? null : _scanLabel,
                    icon: const Icon(Icons.document_scanner_outlined),
                    label: const Text('Scan label (beta)'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            top: false,
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      Text(
                        '${_rows.length} ${_rows.length == 1 ? 'entry' : 'entries'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      if (MediaQuery.textScalerOf(context).scale(1) > 1.5) ...[
                        FilledButton(
                          key: const ValueKey('save-groceries'),
                          onPressed: _saving ? null : _save,
                          child: Text(_saving ? 'Saving…' : 'Save groceries'),
                        ),
                        TextButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ] else
                        Row(
                          children: [
                            TextButton(
                              onPressed: _saving
                                  ? null
                                  : () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: FilledButton(
                                key: const ValueKey('save-groceries'),
                                onPressed: _saving ? null : _save,
                                child: Text(
                                  _saving ? 'Saving…' : 'Save groceries',
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _FieldHelp extends StatelessWidget {
  const _FieldHelp(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: message,
    triggerMode: TooltipTriggerMode.tap,
    waitDuration: const Duration(milliseconds: 400),
    showDuration: const Duration(seconds: 6),
    child: const Padding(
      padding: EdgeInsets.all(12),
      child: Icon(Icons.help_outline, size: 20),
    ),
  );
}
