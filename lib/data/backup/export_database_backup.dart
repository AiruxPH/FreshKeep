import 'dart:convert';
import 'dart:typed_data';

import '../../domain/backup/backup_models.dart';
import '../../domain/food_category.dart';
import '../../domain/guidance/guidance_selection.dart';
import '../../domain/quantity/quantity_math.dart';
import '../inventory_database.dart';

/// Reads all FreshKeep tables inside one consistent database transaction.
Future<FreshKeepBackup> exportDatabaseBackup(
  InventoryDatabase db, {
  bool includePhotos = true,
  DateTime? now,
}) => db.transaction(() async {
  final batchRows = await db
      .customSelect('SELECT * FROM batches ORDER BY id ASC')
      .get();

  final photoByBatchId = <int, String>{};
  if (includePhotos) {
    final photoRows = await db
        .customSelect(
          'SELECT batch_id, bytes FROM batch_photos ORDER BY batch_id ASC',
        )
        .get();
    for (final row in photoRows) {
      final batchId = row.read<int>('batch_id');
      final bytes = row.read<Uint8List>('bytes');
      photoByBatchId[batchId] = base64Encode(bytes);
    }
  }

  final batches = [
    for (final row in batchRows)
      BackupBatchRecord(
        id: row.read<int>('id'),
        name: row.read<String>('name'),
        startingQty: normalizeQuantity(row.read<double>('starting_qty')),
        unit: row.read<String>('unit'),
        storage: row.read<String>('storage'),
        category: row.readNullable<String>('category') ??
            FoodCategory.defaultCategory,
        printedDate: row.readNullable<String>('printed_date'),
        printedTime: row.readNullable<String>('printed_time'),
        guidance: _readGuidance(row),
        createdAt: row.read<String>('created_at'),
        photoBase64: includePhotos ? photoByBatchId[row.read<int>('id')] : null,
      ),
  ];

  final eventRows = await db
      .customSelect(
        'SELECT id, batch_id, type, delta, reason, created_at, reverses_id '
        'FROM events ORDER BY id ASC',
      )
      .get();
  final events = [
    for (final row in eventRows)
      BackupEventRecord(
        id: row.read<int>('id'),
        batchId: row.read<int>('batch_id'),
        type: row.read<String>('type'),
        delta: normalizeQuantity(row.read<double>('delta')),
        reason: row.readNullable<String>('reason'),
        createdAt: row.read<String>('created_at'),
        reversesId: row.readNullable<int>('reverses_id'),
      ),
  ];

  final editRows = await db
      .customSelect(
        'SELECT id, batch_id, old_name, new_name, old_storage, new_storage, '
        'old_category, new_category, old_date, new_date, created_at, '
        'photo_change, guidance_change '
        'FROM batch_edits ORDER BY id ASC',
      )
      .get();
  final edits = [
    for (final row in editRows)
      BackupBatchEditRecord(
        id: row.read<int>('id'),
        batchId: row.read<int>('batch_id'),
        oldName: row.read<String>('old_name'),
        newName: row.read<String>('new_name'),
        oldStorage: row.read<String>('old_storage'),
        newStorage: row.read<String>('new_storage'),
        oldCategory: row.readNullable<String>('old_category') ??
            FoodCategory.defaultCategory,
        newCategory: row.readNullable<String>('new_category') ??
            FoodCategory.defaultCategory,
        oldDate: row.readNullable<String>('old_date'),
        newDate: row.readNullable<String>('new_date'),
        createdAt: row.read<String>('created_at'),
        photoChange: row.readNullable<String>('photo_change'),
        guidanceChange: row.readNullable<String>('guidance_change'),
      ),
  ];

  final reminderSettings = await db.loadReminderSettings();

  final prefRows = await db
      .customSelect('SELECT key, value FROM app_preferences ORDER BY key ASC')
      .get();
  final prefs = <String, String>{
    for (final row in prefRows) row.read<String>('key'): row.read<String>('value'),
  };

  return FreshKeepBackup(
    exportedAt: (now ?? DateTime.now()).toUtc(),
    includesPhotos: includePhotos,
    batches: batches,
    events: events,
    batchEdits: edits,
    reminderSettings: reminderSettings,
    appPreferences: prefs,
  );
});

BatchGuidance? _readGuidance(dynamic row) {
  final ruleId = row.readNullable<String>('guidance_rule_id');
  final anchorDate = row.readNullable<String>('guidance_anchor_date');
  final suggestedDate = row.readNullable<String>('suggested_date');
  if (ruleId == null || anchorDate == null || suggestedDate == null) {
    return null;
  }
  return BatchGuidance.stored(
    ruleId: ruleId,
    catalogVersion:
        row.readNullable<String>('guidance_catalog_version') ?? 'unknown',
    anchorEvent: row.readNullable<String>('guidance_anchor_event') ?? 'Stored',
    anchorDate: anchorDate,
    suggestedDate: suggestedDate,
  );
}
