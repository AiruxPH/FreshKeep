import 'package:flutter/material.dart';

import '../../domain/dashboard_summary.dart';

/// Displays the most frequent recorded waste reasons across unreversed disposals.
class TopWasteReasonsCard extends StatelessWidget {
  const TopWasteReasonsCard({
    super.key,
    required this.reasons,
    required this.totalDisposals,
  });

  final List<ReasonTotal> reasons;
  final int totalDisposals;

  @override
  Widget build(BuildContext context) {
    if (reasons.isEmpty || totalDisposals == 0) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top waste reasons',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            for (final item in reasons.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(item.reason)),
                        Text(
                          '${item.count} ${item.count == 1 ? 'event' : 'events'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: item.count / totalDisposals,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFF5ECEC),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFB85454),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
