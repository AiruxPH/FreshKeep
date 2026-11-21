import 'dart:convert';

import '../batch.dart';
import '../food_photo.dart';
import 'backup_models.dart';

/// Validates structural integrity, stock conservation, reversals, photos, and
/// audit rows for [backup] before any database mutation runs.
void validateBackup(FreshKeepBackup backup) {
  if (backup.formatVersion != FreshKeepBackup.currentFormatVersion) {
    throw BackupValidationException(
      'Unsupported backup format version (${backup.formatVersion}).',
    );
  }
  if (backup.dbSchemaVersion < 1) {
    throw BackupValidationException(
      'Invalid database schema version (${backup.dbSchemaVersion}).',
    );
  }

  final batchIds = <int>{};
  final batchById = <int, BackupBatchRecord>{};
  for (final batch in backup.batches) {
    if (batch.id < 1 || !batchIds.add(batch.id)) {
      throw BackupValidationException(
        'Backup contains an invalid or duplicate batch ID (#${batch.id}).',
      );
    }
    try {
      BatchDraft(
        name: batch.name,
        quantity: batch.startingQty,
        unit: batch.unit,
        storage: batch.storage,
        printedDate: batch.printedDate,
        printedTime: batch.printedTime,
        guidance: batch.guidance,
      );
    } on ArgumentError catch (error) {
      throw BackupValidationException(
        'Invalid batch #${batch.id} ("${batch.name}"): ${error.message}',
      );
    }
    if (DateTime.tryParse(batch.createdAt) == null) {
      throw BackupValidationException(
        'Batch #${batch.id} has an invalid creation timestamp.',
      );
    }
    if (batch.photoBase64 != null) {
      try {
        final bytes = base64Decode(batch.photoBase64!);
        FoodPhoto(bytes);
      } on FormatException catch (error) {
        throw BackupValidationException(
          'Invalid photo in batch #${batch.id}: ${error.message}',
        );
      }
    }
    batchById[batch.id] = batch;
  }

  final eventIds = <int>{};
  final eventsById = <int, BackupEventRecord>{};
  final deltaSumByBatch = <int, int>{};
  const validEventTypes = {'consume', 'dispose', 'correct', 'reverse'};

  for (final event in backup.events) {
    if (event.id < 1 || !eventIds.add(event.id)) {
      throw BackupValidationException(
        'Backup contains an invalid or duplicate event ID (#${event.id}).',
      );
    }
    if (!batchIds.contains(event.batchId)) {
      throw BackupValidationException(
        'Event #${event.id} references missing batch #${event.batchId}.',
      );
    }
    if (!validEventTypes.contains(event.type)) {
      throw BackupValidationException(
        'Event #${event.id} has unsupported type "${event.type}".',
      );
    }
    if (event.delta == 0) {
      throw BackupValidationException(
        'Event #${event.id} cannot have a zero quantity change.',
      );
    }
    if ((event.type == 'consume' || event.type == 'dispose') &&
        event.delta >= 0) {
      throw BackupValidationException(
        'Event #${event.id} (${event.type}) must decrease stock.',
      );
    }
    if (event.reason != null && event.reason!.length > 200) {
      throw BackupValidationException(
        'Event #${event.id} has a reason exceeding 200 characters.',
      );
    }
    if (DateTime.tryParse(event.createdAt) == null) {
      throw BackupValidationException(
        'Event #${event.id} has an invalid timestamp.',
      );
    }
    if (event.type == 'reverse' && event.reversesId == null) {
      throw BackupValidationException(
        'Reversal event #${event.id} is missing reversesId.',
      );
    }
    if (event.type != 'reverse' && event.reversesId != null) {
      throw BackupValidationException(
        'Non-reversal event #${event.id} cannot set reversesId.',
      );
    }
    eventsById[event.id] = event;
    deltaSumByBatch[event.batchId] =
        (deltaSumByBatch[event.batchId] ?? 0) + event.delta;
  }

  final seenReversedIds = <int>{};
  for (final event in backup.events) {
    if (event.type != 'reverse') continue;
    final targetId = event.reversesId!;
    final target = eventsById[targetId];
    if (target == null) {
      throw BackupValidationException(
        'Reversal event #${event.id} references missing event #$targetId.',
      );
    }
    if (target.type == 'reverse') {
      throw BackupValidationException(
        'Reversal event #${event.id} cannot reverse another reversal.',
      );
    }
    if (target.batchId != event.batchId) {
      throw BackupValidationException(
        'Reversal event #${event.id} belongs to a different batch than #$targetId.',
      );
    }
    if (!seenReversedIds.add(targetId)) {
      throw BackupValidationException(
        'Event #$targetId is reversed more than once in this backup.',
      );
    }
    if (event.delta != -target.delta) {
      throw BackupValidationException(
        'Reversal event #${event.id} delta does not cancel event #$targetId.',
      );
    }
  }

  for (final batch in backup.batches) {
    final remaining = batch.startingQty + (deltaSumByBatch[batch.id] ?? 0);
    if (remaining < 0 || remaining > 1000000000) {
      throw BackupValidationException(
        'Resulting remaining stock ($remaining) for "${batch.name}" is out of range.',
      );
    }
  }

  final editIds = <int>{};
  for (final edit in backup.batchEdits) {
    if (edit.id < 1 || !editIds.add(edit.id)) {
      throw BackupValidationException(
        'Backup contains an invalid or duplicate batch edit ID (#${edit.id}).',
      );
    }
    if (!batchById.containsKey(edit.batchId)) {
      throw BackupValidationException(
        'Edit #${edit.id} references missing batch #${edit.batchId}.',
      );
    }
    try {
      BatchDetailsDraft(
        name: edit.oldName,
        storage: edit.oldStorage,
        printedDate: edit.oldDate,
      );
      BatchDetailsDraft(
        name: edit.newName,
        storage: edit.newStorage,
        printedDate: edit.newDate,
      );
    } on ArgumentError catch (error) {
      throw BackupValidationException(
        'Invalid detail history #${edit.id}: ${error.message}',
      );
    }
    if (DateTime.tryParse(edit.createdAt) == null) {
      throw BackupValidationException(
        'Detail history #${edit.id} has an invalid timestamp.',
      );
    }
  }

  final settings = backup.reminderSettings;
  if (settings.hour < 0 ||
      settings.hour > 23 ||
      settings.minute < 0 ||
      settings.minute > 59 ||
      ![1, 3].contains(settings.leadDays)) {
    throw const BackupValidationException(
      'Backup contains invalid reminder settings.',
    );
  }
}
