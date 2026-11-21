import 'package:flutter/material.dart';

import 'data/inventory_database.dart';
import 'domain/batch.dart';
import 'domain/dashboard_summary.dart';
import 'domain/inventory_report.dart';
import 'domain/waste_query.dart';
import 'batch_details_screen.dart';
import 'widgets/dashboard/dashboard_hero_card.dart';
import 'widgets/dashboard/dashboard_stat_grid.dart';
import 'widgets/dashboard/date_attention_card.dart';
import 'widgets/dashboard/top_waste_reasons_card.dart';
import 'widgets/dashboard/unit_breakdown_card.dart';
import 'widgets/local_day_scope.dart';
import 'widgets/waste/waste_entry_card.dart';
import 'widgets/waste/waste_filters_bar.dart';

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

  final _search = TextEditingController();
  String _unit = 'all';
  String _reason = 'all';
  WasteDateRange _dateRange = WasteDateRange.allTime;
  WasteSort _sort = WasteSort.newest;

  bool get _hasWasteFilters =>
      _search.text.isNotEmpty ||
      _unit != 'all' ||
      _reason != 'all' ||
      _dateRange != WasteDateRange.allTime ||
      _sort != WasteSort.newest;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _resetWasteFilters() => setState(() {
    _search.clear();
    _unit = 'all';
    _reason = 'all';
    _dateRange = WasteDateRange.allTime;
    _sort = WasteSort.newest;
  });

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

  List<Widget> _buildDashboard(BuildContext context) {
    final report = _report!;
    final summary = DashboardSummary.fromReport(
      report,
      LocalDayScope.maybeOf(context),
    );
    return [
      DashboardHeroCard(report: report, summary: summary),
      const SizedBox(height: 14),
      DashboardStatGrid(report: report),
      const SizedBox(height: 14),
      DateAttentionCard(
        summary: summary,
        activeBatches: report.activeBatches,
      ),
      const SizedBox(height: 20),
      Text(
        'Quantities by unit',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const Text(
        'Pieces, grams (g), and millilitres (mL) are counted separately.',
      ),
      const SizedBox(height: 6),
      UnitBreakdownCard(report: report),
      if (summary.topReasons.isNotEmpty) ...[
        const SizedBox(height: 14),
        TopWasteReasonsCard(
          reasons: summary.topReasons,
          totalDisposals: report.disposals.length,
        ),
      ],
      const SizedBox(height: 16),
      if (report.batches.isEmpty)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'No groceries yet. Add a batch from Inventory to get started.',
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    ReportScreen(database: widget.database, wasteLog: true),
              ),
            );
            if (mounted) await _load();
          },
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('Open waste log'),
        ),
      ),
    ];
  }

  List<Widget> _buildWasteLog(BuildContext context) {
    final report = _report!;
    final now = LocalDayScope.maybeOf(context);
    final reasons = distinctWasteReasons(report.disposals);
    final visible = queryWasteLog(
      report.disposals,
      now,
      search: _search.text,
      unit: _unit == 'all' ? null : _unit,
      reason: _reason == 'all' ? null : _reason,
      dateRange: _dateRange,
      sort: _sort,
    );
    final filteredTotals = wasteTotalsByUnit(visible);

    return [
      Text(
        '${report.disposals.length} disposal events',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 12),
      if (report.disposals.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No recorded waste. Food you discard from Inventory will appear here.',
            ),
          ),
        )
      else ...[
        WasteFiltersBar(
          searchController: _search,
          unit: _unit,
          reason: _reason,
          reasons: reasons,
          dateRange: _dateRange,
          sort: _sort,
          hasFilters: _hasWasteFilters,
          onSearchChanged: (_) => setState(() {}),
          onClearSearch: () {
            _search.clear();
            setState(() {});
          },
          onUnitChanged: (v) => setState(() => _unit = v),
          onReasonChanged: (v) => setState(() => _reason = v),
          onDateRangeChanged: (v) => setState(() => _dateRange = v),
          onSortChanged: (v) => setState(() => _sort = v),
          onReset: _resetWasteFilters,
        ),
        if (_hasWasteFilters) ...[
          Text(
            'Showing ${visible.length} of ${report.disposals.length} disposal events',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (visible.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final unit in BatchDraft.units)
                    if ((filteredTotals[unit] ?? 0) > 0)
                      Chip(
                        label: Text(
                          'Filtered: ${quantityLabel(filteredTotals[unit]!, unit)}',
                        ),
                      ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 6),
        if (visible.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text('No waste entries match your search and filters.'),
                  TextButton(
                    onPressed: _resetWasteFilters,
                    child: const Text('Reset filters'),
                  ),
                ],
              ),
            ),
          )
        else
          ...visible.map(
            (entry) => WasteEntryCard(
              entry: entry,
              onOpenBatch: () => _openBatch(entry.batchId),
            ),
          ),
      ],
    ];
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    if (!widget.wasteLog)
                      ..._buildDashboard(context)
                    else
                      ..._buildWasteLog(context),
                  ],
                ),
              ),
            ),
          ),
  );
}
