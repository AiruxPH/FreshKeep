import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../domain/backup/backup_models.dart';

/// Raw content of a user-selected JSON backup file.
class PickedBackupFile {
  const PickedBackupFile({required this.name, required this.content});
  final String name;
  final String content;
}

typedef SaveBackupFile =
    Future<bool> Function(String fileName, String jsonContent);
typedef PickBackupFile = Future<PickedBackupFile?> Function();

const int maxBackupFileBytes = 50 * 1024 * 1024;

/// Saves [jsonContent] as [fileName] via the platform file saver (Android SAF
/// document creation or browser download). Returns `false` if cancelled.
Future<bool> saveBackupFileToDevice(String fileName, String jsonContent) async {
  final bytes = Uint8List.fromList(utf8.encode(jsonContent));
  final savedUri = await FilePicker.saveFile(
    fileName: fileName,
    bytes: bytes,
    mimeType: 'application/json',
    dialogTitle: 'Save FreshKeep JSON backup',
  );
  return savedUri != null;
}

/// Prompts the user to pick a JSON backup file and decodes it as UTF-8 text.
Future<PickedBackupFile?> pickBackupFileFromDevice() async {
  final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  // On Android, FileType.custom with ['json'] can gray out .json files in
  // Downloads because OEM file managers disagree on application/json MIME tags.
  final picked = await FilePicker.pickFile(
    dialogTitle: 'Choose FreshKeep JSON backup',
    type: isAndroid ? FileType.any : FileType.custom,
    allowedExtensions: isAndroid ? null : const ['json'],
  );
  if (picked == null) return null;

  final reportedLength = await picked.length();
  if (reportedLength != null && reportedLength > maxBackupFileBytes) {
    throw const BackupValidationException(
      'Backup file is larger than 50 MB and cannot be opened.',
    );
  }

  final bytes = await picked.readAsBytes();
  if (bytes.length > maxBackupFileBytes) {
    throw const BackupValidationException(
      'Backup file is larger than 50 MB and cannot be opened.',
    );
  }

  try {
    return PickedBackupFile(name: picked.name, content: utf8.decode(bytes));
  } on FormatException {
    throw const BackupValidationException(
      'Selected file is not valid UTF-8 JSON text.',
    );
  }
}
