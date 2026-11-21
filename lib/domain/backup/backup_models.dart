import '../guidance/guidance_selection.dart';
import '../reminder.dart';

/// How a validated backup should be applied to the local database.
enum BackupImportMode { merge, replace }

/// Thrown when backup JSON fails structural or invariant validation.
class BackupValidationException implements Exception {
  const BackupValidationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Serializable snapshot of a single grocery batch row and optional photo.
class BackupBatchRecord {
  const BackupBatchRecord({
    required this.id,
    required this.name,
    required this.startingQty,
    required this.unit,
    required this.storage,
    this.printedDate,
    this.printedTime,
    this.guidance,
    required this.createdAt,
    this.photoBase64,
  });

  final int id;
  final String name;
  final int startingQty;
  final String unit;
  final String storage;
  final String? printedDate;
  final String? printedTime;
  final BatchGuidance? guidance;
  final String createdAt;
  final String? photoBase64;
}

/// Serializable snapshot of a single append-only stock event row.
class BackupEventRecord {
  const BackupEventRecord({
    required this.id,
    required this.batchId,
    required this.type,
    required this.delta,
    this.reason,
    required this.createdAt,
    this.reversesId,
  });

  final int id;
  final int batchId;
  final String type;
  final int delta;
  final String? reason;
  final String createdAt;
  final int? reversesId;
}

/// Serializable snapshot of a single append-only batch detail audit row.
class BackupBatchEditRecord {
  const BackupBatchEditRecord({
    required this.id,
    required this.batchId,
    required this.oldName,
    required this.newName,
    required this.oldStorage,
    required this.newStorage,
    this.oldDate,
    this.newDate,
    required this.createdAt,
    this.photoChange,
    this.guidanceChange,
  });

  final int id;
  final int batchId;
  final String oldName;
  final String newName;
  final String oldStorage;
  final String newStorage;
  final String? oldDate;
  final String? newDate;
  final String createdAt;
  final String? photoChange;
  final String? guidanceChange;
}

/// Versioned offline JSON backup container for all FreshKeep local state.
class FreshKeepBackup {
  FreshKeepBackup({
    this.formatVersion = currentFormatVersion,
    this.dbSchemaVersion = currentDbSchemaVersion,
    this.appVersion = '1.0.0+1',
    required this.exportedAt,
    required this.includesPhotos,
    required this.batches,
    required this.events,
    required this.batchEdits,
    required this.reminderSettings,
    this.appPreferences = const {},
  });

  static const formatTag = 'freshkeep_backup';
  static const currentFormatVersion = 1;
  static const currentDbSchemaVersion = 8;

  final int formatVersion;
  final int dbSchemaVersion;
  final String appVersion;
  final DateTime exportedAt;
  final bool includesPhotos;
  final List<BackupBatchRecord> batches;
  final List<BackupEventRecord> events;
  final List<BackupBatchEditRecord> batchEdits;
  final ReminderSettings reminderSettings;
  final Map<String, String> appPreferences;

  int get photoCount =>
      batches.where((batch) => batch.photoBase64 != null).length;
}

/// Counts committed during an atomic backup import.
class BackupImportSummary {
  const BackupImportSummary({
    required this.batchesImported,
    required this.eventsImported,
    required this.editsImported,
    required this.photosImported,
    required this.mode,
  });

  final int batchesImported;
  final int eventsImported;
  final int editsImported;
  final int photosImported;
  final BackupImportMode mode;
}
