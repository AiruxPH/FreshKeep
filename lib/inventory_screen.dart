import 'widgets/food_photo.dart';

import 'package:flutter/material.dart';

import 'data/inventory_database.dart';
import 'domain/batch.dart';
import 'batch_details_screen.dart';
import 'widgets/batch_date_label.dart';
import 'stock_action_dialog.dart';
import 'domain/stock_event.dart';
import 'add_groceries_dialog.dart';

import 'reminders/reminder_controller.dart';
import 'domain/inventory_query.dart';
import 'domain/date_status.dart';
import 'widgets/local_day_scope.dart';
import 'widgets/recent_undo_sheet.dart';
import 'widgets/toast/show_freshkeep_toast.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({
    super.key,
    required this.database,
    this.reminders,
    this.refreshToken = 0,
  });
  final InventoryDatabase database;
  final ReminderController? reminders;
  final int refreshToken;
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<InventoryBatch> _batches = [];
  bool _loading = true;
  bool _failed = false;
  final _search = TextEditingController();
  String _storage = 'all';
  String _dateFilter = 'all';
  StockFilter _stockFilter = StockFilter.active;
  InventorySort _sort = InventorySort.soonestDate;
  bool get _hasFilters =>
      _search.text.isNotEmpty ||
      _storage != 'all' ||
      _dateFilter != 'all' ||
      _stockFilter != StockFilter.active ||
      _sort != InventorySort.soonestDate;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _resetFilters() => setState(() {
    _search.clear();
    _storage = 'all';
    _dateFilter = 'all';
    _stockFilter = StockFilter.active;
    _sort = InventorySort.soonestDate;
  });

  Widget _filters() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: _search,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: 'Search inventory',
          hintText: 'Food name',
          isDense: true,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear inventory search',
                  onPressed: () {
                    _search.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.clear),
                ),
        ),
      ),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Filters and sort'),
        childrenPadding: const EdgeInsets.only(bottom: 12),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 500
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: width,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('storage-$_storage'),
                      initialValue: _storage,
                      decoration: const InputDecoration(
                        labelText: 'Storage filter',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('All storage'),
                        ),
                        ...BatchDraft.locations.map(
                          (v) => DropdownMenuItem(value: v, child: Text(v)),
                        ),
                      ],
                      onChanged: (value) => setState(() => _storage = value!),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('date-$_dateFilter'),
                      initialValue: _dateFilter,
                      decoration: const InputDecoration(
                        labelText: 'Date filter',
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('All dates'),
                        ),
                        ...DateStatus.values.map(
                          (v) => DropdownMenuItem(
                            value: v.name,
                            child: Text(v.label),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _dateFilter = value!),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: DropdownButtonFormField<StockFilter>(
                      key: ValueKey('stock-$_stockFilter'),
                      initialValue: _stockFilter,
                      decoration: const InputDecoration(
                        labelText: 'Stock filter',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: StockFilter.all,
                          child: Text('All batches'),
                        ),
                        DropdownMenuItem(
                          value: StockFilter.active,
                          child: Text('Active only'),
                        ),
                        DropdownMenuItem(
                          value: StockFilter.depleted,
                          child: Text('Depleted only'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _stockFilter = value!),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: DropdownButtonFormField<InventorySort>(
                      key: ValueKey('sort-$_sort'),
                      initialValue: _sort,
                      decoration: const InputDecoration(
                        labelText: 'Sort order',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: InventorySort.newest,
                          child: Text('Newest added'),
                        ),
                        DropdownMenuItem(
                          value: InventorySort.soonestDate,
                          child: Text('Soonest date'),
                        ),
                        DropdownMenuItem(
                          value: InventorySort.name,
                          child: Text('Food name A–Z'),
                        ),
                      ],
                      onChanged: (value) => setState(() => _sort = value!),
                    ),
                  ),
                ],
              );
            },
          ),
          if (_sort == InventorySort.soonestDate)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Oldest printed dates first, including past dates. Unknown dates come last.',
              ),
            ),
        ],
      ),
      if (_hasFilters)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _resetFilters,
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('Reset filters'),
          ),
        ),
    ],
  );
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant InventoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final batches = await widget.database.loadBatches();
      if (mounted) setState(() => _batches = batches);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => AddGroceriesScreen(database: widget.database),
      ),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _openBatch(InventoryBatch batch) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            BatchDetailsScreen(database: widget.database, batchId: batch.id),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openRecentUndo() async {
    await showRecentUndoSheet(
      context,
      database: widget.database,
      onUndone: () {
        if (mounted) _load();
      },
    );
  }

  void _showAll() => setState(() {
    _search.clear();
    _storage = 'all';
    _dateFilter = 'all';
    _stockFilter = StockFilter.all;
    _sort = InventorySort.soonestDate;
  });

  Future<void> _quickAction(InventoryBatch batch, StockAction action) async {
    final id = await showStockAction(
      context,
      database: widget.database,
      batch: batch,
      action: action,
    );
    if (id == null || !mounted) return;
    await _load();
    if (!mounted) return;
    showFreshKeepToast(
      context,
      message: action == StockAction.consume
          ? 'Food use recorded.'
          : 'Waste recorded.',
      actionLabel: 'Undo',
      onAction: () async {
        try {
          await widget.database.undoEvent(batch.id, id);
          if (mounted) await _load();
        } catch (error) {
          if (mounted) {
            showFreshKeepToast(
              context,
              message: error is StockValidationException
                  ? error.message
                  : 'Could not undo. Please try again.',
            );
          }
        }
      },
    );
  }

  Widget _foodCard(InventoryBatch batch) => Card(
    key: ValueKey('batch-${batch.id}'),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => _openBatch(batch),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (batch.draft.photo != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: FoodPhotoView(
                      photo: batch.draft.photo!,
                      label: 'Photo of ${batch.draft.name}',
                    ),
                  ),
                Expanded(
                  child: Text(
                    batch.draft.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => _openBatch(batch),
                  tooltip: 'View batch details',
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  quantityLabel(batch.remaining, batch.draft.unit),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(switch (batch.draft.storage) {
                      'Fridge' => Icons.kitchen_outlined,
                      'Freezer' => Icons.ac_unit,
                      _ => Icons.inventory_2_outlined,
                    }, size: 16),
                    const SizedBox(width: 6),
                    Text(batch.draft.storage),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            BatchDateLabel(
              printedDate: batch.draft.printedDate,
              printedTime: batch.draft.printedTime,
              guidance: batch.draft.guidance,
            ),
            if (batch.depleted)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Used up · history saved'),
              ),
            if (!batch.depleted)
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => _quickAction(batch, StockAction.consume),
                    icon: const Icon(Icons.restaurant_outlined, size: 18),
                    label: const Text('Use'),
                  ),
                  TextButton.icon(
                    onPressed: () => _quickAction(batch, StockAction.dispose),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Discard'),
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final visible = queryInventory(
      _batches,
      LocalDayScope.of(context),
      search: _search.text,
      storage: _storage == 'all' ? null : _storage,
      status: _dateFilter == 'all'
          ? null
          : DateStatus.values.byName(_dateFilter),
      stock: _stockFilter,
      sort: _sort,
    );
    final active = _batches.where((batch) => !batch.depleted).length;
    return Scaffold(
      appBar: AppBar(
        title: MediaQuery.sizeOf(context).width >= 1000
            ? null
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.eco_outlined),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'FreshKeep',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
        actions: [
          IconButton(
            key: const ValueKey('recent-undo-button'),
            onPressed: _loading ? null : _openRecentUndo,
            tooltip: 'Undo recent action',
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh inventory',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading || _failed ? null : _add,
        icon: const Icon(Icons.add),
        label: const Text('Add groceries'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 112),
            children: [
              Text(
                'My groceries',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '$active in stock · ${_batches.length - active} used up',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              if (!_loading && !_failed && _batches.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('In stock'),
                      selected: _stockFilter == StockFilter.active,
                      onSelected: (_) =>
                          setState(() => _stockFilter = StockFilter.active),
                    ),
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _stockFilter == StockFilter.all,
                      onSelected: (_) =>
                          setState(() => _stockFilter = StockFilter.all),
                    ),
                    ChoiceChip(
                      label: const Text('Used up'),
                      selected: _stockFilter == StockFilter.depleted,
                      onSelected: (_) =>
                          setState(() => _stockFilter = StockFilter.depleted),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _filters(),
                Text(
                  'Showing ${visible.length} of ${_batches.length} ${_batches.length == 1 ? 'batch' : 'batches'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
              ],
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_failed)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Text(
                          'Could not load your groceries. Please try again.',
                        ),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_batches.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Column(
                      children: [
                        Icon(Icons.kitchen_outlined, size: 48),
                        SizedBox(height: 16),
                        Text(
                          'A fresh start',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Add your first groceries to see what is in your kitchen.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else if (visible.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          _stockFilter == StockFilter.active && !_hasFilters
                              ? 'No food in stock right now.'
                              : 'No batches match your search and filters.',
                        ),
                        TextButton(
                          onPressed: _showAll,
                          child: const Text('Show all batches'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...visible.map(_foodCard),
            ],
          ),
        ),
      ),
    );
  }
}
