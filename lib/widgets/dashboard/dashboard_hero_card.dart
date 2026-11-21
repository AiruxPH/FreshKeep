import 'package:flutter/material.dart';

import '../../domain/dashboard_summary.dart';
import '../../domain/inventory_report.dart';

/// Botanical green overview card summarizing stock activity and items needing
/// attention soon.
class DashboardHeroCard extends StatelessWidget {
  const DashboardHeroCard({
    super.key,
    required this.report,
    required this.summary,
  });

  final InventoryReport report;
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final total = report.batches.length;
    final active = report.activeBatches;
    final ratio = total == 0 ? 0.0 : active / total;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF28664B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.eco_outlined, color: Color(0xFFDDECE1)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kitchen overview',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            total == 0
                ? 'No batches tracked yet'
                : '$active of $total ${total == 1 ? 'batch' : 'batches'} in stock',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: const Color(0xFF1B4A35),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFA7E3C0),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: summary.attentionCount > 0
                  ? const Color(0xFFFFEFCB)
                  : const Color(0xFFDDECE1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              summary.attentionCount > 0
                  ? '${summary.attentionCount} active ${summary.attentionCount == 1 ? 'batch needs' : 'batches need'} attention soon'
                  : 'No active batches expiring within 3 days',
              style: TextStyle(
                color: summary.attentionCount > 0
                    ? const Color(0xFF674B00)
                    : const Color(0xFF1E3329),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
