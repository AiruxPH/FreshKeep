import 'dart:convert';

import 'backup_models.dart';

/// Encodes a [FreshKeepBackup] snapshot as versioned offline JSON.
String serializeBackup(FreshKeepBackup backup, {bool pretty = true}) {
  final payload = <String, Object?>{
    'format': FreshKeepBackup.formatTag,
    'formatVersion': backup.formatVersion,
    'dbSchemaVersion': backup.dbSchemaVersion,
    'appVersion': backup.appVersion,
    'exportedAt': backup.exportedAt.toUtc().toIso8601String(),
    'includesPhotos': backup.includesPhotos,
    'batches': [
      for (final b in backup.batches)
        <String, Object?>{
          'id': b.id,
          'name': b.name,
          'startingQty': b.startingQty,
          'unit': b.unit,
          'storage': b.storage,
          'printedDate': b.printedDate,
          'printedTime': b.printedTime,
          'guidance': b.guidance == null
              ? null
              : <String, Object?>{
                  'ruleId': b.guidance!.ruleId,
                  'catalogVersion': b.guidance!.catalogVersion,
                  'anchorEvent': b.guidance!.anchorEvent,
                  'anchorDate': b.guidance!.anchorDate,
                  'suggestedDate': b.guidance!.suggestedDate,
                },
          'createdAt': b.createdAt,
          'photoBase64': b.photoBase64,
        },
    ],
    'events': [
      for (final e in backup.events)
        <String, Object?>{
          'id': e.id,
          'batchId': e.batchId,
          'type': e.type,
          'delta': e.delta,
          'reason': e.reason,
          'createdAt': e.createdAt,
          'reversesId': e.reversesId,
        },
    ],
    'batchEdits': [
      for (final edit in backup.batchEdits)
        <String, Object?>{
          'id': edit.id,
          'batchId': edit.batchId,
          'oldName': edit.oldName,
          'newName': edit.newName,
          'oldStorage': edit.oldStorage,
          'newStorage': edit.newStorage,
          'oldDate': edit.oldDate,
          'newDate': edit.newDate,
          'createdAt': edit.createdAt,
          'photoChange': edit.photoChange,
          'guidanceChange': edit.guidanceChange,
        },
    ],
    'reminderSettings': <String, Object?>{
      'enabled': backup.reminderSettings.enabled,
      'hour': backup.reminderSettings.hour,
      'minute': backup.reminderSettings.minute,
      'leadDays': backup.reminderSettings.leadDays,
    },
    'appPreferences': backup.appPreferences,
  };

  if (pretty) {
    return const JsonEncoder.withIndent('  ').convert(payload);
  }
  return jsonEncode(payload);
}
