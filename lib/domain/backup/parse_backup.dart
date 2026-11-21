import 'dart:convert';

import '../guidance/guidance_selection.dart';
import '../reminder.dart';
import 'backup_models.dart';
import 'validate_backup.dart';

/// Parses and validates a raw JSON string into a [FreshKeepBackup].
///
/// Rejects malformed JSON, wrong format tags, unsupported versions, type
/// mismatches, broken references, and stock/photo invariant violations.
FreshKeepBackup parseBackup(String rawJson) {
  final Object? decoded;
  try {
    decoded = jsonDecode(rawJson);
  } on FormatException {
    throw const BackupValidationException(
      'This file is not valid JSON. Choose an exported FreshKeep backup.',
    );
  }
  if (decoded is! Map<String, dynamic>) {
    throw const BackupValidationException(
      'Backup JSON must be a top-level object.',
    );
  }

  if (decoded['format'] != FreshKeepBackup.formatTag) {
    throw const BackupValidationException(
      'This JSON file is not a FreshKeep backup.',
    );
  }

  final formatVersion = _requireInt(decoded, 'formatVersion');
  if (formatVersion != FreshKeepBackup.currentFormatVersion) {
    throw BackupValidationException(
      'Unsupported backup format version ($formatVersion).',
    );
  }

  final dbSchemaVersion = decoded['dbSchemaVersion'] == null
      ? FreshKeepBackup.currentDbSchemaVersion
      : _requireInt(decoded, 'dbSchemaVersion');
  final appVersion = _optionalString(decoded, 'appVersion') ?? 'unknown';
  final exportedAtRaw = _requireString(decoded, 'exportedAt');
  final exportedAt = DateTime.tryParse(exportedAtRaw);
  if (exportedAt == null) {
    throw const BackupValidationException(
      'Backup has an invalid exportedAt timestamp.',
    );
  }
  final includesPhotos = decoded['includesPhotos'] is bool
      ? decoded['includesPhotos'] as bool
      : false;

  final batchesList = _requireMapList(decoded, 'batches');
  final eventsList = _requireMapList(decoded, 'events');
  final editsList = _requireMapList(decoded, 'batchEdits');
  final settingsMap = _requireMap(decoded, 'reminderSettings');

  final batches = [for (final item in batchesList) _parseBatch(item)];
  final events = [for (final item in eventsList) _parseEvent(item)];
  final edits = [for (final item in editsList) _parseEdit(item)];
  final reminderSettings = _parseReminderSettings(settingsMap);
  final appPreferences = _parsePreferences(decoded['appPreferences']);

  final backup = FreshKeepBackup(
    formatVersion: formatVersion,
    dbSchemaVersion: dbSchemaVersion,
    appVersion: appVersion,
    exportedAt: exportedAt,
    includesPhotos: includesPhotos,
    batches: batches,
    events: events,
    batchEdits: edits,
    reminderSettings: reminderSettings,
    appPreferences: appPreferences,
  );
  validateBackup(backup);
  return backup;
}

BackupBatchRecord _parseBatch(Map<String, dynamic> map) {
  final guidanceRaw = map['guidance'];
  BatchGuidance? guidance;
  if (guidanceRaw != null) {
    if (guidanceRaw is! Map<String, dynamic>) {
      throw const BackupValidationException('Batch guidance entry is invalid.');
    }
    try {
      guidance = BatchGuidance.stored(
        ruleId: _requireString(guidanceRaw, 'ruleId'),
        catalogVersion: _requireString(guidanceRaw, 'catalogVersion'),
        anchorEvent: _requireString(guidanceRaw, 'anchorEvent'),
        anchorDate: _requireString(guidanceRaw, 'anchorDate'),
        suggestedDate: _requireString(guidanceRaw, 'suggestedDate'),
      );
    } on ArgumentError catch (error) {
      throw BackupValidationException(
        'Invalid batch guidance in backup: ${error.message}',
      );
    }
  }

  return BackupBatchRecord(
    id: _requireInt(map, 'id'),
    name: _requireString(map, 'name'),
    startingQty: _requireInt(map, 'startingQty'),
    unit: _requireString(map, 'unit'),
    storage: _requireString(map, 'storage'),
    printedDate: _optionalString(map, 'printedDate'),
    printedTime: _optionalString(map, 'printedTime'),
    guidance: guidance,
    createdAt: _requireString(map, 'createdAt'),
    photoBase64: _optionalString(map, 'photoBase64'),
  );
}

BackupEventRecord _parseEvent(Map<String, dynamic> map) => BackupEventRecord(
  id: _requireInt(map, 'id'),
  batchId: _requireInt(map, 'batchId'),
  type: _requireString(map, 'type'),
  delta: _requireInt(map, 'delta'),
  reason: _optionalString(map, 'reason'),
  createdAt: _requireString(map, 'createdAt'),
  reversesId: _optionalInt(map, 'reversesId'),
);

BackupBatchEditRecord _parseEdit(Map<String, dynamic> map) =>
    BackupBatchEditRecord(
      id: _requireInt(map, 'id'),
      batchId: _requireInt(map, 'batchId'),
      oldName: _requireString(map, 'oldName'),
      newName: _requireString(map, 'newName'),
      oldStorage: _requireString(map, 'oldStorage'),
      newStorage: _requireString(map, 'newStorage'),
      oldDate: _optionalString(map, 'oldDate'),
      newDate: _optionalString(map, 'newDate'),
      createdAt: _requireString(map, 'createdAt'),
      photoChange: _optionalString(map, 'photoChange'),
      guidanceChange: _optionalString(map, 'guidanceChange'),
    );

ReminderSettings _parseReminderSettings(Map<String, dynamic> map) {
  final enabled = map['enabled'];
  if (enabled is! bool) {
    throw const BackupValidationException(
      'Backup reminderSettings.enabled must be a boolean.',
    );
  }
  try {
    return ReminderSettings(
      enabled: enabled,
      hour: _requireInt(map, 'hour'),
      minute: _requireInt(map, 'minute'),
      leadDays: _requireInt(map, 'leadDays'),
    );
  } on ArgumentError catch (error) {
    throw BackupValidationException(
      'Invalid reminder settings in backup: ${error.message}',
    );
  }
}

Map<String, String> _parsePreferences(Object? raw) {
  if (raw == null) return const {};
  if (raw is! Map<String, dynamic>) {
    throw const BackupValidationException(
      'Backup appPreferences must be an object.',
    );
  }
  final prefs = <String, String>{};
  for (final entry in raw.entries) {
    final value = entry.value;
    if (value is! String) {
      throw const BackupValidationException(
        'Backup preference values must be strings.',
      );
    }
    prefs[entry.key] = value;
  }
  return Map.unmodifiable(prefs);
}

int _requireInt(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! int) {
    throw BackupValidationException('Expected integer field "$key" in backup.');
  }
  return value;
}

int? _optionalInt(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is! int) {
    throw BackupValidationException(
      'Expected integer or null field "$key" in backup.',
    );
  }
  return value;
}

String _requireString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! String) {
    throw BackupValidationException('Expected string field "$key" in backup.');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is! String) {
    throw BackupValidationException(
      'Expected string or null field "$key" in backup.',
    );
  }
  return value;
}

Map<String, dynamic> _requireMap(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! Map<String, dynamic>) {
    throw BackupValidationException('Expected object field "$key" in backup.');
  }
  return value;
}

List<Map<String, dynamic>> _requireMapList(
  Map<String, dynamic> map,
  String key,
) {
  final value = map[key];
  if (value is! List) {
    throw BackupValidationException('Expected array field "$key" in backup.');
  }
  final result = <Map<String, dynamic>>[];
  for (final item in value) {
    if (item is! Map<String, dynamic>) {
      throw BackupValidationException(
        'Expected object entry inside "$key" array.',
      );
    }
    result.add(item);
  }
  return result;
}
