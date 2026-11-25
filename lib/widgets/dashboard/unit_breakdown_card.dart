import 'package:flutter/material.dart';

import '../../domain/batch.dart';
import '../../domain/inventory_report.dart';
import '../../domain/quantity/format_quantity.dart';

/// Displays remaining and discarded totals per compatible unit with visual
/// remaining-vs-discarded bars.
class UnitBreakdownCard extends StatelessWidget {
  const UnitBreakdownCard({super.key, required this.report});

  final InventoryReport report;

  @override
  Widget build(BuildContext context) {
    final remaining = report.remainingByUnit;
    final waste = report.disposedByUnit;

    Widget row(
      String unit,
      String stock,
      String disposed, {
      bool heading = false,
      double? remainingFraction,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          DefaultTextStyle.merge(
            style: TextStyle(
              fontWeight: heading ? FontWeight.bold : FontWeight.normal,
            ),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text(unit)),
                Expanded(flex: 3, child: Text(stock, textAlign: TextAlign.end)),
                Expanded(
                  flex: 3,
                  child: Text(disposed, textAlign: TextAlign.end),
                ),
              ],
            ),
          ),
          if (remainingFraction != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: remainingFraction,
                minHeight: 6,
                backgroundColor: const Color(0xFFF3D4D4),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF28664B),
                ),
              ),
            ),
          ],
        ],
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
              () {
                final rem = remaining[unit] ?? 0;
                final disp = waste[unit] ?? 0;
                final total = rem + disp;
                return row(
                  unit,
                  formatQuantityValue(rem),
                  formatQuantityValue(disp),
                  remainingFraction: total == 0 ? 0.0 : rem / total,
                );
              }(),
          ],
        ),
      ),
    );
  }
}
