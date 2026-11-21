import 'package:flutter/material.dart';

import '../../domain/guidance/find_guidance_rule.dart';
import '../../domain/guidance/guidance_selection.dart';
import '../../domain/storage_guidance.dart';

/// Displays an attached calculated storage-guidance rule, anchor event/date,
/// source citation, and actions to change or clear the suggested date.
class BatchGuidanceCard extends StatelessWidget {
  const BatchGuidanceCard({
    super.key,
    required this.guidance,
    required this.hasPrintedDate,
    required this.onChange,
    required this.onClear,
  });

  final BatchGuidance guidance;
  final bool hasPrintedDate;
  final VoidCallback onChange;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final rule = findGuidanceRule(guidance.ruleId);
    final windowLabel = guidance.hasRange
        ? '${guidance.suggestedDate} to ${guidance.suggestedEndDate}'
        : guidance.suggestedDate;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Suggested storage guidance',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              rule == null
                  ? 'Rule ${guidance.ruleId} (catalog ${guidance.catalogVersion})'
                  : '${rule.food} · ${rule.condition}',
            ),
            Text('Based on: ${guidance.anchorEvent} on ${guidance.anchorDate}'),
            Text(
              'Suggested date: $windowLabel',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (rule != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Source: ${rule.sourceTitle} · ${rule.sourceLocation} · Reviewed ${StorageGuidance.reviewedOn}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (hasPrintedDate)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Printed date takes priority for status and reminders.',
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: onChange,
                  child: const Text('Change guidance'),
                ),
                TextButton(
                  onPressed: onClear,
                  child: const Text('Clear suggested date'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
