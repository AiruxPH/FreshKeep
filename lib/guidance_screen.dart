import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/guidance_catalog.dart';
import 'data/inventory_database.dart';
import 'domain/batch.dart';
import 'domain/stock_event.dart';
import 'domain/storage_guidance.dart';
import 'widgets/guidance/apply_guidance_sheet.dart';
import 'widgets/toast/show_freshkeep_toast.dart';

class GuidanceScreen extends StatefulWidget {
  const GuidanceScreen({
    super.key,
    this.foodName = '',
    this.storage,
    this.database,
    this.batch,
  });
  final String foodName;
  final String? storage;
  final InventoryDatabase? database;
  final InventoryBatch? batch;
  @override
  State<GuidanceScreen> createState() => _GuidanceScreenState();
}

class _GuidanceScreenState extends State<GuidanceScreen> {
  late final TextEditingController _search;
  String? _storage;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.foodName);
    _storage = widget.storage;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _copySource(StorageGuidance rule) async {
    try {
      await Clipboard.setData(
        ClipboardData(
          text:
              '${rule.sourceTitle}\n${rule.sourceLocation}\n${rule.sourceUrl}\nReviewed ${StorageGuidance.reviewedOn}',
        ),
      );
      if (mounted) {
        showFreshKeepToast(context, message: 'Source citation copied.');
      }
    } catch (_) {
      if (mounted) {
        showFreshKeepToast(
          context,
          message: 'Could not copy. You can select the source link below.',
        );
      }
    }
  }

  Future<void> _applyRule(StorageGuidance rule) async {
    final batch = widget.batch;
    final database = widget.database;
    if (_saving || batch == null || database == null) return;
    final currentGuidance = batch.draft.guidance;
    final selection = await showApplyGuidanceSheet(
      context,
      rule: rule,
      initial: currentGuidance != null && currentGuidance.ruleId == rule.id
          ? currentGuidance
          : null,
    );
    if (selection == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await database.editBatchDetails(
        batch.id,
        BatchDetailsDraft(
          name: batch.draft.name,
          storage: batch.draft.storage,
          category: batch.draft.category,
          printedDate: batch.draft.printedDate,
          printedTime: batch.draft.printedTime,
        ),
        expected: batch.draft,
        updateGuidance: true,
        guidance: selection,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        showFreshKeepToast(
          context,
          message: error is StockValidationException
              ? error.message
              : 'Could not save suggested date. Please try again.',
        );
      }
    }
  }

  Future<void> _clearGuidance() async {
    final batch = widget.batch;
    final database = widget.database;
    if (_saving || batch == null || database == null) return;
    setState(() => _saving = true);
    try {
      await database.editBatchDetails(
        batch.id,
        BatchDetailsDraft(
          name: batch.draft.name,
          storage: batch.draft.storage,
          category: batch.draft.category,
          printedDate: batch.draft.printedDate,
          printedTime: batch.draft.printedTime,
        ),
        expected: batch.draft,
        updateGuidance: true,
        guidance: null,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        showFreshKeepToast(
          context,
          message: error is StockValidationException
              ? error.message
              : 'Could not clear suggested date. Please try again.',
        );
      }
    }
  }

  Widget _rule(StorageGuidance rule) {
    final batch = widget.batch;
    final canSelect = batch != null && widget.database != null;
    final matchesStorage = batch == null || rule.storage == batch.draft.storage;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rule.food, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '${rule.storage} · ${rule.duration}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('Applies to: ${rule.condition}'),
            const SizedBox(height: 12),
            Text('Source: ${rule.sourceTitle}'),
            if (canSelect)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: matchesStorage
                    ? FilledButton.tonalIcon(
                        onPressed: _saving ? null : () => _applyRule(rule),
                        icon: const Icon(Icons.event_available_outlined),
                        label: const Text('Use to calculate suggested date'),
                      )
                    : Text(
                        'Matches ${rule.storage}, not this batch’s ${batch.draft.storage} storage.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
              ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Source details'),
              children: [
                Text(rule.sourceLocation),
                Text('Reviewed ${StorageGuidance.reviewedOn}'),
                SelectableText(
                  rule.sourceUrl,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _copySource(rule),
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy citation'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rules = searchGuidance(_search.text, storage: _storage);
    final activeGuidance = widget.batch?.draft.guidance;
    return Scaffold(
      appBar: AppBar(title: const Text('Storage guidance')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Storage references for 16 foods',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Match the food, condition and storage before using a reference. These durations do not guarantee freshness or replace packaging instructions.',
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: activeGuidance == null
                      ? const Text(
                          'Reference only · No suggested date is set. Confirm a matching rule and starting date to calculate one, or browse without changing your inventory.',
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Suggested date set: ${activeGuidance.suggestedDate} (${activeGuidance.anchorEvent} ${activeGuidance.anchorDate}). Printed dates still take priority.',
                            ),
                            if (widget.database != null)
                              TextButton(
                                onPressed: _saving ? null : _clearGuidance,
                                child: const Text('Clear suggested date'),
                              ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Search food or condition',
                  hintText: 'e.g. eggs, cooked rice, mango',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _search.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.clear),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final location in [null, 'Pantry', 'Fridge', 'Freezer'])
                    ChoiceChip(
                      label: Text(location ?? 'All storage'),
                      selected: _storage == location,
                      onSelected: (_) => setState(() => _storage = location),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('${rules.length} matching references'),
              if (rules.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No verified reference matches this food and storage. No estimate is provided. Try another search or All storage; do not assume a different condition applies.',
                    ),
                  ),
                ),
              ...rules.map(_rule),
              const SizedBox(height: 16),
              const Text(
                'FoodKeeper references use a published 2018 Wyoming Department of Health chart; the original FoodKeeper data download was unavailable during review. Mango guidance uses the National Mango Board. This catalog is bundled for offline reading; source websites need internet.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
