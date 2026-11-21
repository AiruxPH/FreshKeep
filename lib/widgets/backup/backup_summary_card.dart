import 'package:flutter/material.dart';

/// Displays local dataset counts and an offline privacy notice on [BackupScreen].
class BackupSummaryCard extends StatelessWidget {
  const BackupSummaryCard({
    super.key,
    required this.totalBatches,
    required this.activeBatches,
    required this.photoCount,
    required this.eventCount,
  });

  final int totalBatches;
  final int activeBatches;
  final int photoCount;
  final int eventCount;

  @override
  Widget build(BuildContext context) {
    final depleted = totalBatches - activeBatches;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.offline_pin_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Current device data',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '$totalBatches ${totalBatches == 1 ? 'batch' : 'batches'} '
              '($activeBatches in stock, $depleted used up) · '
              '$photoCount ${photoCount == 1 ? 'photo' : 'photos'} · '
              '$eventCount stock ${eventCount == 1 ? 'event' : 'events'}',
            ),
            const SizedBox(height: 8),
            Text(
              'Backups stay completely offline as portable JSON files under your control — no cloud account or server is used.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
