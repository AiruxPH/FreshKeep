import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/guidance_catalog.dart';
import 'domain/storage_guidance.dart';

class GuidanceScreen extends StatefulWidget {
  const GuidanceScreen({super.key, this.foodName = '', this.storage});
  final String foodName;
  final String? storage;
  @override
  State<GuidanceScreen> createState() => _GuidanceScreenState();
}

class _GuidanceScreenState extends State<GuidanceScreen> {
  late final TextEditingController _search;
  String? _storage;
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Source citation copied.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not copy. You can select the source link below.',
            ),
          ),
        );
      }
    }
  }

  Widget _rule(StorageGuidance rule) => Card(
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
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Source details'),
            children: [
              Text(rule.sourceLocation),
              Text('Reviewed ${StorageGuidance.reviewedOn}'),
              SelectableText(
                rule.sourceUrl,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
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

  @override
  Widget build(BuildContext context) {
    final rules = searchGuidance(_search.text, storage: _storage);
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
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Reference only · No suggested date is set. The starting event and its date have not been recorded. Your printed dates and inventory stay unchanged.',
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
