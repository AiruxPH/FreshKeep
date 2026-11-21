import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'backup/backup_file_io.dart';
import 'data/inventory_database.dart';
import 'domain/backup/backup_filename.dart';
import 'domain/backup/backup_models.dart';
import 'domain/backup/parse_backup.dart';
import 'domain/backup/serialize_backup.dart';
import 'reminders/reminder_controller.dart';
import 'widgets/backup/backup_summary_card.dart';
import 'widgets/backup/import_preview_dialog.dart';
import 'widgets/backup/paste_backup_dialog.dart';
import 'widgets/toast/show_freshkeep_toast.dart';

/// Offline device-local JSON backup export and restore screen.
class BackupScreen extends StatefulWidget {
  const BackupScreen({
    super.key,
    required this.database,
    this.reminders,
    this.saveFile = saveBackupFileToDevice,
    this.pickFile = pickBackupFileFromDevice,
  });

  final InventoryDatabase database;
  final ReminderController? reminders;
  final SaveBackupFile saveFile;
  final PickBackupFile pickFile;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  static const int _maxClipboardBytes = 2 * 1024 * 1024;

  bool _loadingSummary = true;
  bool _busy = false;
  bool _includePhotos = true;
  int _totalBatches = 0;
  int _activeBatches = 0;
  int _photoCount = 0;
  int _eventCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() => _loadingSummary = true);
    try {
      final batches = await widget.database.loadBatches();
      final eventRow = await widget.database
          .customSelect('SELECT COUNT(*) AS count FROM events')
          .getSingle();
      if (!mounted) return;
      setState(() {
        _totalBatches = batches.length;
        _activeBatches = batches.where((b) => !b.depleted).length;
        _photoCount = batches.where((b) => b.draft.photo != null).length;
        _eventCount = eventRow.read<int>('count');
        _loadingSummary = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingSummary = false;
        _error = 'Could not read current device counts.';
      });
    }
  }

  Future<void> _exportFile() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final backup = await widget.database.exportBackup(
        includePhotos: _includePhotos,
      );
      final json = serializeBackup(backup);
      final filename = buildBackupFilename(backup.exportedAt.toLocal());
      final saved = await widget.saveFile(filename, json);
      if (!mounted) return;
      showFreshKeepToast(
        context,
        message: saved
            ? 'Backup saved (${backup.batches.length} ${backup.batches.length == 1 ? 'batch' : 'batches'}).'
            : 'Export cancelled.',
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not export backup. Existing data is unchanged.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyJson() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final backup = await widget.database.exportBackup(
        includePhotos: _includePhotos,
      );
      final json = serializeBackup(backup);
      if (utf8.encode(json).length > _maxClipboardBytes) {
        if (mounted) {
          setState(
            () => _error =
                'Backup exceeds 2 MB because of saved photos. Turn off photos or use Export JSON file.',
          );
        }
        return;
      }
      await Clipboard.setData(ClipboardData(text: json));
      if (!mounted) return;
      showFreshKeepToast(context, message: 'Backup JSON copied to clipboard.');
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not copy backup JSON.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAndImport() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = await widget.pickFile();
      if (!mounted || picked == null) return;
      await _processRawImport(picked.content, sourceName: picked.name);
    } on BackupValidationException catch (error) {
      if (mounted) {
        setState(
          () => _error = '${error.message} Existing data was not changed.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not read the selected file. Existing data was not changed.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pasteAndImport() async {
    if (_busy) return;
    final pasted = await showPasteBackupDialog(context);
    if (!mounted || pasted == null || pasted.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _processRawImport(pasted, sourceName: 'Pasted JSON');
    } on BackupValidationException catch (error) {
      if (mounted) {
        setState(
          () => _error = '${error.message} Existing data was not changed.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not import pasted JSON. Existing data was not changed.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _processRawImport(
    String rawJson, {
    required String sourceName,
  }) async {
    final backup = parseBackup(rawJson);
    if (!mounted) return;
    final mode = await showImportPreviewDialog(
      context,
      backup: backup,
      sourceName: sourceName,
    );
    if (!mounted || mode == null) return;
    final summary = await widget.database.importBackup(backup, mode: mode);
    await widget.reminders?.refresh();
    await _loadSummary();
    if (!mounted) return;
    showFreshKeepToast(
      context,
      message:
          'Imported ${summary.batchesImported} ${summary.batchesImported == 1 ? 'batch' : 'batches'} '
          '(${summary.mode == BackupImportMode.replace ? 'replaced' : 'merged'}).',
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Backup & restore')),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Text(
              'Local JSON backup',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            const Text(
              'Save your batches, histories, guidance links, photos, and reminder settings as a local JSON file, or restore a backup onto this device.',
            ),
            const SizedBox(height: 16),
            if (_loadingSummary)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              BackupSummaryCard(
                totalBatches: _totalBatches,
                activeBatches: _activeBatches,
                photoCount: _photoCount,
                eventCount: _eventCount,
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Export backup',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Include food photos in backup'),
                      subtitle: const Text(
                        'Turning this off produces a smaller text-only JSON file.',
                      ),
                      value: _includePhotos,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _includePhotos = v),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          key: const ValueKey('export-backup-file'),
                          onPressed: _busy ? null : _exportFile,
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('Export JSON file'),
                        ),
                        OutlinedButton.icon(
                          key: const ValueKey('copy-backup-json'),
                          onPressed: _busy ? null : _copyJson,
                          icon: const Icon(Icons.copy_all_outlined),
                          label: const Text('Copy JSON'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Import backup',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Every backup is validated and previewed before changing anything. You can merge into existing records or replace everything on this device.',
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          key: const ValueKey('import-backup-file'),
                          onPressed: _busy ? null : _pickAndImport,
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('Import JSON file'),
                        ),
                        OutlinedButton.icon(
                          key: const ValueKey('paste-backup-json'),
                          onPressed: _busy ? null : _pasteAndImport,
                          icon: const Icon(Icons.content_paste_outlined),
                          label: const Text('Paste JSON'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    ),
  );
}
