import 'package:flutter/material.dart';

import '../../domain/batch.dart';
import '../../domain/guidance/calculate_suggested_dates.dart';
import '../../domain/guidance/guidance_selection.dart';
import '../../domain/storage_guidance.dart';

/// Prompts the user to confirm the starting event and date before calculating
/// a suggested review date from a cited [StorageGuidance] rule.
Future<BatchGuidance?> showApplyGuidanceSheet(
  BuildContext context, {
  required StorageGuidance rule,
  BatchGuidance? initial,
}) {
  return showModalBottomSheet<BatchGuidance>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ApplyGuidanceContent(rule: rule, initial: initial),
  );
}

class _ApplyGuidanceContent extends StatefulWidget {
  const _ApplyGuidanceContent({required this.rule, this.initial});
  final StorageGuidance rule;
  final BatchGuidance? initial;

  @override
  State<_ApplyGuidanceContent> createState() => _ApplyGuidanceContentState();
}

class _ApplyGuidanceContentState extends State<_ApplyGuidanceContent> {
  late String _anchorEvent;
  DateTime? _anchorDate;

  @override
  void initState() {
    super.initState();
    _anchorEvent =
        widget.initial != null &&
            StorageGuidance.anchorEvents.contains(widget.initial!.anchorEvent)
        ? widget.initial!.anchorEvent
        : widget.rule.defaultAnchorEvent;
    _anchorDate = widget.initial == null
        ? null
        : DateTime.tryParse(widget.initial!.anchorDate);
  }

  @override
  Widget build(BuildContext context) {
    final anchorIso = _anchorDate == null
        ? null
        : BatchDraft.dateOnly(_anchorDate!);
    final preview = anchorIso == null
        ? null
        : calculateSuggestedDates(widget.rule, anchorIso);

    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Calculate suggested date',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.rule.food} · ${widget.rule.storage} · ${widget.rule.duration}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text('Applies to: ${widget.rule.condition}'),
              Text(
                'Source: ${widget.rule.sourceTitle} (${widget.rule.sourceLocation})',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _anchorEvent,
                decoration: const InputDecoration(labelText: 'Starting event'),
                items: StorageGuidance.anchorEvents
                    .map(
                      (event) =>
                          DropdownMenuItem(value: event, child: Text(event)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _anchorEvent = value!),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final maxDate =
                      _anchorDate != null && _anchorDate!.isAfter(today)
                      ? _anchorDate!
                      : today;
                  final initial =
                      _anchorDate != null && _anchorDate!.isAfter(maxDate)
                      ? maxDate
                      : (_anchorDate ?? today);
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: DateTime(2000),
                    lastDate: maxDate,
                  );
                  if (picked != null && mounted) {
                    setState(() => _anchorDate = picked);
                  }
                },
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  anchorIso == null
                      ? 'Select starting date'
                      : 'Starting date · $anchorIso',
                ),
              ),
              const SizedBox(height: 12),
              if (preview != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Suggested review date: ${preview.earliest}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (preview.earliest != preview.latest)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Source window: ${preview.earliest} to ${preview.latest} (${widget.rule.duration})',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              Text(
                'Calculated from your confirmed starting date and ${widget.rule.sourceTitle}. Never replaces a printed packaging date or guarantees freshness.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: anchorIso == null
                          ? null
                          : () => Navigator.pop(
                              context,
                              BatchGuidance.fromRule(
                                rule: widget.rule,
                                anchorEvent: _anchorEvent,
                                anchorDate: anchorIso,
                              ),
                            ),
                      child: const Text('Save suggested date'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
