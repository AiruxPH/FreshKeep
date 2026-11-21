import 'package:flutter/material.dart';

import '../../domain/batch.dart';
import '../../domain/waste_query.dart';

/// Search bar and expandable unit/reason/date/sort controls for the Waste log.
class WasteFiltersBar extends StatelessWidget {
  const WasteFiltersBar({
    super.key,
    required this.searchController,
    required this.unit,
    required this.reason,
    required this.reasons,
    required this.dateRange,
    required this.sort,
    required this.hasFilters,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onUnitChanged,
    required this.onReasonChanged,
    required this.onDateRangeChanged,
    required this.onSortChanged,
    required this.onReset,
  });

  final TextEditingController searchController;
  final String unit;
  final String reason;
  final List<String> reasons;
  final WasteDateRange dateRange;
  final WasteSort sort;
  final bool hasFilters;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onUnitChanged;
  final ValueChanged<String> onReasonChanged;
  final ValueChanged<WasteDateRange> onDateRangeChanged;
  final ValueChanged<WasteSort> onSortChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final activeReason = reason == 'all' || reasons.contains(reason)
        ? reason
        : 'all';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            labelText: 'Search waste log',
            hintText: 'Food name or reason',
            isDense: true,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear waste search',
                    onPressed: onClearSearch,
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
                        key: ValueKey('waste-unit-$unit'),
                        initialValue: unit,
                        decoration: const InputDecoration(
                          labelText: 'Unit filter',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('All units'),
                          ),
                          ...BatchDraft.units.map(
                            (u) => DropdownMenuItem(value: u, child: Text(u)),
                          ),
                        ],
                        onChanged: (value) => onUnitChanged(value!),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('waste-reason-$activeReason'),
                        initialValue: activeReason,
                        decoration: const InputDecoration(
                          labelText: 'Reason filter',
                        ),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('All reasons'),
                          ),
                          ...reasons.map(
                            (r) => DropdownMenuItem(value: r, child: Text(r)),
                          ),
                        ],
                        onChanged: (value) => onReasonChanged(value!),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: DropdownButtonFormField<WasteDateRange>(
                        key: ValueKey('waste-range-$dateRange'),
                        initialValue: dateRange,
                        decoration: const InputDecoration(
                          labelText: 'Date range',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: WasteDateRange.allTime,
                            child: Text('All time'),
                          ),
                          DropdownMenuItem(
                            value: WasteDateRange.last7Days,
                            child: Text('Last 7 days'),
                          ),
                          DropdownMenuItem(
                            value: WasteDateRange.last30Days,
                            child: Text('Last 30 days'),
                          ),
                        ],
                        onChanged: (value) => onDateRangeChanged(value!),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: DropdownButtonFormField<WasteSort>(
                        key: ValueKey('waste-sort-$sort'),
                        initialValue: sort,
                        decoration: const InputDecoration(
                          labelText: 'Sort order',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: WasteSort.newest,
                            child: Text('Newest first'),
                          ),
                          DropdownMenuItem(
                            value: WasteSort.oldest,
                            child: Text('Oldest first'),
                          ),
                          DropdownMenuItem(
                            value: WasteSort.largestQty,
                            child: Text('Largest quantity'),
                          ),
                          DropdownMenuItem(
                            value: WasteSort.foodName,
                            child: Text('Food name A–Z'),
                          ),
                        ],
                        onChanged: (value) => onSortChanged(value!),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        if (hasFilters)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Reset filters'),
            ),
          ),
      ],
    );
  }
}
