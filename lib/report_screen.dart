import 'package:flutter/material.dart';

import 'batch_details_screen.dart';
import 'data/inventory_database.dart';
import 'domain/batch.dart';
import 'domain/inventory_report.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({
    super.key,
    required this.database,
    this.wasteLog = false,
  });
  final InventoryDatabase database;
  final bool wasteLog;
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  InventoryReport? _report;
  bool _loading = true;
  bool _failed = false;

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
      final report = await widget.database.loadReport();
      if (mounted) setState(() => _report = report);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openBatch(int id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            BatchDetailsScreen(database: widget.database, batchId: id),
      ),
    );
    if (mounted) await _load();
  }

  Widget _stat(String label, int value, String help, {double width = 190}) =>
      SizedBox(
        width: width,
        child: Tooltip(
          message: help,
          triggerMode: TooltipTriggerMode.tap,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$value',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(label),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _quantities() {
    final remaining = _report!.remainingByUnit;
    final waste = _report!.disposedByUnit;
    Widget row(
      String unit,
      String stock,
      String disposed, {
      bool heading = false,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          fontWeight: heading ? FontWeight.bold : FontWeight.normal,
        ),
        child: Row(
          children: [
            Expanded(flex: 2, child: Text(unit)),
            Expanded(flex: 3, child: Text(stock, textAlign: TextAlign.end)),
            Expanded(flex: 3, child: Text(disposed, textAlign: TextAlign.end)),
          ],
        ),
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            row('Unit', 'Remaining', 'Discarded', heading: true),
            const Divider(),
            for (final unit in BatchDraft.units)
              row(unit, '${remaining[unit]}', '${waste[unit]}'),
          ],
        ),
      ),
    );
  }

  Widget _wasteEntry(WasteEntry entry) {
    final local = entry.createdAt.toLocal();
    final locale = MaterialLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.food, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Discarded ${quantityLabel(entry.quantity, entry.unit)}'),
            Text('Reason: ${entry.reason}'),
            Text(
              '${locale.formatMediumDate(local)} · ${locale.formatTimeOfDay(TimeOfDay.fromDateTime(local))}',
            ),
            Text('Batch #${entry.batchId} · Entry #${entry.id}'),
            const SizedBox(height: 8),
            Tooltip(
              message: 'Open this batch to review history or undo a mistaken disposal.',
              child: TextButton.icon(
                onPressed: () => _openBatch(entry.batchId),
                icon: const Icon(Icons.history),
                label: const Text('View batch history'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.wasteLog ? 'Waste log' : 'Dashboard'),
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          tooltip: 'Refresh report',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _failed
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Could not load this report. Your saved records have not been cleared.',
                  ),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            ),
          )
        : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    widget.wasteLog
                        ? 'Recorded waste'
                        : 'Your tracked inventory',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'All time · Only recorded disposals count as waste. Undone entries are excluded.',
                  ),
                  const SizedBox(height: 20),
                  if (!widget.wasteLog) ...[
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth >= 700
                            ? (constraints.maxWidth - 24) / 4
                            : (constraints.maxWidth - 8) / 2;
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _stat(
                              'Total batches',
                              _report!.batches.length,
                              'All saved batches, including those used up.',
                              width: width,
                            ),
                            _stat(
                              'In stock',
                              _report!.activeBatches,
                              'Batches with food remaining.',
                              width: width,
                            ),
                            _stat(
                              'Used up',
                              _report!.depletedBatches,
                              'Empty batches with saved history.',
                              width: width,
                            ),
                            _stat(
                              'Disposals',
                              _report!.disposals.length,
                              'Recorded waste that have not been undone.',
                              width: width,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Quantities by unit',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Text(
                      'Pieces, grams (g), and millilitres (mL) are counted separately.',
                    ),
                    _quantities(),
                    const SizedBox(height: 16),
                    if (_report!.batches.isEmpty)
                      const Text(
                        'No groceries yet. Add a batch from Inventory to get started.',
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ReportScreen(
                                database: widget.database,
                                wasteLog: true,
                              ),
                            ),
                          );
                          if (mounted) await _load();
                        },
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const Text('Open waste log'),
                      ),
                    ),
                  ] else ...[
                    Text(
                      '${_report!.disposals.length} disposal events',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (_report!.disposals.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No recorded waste. Food you discard from Inventory will appear here.',
                          ),
                        ),
                      ),
                    ..._report!.disposals.map(_wasteEntry),
                  ],
                ],
              ),
            ),
          ),
  );
}
