import 'package:flutter/material.dart';

import '../../domain/batch.dart';
import '../../domain/inventory_report.dart';

/// Card presenting a single unreversed disposal record with batch history link.
class WasteEntryCard extends StatelessWidget {
  const WasteEntryCard({
    super.key,
    required this.entry,
    required this.onOpenBatch,
  });

  final WasteEntry entry;
  final VoidCallback onOpenBatch;

  @override
  Widget build(BuildContext context) {
    final local = entry.createdAt.toLocal();
    final locale = MaterialLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    entry.food,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8DFDF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Discarded ${quantityLabel(entry.quantity, entry.unit)}',
                    style: const TextStyle(
                      color: Color(0xFF822D2D),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Reason: ${entry.reason}'),
            const SizedBox(height: 2),
            Text(
              '${locale.formatMediumDate(local)} · ${locale.formatTimeOfDay(TimeOfDay.fromDateTime(local))}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Batch #${entry.batchId} · Entry #${entry.id}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Tooltip(
              message:
                  'Open this batch to review history or undo a mistaken disposal.',
              child: TextButton.icon(
                onPressed: onOpenBatch,
                icon: const Icon(Icons.history),
                label: const Text('View batch history'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
