import 'package:flutter/material.dart';

import '../../domain/batch.dart';
import '../../domain/ocr/ocr_models.dart';

/// Lets the user inspect extracted printed-date findings, resolve ambiguity
/// explicitly, choose a date manually, or leave the date unknown.
class OcrDateReviewCard extends StatelessWidget {
  const OcrDateReviewCard({
    super.key,
    required this.dateResult,
    required this.selectedDate,
    required this.onDateChanged,
    this.enabled = true,
  });

  final OcrDateParseResult dateResult;
  final String? selectedDate;
  final ValueChanged<String?> onDateChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Printed expiration date',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              selectedDate == null
                  ? 'Date unknown'
                  : 'Selected date: $selectedDate',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (dateResult.rawMatch != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Matched text: "${dateResult.rawMatch}"',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (dateResult.warning != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  dateResult.warning!,
                  style: TextStyle(color: scheme.error),
                ),
              ),
            if (dateResult.ambiguousCandidates.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Confirm matching date:',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final candidate in dateResult.ambiguousCandidates)
                    ChoiceChip(
                      key: ValueKey('ocr-candidate-${candidate.isoDate}'),
                      label: Text(candidate.label),
                      selected: selectedDate == candidate.isoDate,
                      onSelected: !enabled
                          ? null
                          : (isSelected) => onDateChanged(
                              isSelected ? candidate.isoDate : null,
                            ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: !enabled
                      ? null
                      : () async {
                          final initial = selectedDate == null
                              ? DateTime.now()
                              : (DateTime.tryParse(selectedDate!) ??
                                    DateTime.now());
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: initial,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100, 12, 31),
                          );
                          if (picked != null) {
                            onDateChanged(BatchDraft.dateOnly(picked));
                          }
                        },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                    selectedDate == null ? 'Pick printed date' : 'Change date',
                  ),
                ),
                if (selectedDate != null)
                  TextButton(
                    onPressed: !enabled ? null : () => onDateChanged(null),
                    child: const Text('Clear date'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Missing or unreadable dates stay unknown. FreshKeep never infers expiration dates from food appearance.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
