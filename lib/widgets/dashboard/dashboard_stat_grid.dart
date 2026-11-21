import 'package:flutter/material.dart';

import '../../domain/inventory_report.dart';

/// Responsive 2x2 / 4x1 grid of key batch and disposal counters.
class DashboardStatGrid extends StatelessWidget {
  const DashboardStatGrid({super.key, required this.report});

  final InventoryReport report;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 700
            ? (constraints.maxWidth - 24) / 4
            : (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatCard(
              width: width,
              icon: Icons.inventory_2_outlined,
              tint: const Color(0xFFE8EFF7),
              iconColor: const Color(0xFF294B70),
              label: 'Total batches',
              value: report.batches.length,
              help: 'All saved batches, including those used up.',
            ),
            _StatCard(
              width: width,
              icon: Icons.kitchen_outlined,
              tint: const Color(0xFFDDECE1),
              iconColor: const Color(0xFF28664B),
              label: 'In stock',
              value: report.activeBatches,
              help: 'Batches with food remaining.',
            ),
            _StatCard(
              width: width,
              icon: Icons.check_circle_outline,
              tint: const Color(0xFFEAEAEA),
              iconColor: const Color(0xFF424242),
              label: 'Used up',
              value: report.depletedBatches,
              help: 'Empty batches with saved history.',
            ),
            _StatCard(
              width: width,
              icon: Icons.delete_outline,
              tint: const Color(0xFFF8DFDF),
              iconColor: const Color(0xFF822D2D),
              label: 'Disposals',
              value: report.disposals.length,
              help: 'Recorded waste that have not been undone.',
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.width,
    required this.icon,
    required this.tint,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.help,
  });

  final double width;
  final IconData icon;
  final Color tint;
  final Color iconColor;
  final String label;
  final int value;
  final String help;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Tooltip(
        message: help,
        triggerMode: TooltipTriggerMode.tap,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(height: 10),
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
  }
}
