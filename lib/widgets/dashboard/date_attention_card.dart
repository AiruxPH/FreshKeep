import 'package:flutter/material.dart';

import '../../domain/batch.dart';
import '../../domain/dashboard_summary.dart';

/// Shows active inventory counts broken down by date urgency and storage spot.
class DateAttentionCard extends StatelessWidget {
  const DateAttentionCard({
    super.key,
    required this.summary,
    required this.activeBatches,
  });

  final DashboardSummary summary;
  final int activeBatches;

  @override
  Widget build(BuildContext context) {
    final buckets = [
      ('Past date', summary.pastCount, const Color(0xFFC64747)),
      ('Today / hours left', summary.urgentCount, const Color(0xFFD97706)),
      ('In 1–3 days', summary.soonCount, const Color(0xFFE0A100)),
      ('More than 3 days', summary.laterCount, const Color(0xFF28664B)),
      ('Date unknown', summary.unknownCount, const Color(0xFF7D8580)),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date attention',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Active batches grouped by printed or suggested date.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            for (final (label, count, color) in buckets)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(label)),
                        Text(
                          '$count',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: activeBatches == 0 ? 0 : count / activeBatches,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFF0F2EE),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 20),
            Text(
              'By storage',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final location in BatchDraft.locations)
                  Chip(
                    avatar: Icon(
                      switch (location) {
                        'Fridge' => Icons.kitchen_outlined,
                        'Freezer' => Icons.ac_unit,
                        _ => Icons.inventory_2_outlined,
                      },
                      size: 16,
                    ),
                    label: Text(
                      '$location · ${summary.byStorage[location] ?? 0}',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
