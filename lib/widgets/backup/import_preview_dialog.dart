import 'package:flutter/material.dart';

import '../../domain/backup/backup_models.dart';

/// Shows parsed backup metadata and lets the user pick Merge vs Replace before
/// mutating local SQLite records. Returns `null` if cancelled.
Future<BackupImportMode?> showImportPreviewDialog(
  BuildContext context, {
  required FreshKeepBackup backup,
  required String sourceName,
}) {
  return showDialog<BackupImportMode>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _ImportPreviewDialog(backup: backup, sourceName: sourceName),
  );
}

class _ImportPreviewDialog extends StatefulWidget {
  const _ImportPreviewDialog({required this.backup, required this.sourceName});

  final FreshKeepBackup backup;
  final String sourceName;

  @override
  State<_ImportPreviewDialog> createState() => _ImportPreviewDialogState();
}

class _ImportPreviewDialogState extends State<_ImportPreviewDialog> {
  BackupImportMode _mode = BackupImportMode.merge;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final localExport = widget.backup.exportedAt.toLocal();
    final dateText = localizations.formatMediumDate(localExport);
    final timeText = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(localExport),
    );
    final b = widget.backup;

    return AlertDialog(
      title: const Text('Review backup before import'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Source: ${widget.sourceName}'),
              Text('Exported: $dateText · $timeText'),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${b.batches.length} ${b.batches.length == 1 ? 'batch' : 'batches'} · '
                        '${b.photoCount} ${b.photoCount == 1 ? 'photo' : 'photos'}',
                      ),
                      Text(
                        '${b.events.length} stock ${b.events.length == 1 ? 'event' : 'events'} · '
                        '${b.batchEdits.length} detail ${b.batchEdits.length == 1 ? 'edit' : 'edits'}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Choose how to import',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              _ModeOptionCard(
                key: const ValueKey('import-mode-merge'),
                title: 'Merge into current data',
                subtitle:
                    'Adds imported batches, photos, and histories alongside your current records and reminder settings.',
                selected: _mode == BackupImportMode.merge,
                onTap: () => setState(() => _mode = BackupImportMode.merge),
              ),
              const SizedBox(height: 8),
              _ModeOptionCard(
                key: const ValueKey('import-mode-replace'),
                title: 'Replace all device data',
                subtitle:
                    'Clears current inventory, photos, histories, and reminder settings on this device and restores this backup.',
                selected: _mode == BackupImportMode.replace,
                isDestructive: true,
                onTap: () => setState(() => _mode = BackupImportMode.replace),
              ),
              if (_mode == BackupImportMode.replace)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'Warning: Replacing device data overwrites existing records on this device cleanly in one transaction.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('confirm-backup-import'),
          onPressed: () => Navigator.pop(context, _mode),
          child: Text(
            _mode == BackupImportMode.replace
                ? 'Replace and restore'
                : 'Merge backup',
          ),
        ),
      ],
    );
  }
}

class _ModeOptionCard extends StatelessWidget {
  const _ModeOptionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.isDestructive = false,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = selected
        ? (isDestructive ? scheme.error : scheme.primary)
        : scheme.outlineVariant;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected
                    ? (isDestructive ? scheme.error : scheme.primary)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
