import 'dart:convert';

import '../../domain/backup/backup_models.dart';
import '../../domain/backup/validate_backup.dart';
import '../inventory_database.dart';

/// Atomically imports a validated [FreshKeepBackup] using [mode].
///
/// Validates before mutating anything and rolls back the entire transaction on
/// any SQL or data failure. Preserves append-only triggers on `events` and
/// `batch_edits`.
Future<BackupImportSummary> importDatabaseBackup(
  InventoryDatabase db,
  FreshKeepBackup backup, {
  required BackupImportMode mode,
}) async {
  validateBackup(backup);

  return db.transaction(() async {
    if (mode == BackupImportMode.replace) {
      return _replaceDatabase(db, backup);
    }
    return _mergeIntoDatabase(db, backup);
  });
}

Future<BackupImportSummary> _mergeIntoDatabase(
  InventoryDatabase db,
  FreshKeepBackup backup,
) async {
  final batches = List<BackupBatchRecord>.of(backup.batches)
    ..sort((a, b) => a.id.compareTo(b.id));
  final batchIdMap = <int, int>{};
  var photosImported = 0;

  for (final batch in batches) {
    await db.customStatement(
      '''INSERT INTO batches (
        name, starting_qty, unit, storage, category, printed_date, date_source,
        printed_time, guidance_rule_id, guidance_catalog_version,
        guidance_anchor_event, guidance_anchor_date, suggested_date, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        batch.name.trim(),
        batch.startingQty,
        batch.unit,
        batch.storage,
        batch.category,
        batch.printedDate,
        batch.printedDate == null ? 'unknown' : 'printed',
        batch.printedTime,
        batch.guidance?.ruleId,
        batch.guidance?.catalogVersion,
        batch.guidance?.anchorEvent,
        batch.guidance?.anchorDate,
        batch.guidance?.suggestedDate,
        batch.createdAt,
      ],
    );
    final newBatchId = (await db
            .customSelect('SELECT last_insert_rowid() AS id')
            .getSingle())
        .read<int>('id');
    batchIdMap[batch.id] = newBatchId;

    if (batch.photoBase64 != null) {
      final bytes = base64Decode(batch.photoBase64!);
      await db.customStatement(
        'INSERT INTO batch_photos (batch_id, bytes) VALUES (?, ?)',
        [newBatchId, bytes],
      );
      photosImported++;
    }
  }

  final nonReverseEvents =
      backup.events.where((e) => e.type != 'reverse').toList()
        ..sort((a, b) => a.id.compareTo(b.id));
  final reverseEvents = backup.events.where((e) => e.type == 'reverse').toList()
    ..sort((a, b) => a.id.compareTo(b.id));

  final eventIdMap = <int, int>{};
  for (final event in nonReverseEvents) {
    final mappedBatchId = batchIdMap[event.batchId]!;
    await db.customStatement(
      '''INSERT INTO events (batch_id, type, delta, reason, created_at, reverses_id)
         VALUES (?, ?, ?, ?, ?, NULL)''',
      [
        mappedBatchId,
        event.type,
        event.delta,
        event.reason,
        event.createdAt,
      ],
    );
    final newEventId = (await db
            .customSelect('SELECT last_insert_rowid() AS id')
            .getSingle())
        .read<int>('id');
    eventIdMap[event.id] = newEventId;
  }

  for (final event in reverseEvents) {
    final mappedBatchId = batchIdMap[event.batchId]!;
    final mappedTargetId = eventIdMap[event.reversesId!]!;
    await db.customStatement(
      '''INSERT INTO events (batch_id, type, delta, reason, created_at, reverses_id)
         VALUES (?, 'reverse', ?, ?, ?, ?)''',
      [
        mappedBatchId,
        event.delta,
        event.reason,
        event.createdAt,
        mappedTargetId,
      ],
    );
  }

  final edits = List<BackupBatchEditRecord>.of(backup.batchEdits)
    ..sort((a, b) => a.id.compareTo(b.id));
  for (final edit in edits) {
    final mappedBatchId = batchIdMap[edit.batchId]!;
    await db.customStatement(
      '''INSERT INTO batch_edits (
        batch_id, old_name, new_name, old_storage, new_storage,
        old_category, new_category, old_date, new_date, created_at,
        photo_change, guidance_change
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        mappedBatchId,
        edit.oldName.trim(),
        edit.newName.trim(),
        edit.oldStorage,
        edit.newStorage,
        edit.oldCategory,
        edit.newCategory,
        edit.oldDate,
        edit.newDate,
        edit.createdAt,
        edit.photoChange,
        edit.guidanceChange,
      ],
    );
  }

  return BackupImportSummary(
    batchesImported: batches.length,
    eventsImported: nonReverseEvents.length + reverseEvents.length,
    editsImported: edits.length,
    photosImported: photosImported,
    mode: BackupImportMode.merge,
  );
}

Future<BackupImportSummary> _replaceDatabase(
  InventoryDatabase db,
  FreshKeepBackup backup,
) async {
  final existingOnboarding = await db.hasCompletedOnboarding();

  await db.customStatement('DROP TRIGGER IF EXISTS events_no_delete');
  await db.customStatement('DROP TRIGGER IF EXISTS events_no_update');
  await db.customStatement('DROP TRIGGER IF EXISTS batch_edits_no_delete');
  await db.customStatement('DROP TRIGGER IF EXISTS batch_edits_no_update');

  // Respect foreign keys & events.reverses_id self-reference when clearing.
  await db.customStatement('DELETE FROM batch_photos');
  await db.customStatement('DELETE FROM batch_edits');
  await db.customStatement("DELETE FROM events WHERE type = 'reverse'");
  await db.customStatement('DELETE FROM events');
  await db.customStatement('DELETE FROM batches');
  await db.customStatement('DELETE FROM reminder_settings');
  await db.customStatement('DELETE FROM app_preferences');

  await _recreateAppendOnlyTriggers(db);

  final batches = List<BackupBatchRecord>.of(backup.batches)
    ..sort((a, b) => a.id.compareTo(b.id));
  var photosImported = 0;

  for (final batch in batches) {
    await db.customStatement(
      '''INSERT INTO batches (
        id, name, starting_qty, unit, storage, category, printed_date,
        date_source, printed_time, guidance_rule_id, guidance_catalog_version,
        guidance_anchor_event, guidance_anchor_date, suggested_date, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        batch.id,
        batch.name.trim(),
        batch.startingQty,
        batch.unit,
        batch.storage,
        batch.category,
        batch.printedDate,
        batch.printedDate == null ? 'unknown' : 'printed',
        batch.printedTime,
        batch.guidance?.ruleId,
        batch.guidance?.catalogVersion,
        batch.guidance?.anchorEvent,
        batch.guidance?.anchorDate,
        batch.guidance?.suggestedDate,
        batch.createdAt,
      ],
    );

    if (batch.photoBase64 != null) {
      final bytes = base64Decode(batch.photoBase64!);
      await db.customStatement(
        'INSERT INTO batch_photos (batch_id, bytes) VALUES (?, ?)',
        [batch.id, bytes],
      );
      photosImported++;
    }
  }

  final nonReverseEvents =
      backup.events.where((e) => e.type != 'reverse').toList()
        ..sort((a, b) => a.id.compareTo(b.id));
  final reverseEvents = backup.events.where((e) => e.type == 'reverse').toList()
    ..sort((a, b) => a.id.compareTo(b.id));

  for (final event in nonReverseEvents) {
    await db.customStatement(
      '''INSERT INTO events (id, batch_id, type, delta, reason, created_at, reverses_id)
         VALUES (?, ?, ?, ?, ?, ?, NULL)''',
      [
        event.id,
        event.batchId,
        event.type,
        event.delta,
        event.reason,
        event.createdAt,
      ],
    );
  }

  for (final event in reverseEvents) {
    await db.customStatement(
      '''INSERT INTO events (id, batch_id, type, delta, reason, created_at, reverses_id)
         VALUES (?, ?, 'reverse', ?, ?, ?, ?)''',
      [
        event.id,
        event.batchId,
        event.delta,
        event.reason,
        event.createdAt,
        event.reversesId,
      ],
    );
  }

  final edits = List<BackupBatchEditRecord>.of(backup.batchEdits)
    ..sort((a, b) => a.id.compareTo(b.id));
  for (final edit in edits) {
    await db.customStatement(
      '''INSERT INTO batch_edits (
        id, batch_id, old_name, new_name, old_storage, new_storage,
        old_category, new_category, old_date, new_date, created_at,
        photo_change, guidance_change
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        edit.id,
        edit.batchId,
        edit.oldName.trim(),
        edit.newName.trim(),
        edit.oldStorage,
        edit.newStorage,
        edit.oldCategory,
        edit.newCategory,
        edit.oldDate,
        edit.newDate,
        edit.createdAt,
        edit.photoChange,
        edit.guidanceChange,
      ],
    );
  }

  await db.saveReminderSettings(backup.reminderSettings);

  for (final entry in backup.appPreferences.entries) {
    await db.customStatement(
      'INSERT OR REPLACE INTO app_preferences (key, value) VALUES (?, ?)',
      [entry.key, entry.value],
    );
  }
  if (existingOnboarding) {
    await db.markOnboardingCompleted();
  }

  return BackupImportSummary(
    batchesImported: batches.length,
    eventsImported: nonReverseEvents.length + reverseEvents.length,
    editsImported: edits.length,
    photosImported: photosImported,
    mode: BackupImportMode.replace,
  );
}

Future<void> _recreateAppendOnlyTriggers(InventoryDatabase db) async {
  await db.customStatement(
    "CREATE TRIGGER events_no_update BEFORE UPDATE ON events BEGIN SELECT RAISE(ABORT, 'Events are append-only'); END",
  );
  await db.customStatement(
    "CREATE TRIGGER events_no_delete BEFORE DELETE ON events BEGIN SELECT RAISE(ABORT, 'Events are append-only'); END",
  );
  await db.customStatement(
    "CREATE TRIGGER batch_edits_no_update BEFORE UPDATE ON batch_edits BEGIN SELECT RAISE(ABORT,'Details history is append-only'); END",
  );
  await db.customStatement(
    "CREATE TRIGGER batch_edits_no_delete BEFORE DELETE ON batch_edits BEGIN SELECT RAISE(ABORT,'Details history is append-only'); END",
  );
}
