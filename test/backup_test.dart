import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshkeep/backup/backup_file_io.dart';
import 'package:freshkeep/backup_screen.dart';
import 'package:freshkeep/data/guidance_catalog.dart';
import 'package:freshkeep/data/inventory_database.dart';
import 'package:freshkeep/domain/backup/backup_filename.dart';
import 'package:freshkeep/domain/backup/backup_models.dart';
import 'package:freshkeep/domain/backup/parse_backup.dart';
import 'package:freshkeep/domain/backup/serialize_backup.dart';
import 'package:freshkeep/domain/batch.dart';
import 'package:freshkeep/domain/food_photo.dart';
import 'package:freshkeep/domain/guidance/find_guidance_rule.dart';
import 'package:freshkeep/domain/guidance/guidance_selection.dart';
import 'package:freshkeep/domain/reminder.dart';
import 'package:freshkeep/domain/stock_event.dart';
import 'package:freshkeep/main.dart';
import 'package:freshkeep/reminders/notification_service.dart';
import 'package:freshkeep/reminders/reminder_controller.dart';

FoodPhoto _testPhoto() => FoodPhoto(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAIAAAD8GO2jAAAAK0lEQVR4nO3NQQkAAAgEMKMZxUgX2RQ+hMH+q86cKoFAIBAIBAKBQJAnwQI8I8A9r3relAAAAABJRU5ErkJggg==',
  ),
);

Future<void> _seedRichDatabase(InventoryDatabase db) async {
  final milkRule = findGuidanceRule('milk')!;
  await db.addBatch(
    BatchDraft(
      name: 'Fresh Milk',
      quantity: 4,
      unit: 'pieces',
      storage: milkRule.storage,
      printedDate: '2026-12-01',
      printedTime: '08:30',
      photo: _testPhoto(),
      guidance: BatchGuidance.fromRule(
        rule: milkRule,
        anchorEvent: 'Opened',
        anchorDate: '2026-11-20',
      ),
    ),
  );
  await db.addBatch(
    BatchDraft(
      name: 'Oats',
      quantity: 500,
      unit: 'g',
      storage: 'Pantry',
    ),
  );

  final batches = await db.loadBatches();
  final milk = batches.firstWhere((b) => b.draft.name == 'Fresh Milk');
  final oats = batches.firstWhere((b) => b.draft.name == 'Oats');

  final consumeId = await db.recordAction(milk.id, StockAction.consume, 1);
  await db.recordAction(
    milk.id,
    StockAction.dispose,
    1,
    reason: 'Spilled',
  );
  await db.undoEvent(milk.id, consumeId);
  await db.recordAction(oats.id, StockAction.correct, 450);

  await db.editBatchDetails(
    oats.id,
    BatchDetailsDraft(name: 'Rolled Oats', storage: 'Pantry'),
    expected: oats.draft,
  );
  await db.saveReminderSettings(
    ReminderSettings(enabled: true, hour: 18, minute: 45, leadDays: 1),
  );
  await db.markOnboardingCompleted();
}

void main() {
  test('buildBackupFilename formats deterministic local timestamp', () {
    expect(
      buildBackupFilename(DateTime(2026, 11, 21, 9, 5, 7)),
      'freshkeep-backup-20261121-090507.json',
    );
  });

  test('export and parse round-trip preserves batches, time, guidance, photos, events, edits, and settings', () async {
    final db = InventoryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedRichDatabase(db);

    final exportedWithPhotos = await db.exportBackup(
      includePhotos: true,
      now: DateTime.utc(2026, 11, 21, 10, 0),
    );
    final rawJson = serializeBackup(exportedWithPhotos);
    final parsed = parseBackup(rawJson);

    expect(parsed.batches, hasLength(2));
    expect(parsed.photoCount, 1);
    expect(parsed.events, hasLength(4));
    expect(parsed.batchEdits, hasLength(1));
    expect(parsed.reminderSettings.enabled, isTrue);
    expect(parsed.reminderSettings.hour, 18);
    expect(parsed.reminderSettings.minute, 45);
    expect(parsed.reminderSettings.leadDays, 1);
    expect(parsed.appPreferences['onboarding_completed'], '1');

    final milk = parsed.batches.firstWhere((b) => b.name == 'Fresh Milk');
    expect(milk.printedDate, '2026-12-01');
    expect(milk.printedTime, '08:30');
    expect(milk.guidance?.ruleId, 'milk');
    expect(milk.guidance?.suggestedDate, '2026-11-27');
    expect(milk.photoBase64, isNotNull);

    final exportedNoPhotos = await db.exportBackup(includePhotos: false);
    expect(exportedNoPhotos.includesPhotos, isFalse);
    expect(exportedNoPhotos.photoCount, 0);
  });

  test('parseBackup rejects corrupt JSON and domain-invariant violations', () async {
    final db = InventoryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedRichDatabase(db);
    final validMap =
        jsonDecode(serializeBackup(await db.exportBackup()))
            as Map<String, dynamic>;

    expect(() => parseBackup('{not valid json'), throwsA(isA<BackupValidationException>()));

    final wrongFormat = Map<String, dynamic>.of(validMap)..['format'] = 'other';
    expect(
      () => parseBackup(jsonEncode(wrongFormat)),
      throwsA(isA<BackupValidationException>()),
    );

    final badVersion = Map<String, dynamic>.of(validMap)
      ..['formatVersion'] = 99;
    expect(
      () => parseBackup(jsonEncode(badVersion)),
      throwsA(isA<BackupValidationException>()),
    );

    final negativeStock = jsonDecode(jsonEncode(validMap)) as Map<String, dynamic>;
    final events = negativeStock['events'] as List<dynamic>;
    (events[1] as Map<String, dynamic>)['delta'] = -100;
    expect(
      () => parseBackup(jsonEncode(negativeStock)),
      throwsA(isA<BackupValidationException>()),
    );

    final brokenReverse = jsonDecode(jsonEncode(validMap)) as Map<String, dynamic>;
    final reverseEvent = (brokenReverse['events'] as List<dynamic>).firstWhere(
      (e) => (e as Map<String, dynamic>)['type'] == 'reverse',
    ) as Map<String, dynamic>;
    reverseEvent['reversesId'] = 999;
    expect(
      () => parseBackup(jsonEncode(brokenReverse)),
      throwsA(isA<BackupValidationException>()),
    );

    final hugePhoto = jsonDecode(jsonEncode(validMap)) as Map<String, dynamic>;
    (hugePhoto['batches'] as List<dynamic>).first['photoBase64'] = base64Encode(
      Uint8List(FoodPhoto.maxBytes + 1),
    );
    expect(
      () => parseBackup(jsonEncode(hugePhoto)),
      throwsA(isA<BackupValidationException>()),
    );

    final badGuidanceStorage =
        jsonDecode(jsonEncode(validMap)) as Map<String, dynamic>;
    final milkJson = (badGuidanceStorage['batches'] as List<dynamic>).firstWhere(
      (b) => (b as Map<String, dynamic>)['name'] == 'Fresh Milk',
    ) as Map<String, dynamic>;
    milkJson['storage'] = 'Pantry'; // 'milk' rule requires Fridge
    expect(
      () => parseBackup(jsonEncode(badGuidanceStorage)),
      throwsA(isA<BackupValidationException>()),
    );
  });

  test('merge import preserves existing records and remaps IDs and reversals', () async {
    final sourceDb = InventoryDatabase(NativeDatabase.memory());
    addTearDown(sourceDb.close);
    await _seedRichDatabase(sourceDb);
    final backup = parseBackup(serializeBackup(await sourceDb.exportBackup()));

    final targetDb = InventoryDatabase(NativeDatabase.memory());
    addTearDown(targetDb.close);
    await targetDb.addBatch(
      BatchDraft(name: 'Existing Rice', quantity: 2, unit: 'pieces', storage: 'Pantry'),
    );
    await targetDb.saveReminderSettings(
      ReminderSettings(enabled: false, hour: 7, minute: 15, leadDays: 3),
    );

    final summary = await targetDb.importBackup(
      backup,
      mode: BackupImportMode.merge,
    );
    expect(summary.batchesImported, 2);
    expect(summary.eventsImported, 4);
    expect(summary.editsImported, 1);
    expect(summary.photosImported, 1);

    final mergedBatches = await targetDb.loadBatches();
    expect(mergedBatches, hasLength(3));
    expect(
      mergedBatches.firstWhere((b) => b.draft.name == 'Existing Rice').remaining,
      2,
    );
    final milk = mergedBatches.firstWhere((b) => b.draft.name == 'Fresh Milk');
    expect(milk.remaining, 3);
    expect(milk.draft.photo!.sameAs(_testPhoto()), isTrue);
    expect(milk.draft.printedTime, '08:30');
    expect(milk.draft.guidance?.ruleId, 'milk');
    expect(await targetDb.disposedQuantity(milk.id), 1);

    final milkHistory = await targetDb.loadHistory(milk.id);
    expect(milkHistory, hasLength(3));
    expect(
      milkHistory.where((e) => e.type == 'consume').single.reversed,
      isTrue,
    );

    final targetSettings = await targetDb.loadReminderSettings();
    expect(targetSettings.enabled, isFalse);
    expect(targetSettings.hour, 7);
  });

  test('replace import restores full dataset, preserves onboarding, and retains append-only triggers', () async {
    final sourceDb = InventoryDatabase(NativeDatabase.memory());
    addTearDown(sourceDb.close);
    await _seedRichDatabase(sourceDb);
    final backup = parseBackup(serializeBackup(await sourceDb.exportBackup()));

    final targetDb = InventoryDatabase(NativeDatabase.memory());
    addTearDown(targetDb.close);
    await targetDb.addBatch(
      BatchDraft(name: 'Temporary Item', quantity: 9, unit: 'pieces', storage: 'Pantry'),
    );
    await targetDb.markOnboardingCompleted();

    final summary = await targetDb.importBackup(
      backup,
      mode: BackupImportMode.replace,
    );
    expect(summary.mode, BackupImportMode.replace);
    expect(summary.batchesImported, 2);

    final restoredBatches = await targetDb.loadBatches();
    expect(restoredBatches, hasLength(2));
    expect(
      restoredBatches.any((b) => b.draft.name == 'Temporary Item'),
      isFalse,
    );
    final settings = await targetDb.loadReminderSettings();
    expect(settings.enabled, isTrue);
    expect(settings.hour, 18);
    expect(await targetDb.hasCompletedOnboarding(), isTrue);

    // Append-only protection must still abort updates/deletes after replace.
    await expectLater(
      targetDb.customStatement('DELETE FROM events'),
      throwsException,
    );
    await expectLater(
      targetDb.customStatement("UPDATE batch_edits SET new_name = 'Tampered'"),
      throwsException,
    );
  });

  test('backup restore persists across real SQLite file close and reopen', () async {
    final dir = await Directory.systemTemp.createTemp('freshkeep_backup_test_');
    addTearDown(() => dir.delete(recursive: true));
    final file1 = File('${dir.path}/source.sqlite');
    final file2 = File('${dir.path}/restored.sqlite');

    final db1 = InventoryDatabase(NativeDatabase(file1));
    await _seedRichDatabase(db1);
    final rawJson = serializeBackup(await db1.exportBackup());
    await db1.close();

    final db2 = InventoryDatabase(NativeDatabase(file2));
    await db2.importBackup(parseBackup(rawJson), mode: BackupImportMode.replace);
    await db2.close();

    final db3 = InventoryDatabase(NativeDatabase(file2));
    addTearDown(db3.close);
    final batches = await db3.loadBatches();
    expect(batches, hasLength(2));
    expect(
      batches.firstWhere((b) => b.draft.name == 'Fresh Milk').draft.photo,
      isNotNull,
    );
    expect(await db3.loadGuidanceCatalogCountForCheck(), greaterThan(0));
  });

  testWidgets('BackupScreen exports, handles cancel, imports with preview, and keeps DB intact on error', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sourceDb = InventoryDatabase(NativeDatabase.memory());
    addTearDown(sourceDb.close);
    await _seedRichDatabase(sourceDb);
    final exportedJson = serializeBackup(await sourceDb.exportBackup());

    final db = InventoryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.addBatch(
      BatchDraft(name: 'Bread', quantity: 2, unit: 'pieces', storage: 'Pantry'),
    );
    final controller = ReminderController(db, PreviewNotifications());
    addTearDown(controller.dispose);
    await controller.start();

    String? savedFilename;
    String? savedContent;
    var allowSave = true;
    PickedBackupFile? nextPickedFile;

    await tester.pumpWidget(
      MaterialApp(
        home: BackupScreen(
          database: db,
          reminders: controller,
          saveFile: (name, json) async {
            savedFilename = name;
            savedContent = json;
            return allowSave;
          },
          pickFile: () async => nextPickedFile,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('1 batch (1 in stock, 0 used up)'), findsOneWidget);

    // Export file succeeds
    await tester.tap(find.byKey(const ValueKey('export-backup-file')));
    await tester.pumpAndSettle();
    expect(savedFilename, startsWith('freshkeep-backup-'));
    expect(parseBackup(savedContent!).batches.single.name, 'Bread');
    expect(find.text('Backup saved (1 batch).'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));

    // Export cancelled
    allowSave = false;
    await tester.tap(find.byKey(const ValueKey('export-backup-file')));
    await tester.pumpAndSettle();
    expect(find.text('Export cancelled.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));

    // Corrupt file import leaves existing batch untouched and displays error
    nextPickedFile = const PickedBackupFile(
      name: 'bad.json',
      content: '{"format": "invalid"}',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('import-backup-file')));
    await tester.tap(find.byKey(const ValueKey('import-backup-file')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Existing data was not changed.'), findsOneWidget);
    expect((await db.loadBatches()), hasLength(1));

    // Valid file import -> preview -> Merge
    nextPickedFile = PickedBackupFile(
      name: 'valid.json',
      content: exportedJson,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('import-backup-file')));
    await tester.tap(find.byKey(const ValueKey('import-backup-file')));
    await tester.pumpAndSettle();
    expect(find.text('Review backup before import'), findsOneWidget);
    expect(find.textContaining('2 batches · 1 photo'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-backup-import')));
    await tester.pumpAndSettle();
    expect((await db.loadBatches()), hasLength(3));
    expect(find.textContaining('Imported 2 batches (merged).'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));

    // Paste JSON -> Replace mode removes 'Bread' and restores source dataset
    await tester.ensureVisible(find.byKey(const ValueKey('paste-backup-json')));
    await tester.tap(find.byKey(const ValueKey('paste-backup-json')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('paste-backup-field')),
      exportedJson,
    );
    await tester.tap(find.byKey(const ValueKey('review-pasted-backup')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('import-mode-replace')));
    await tester.tap(find.byKey(const ValueKey('import-mode-replace')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-backup-import')));
    await tester.pumpAndSettle();

    final finalBatches = await db.loadBatches();
    expect(finalBatches, hasLength(2));
    expect(finalBatches.any((b) => b.draft.name == 'Bread'), isFalse);
    expect(controller.settings.hour, 18);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('More tab opens Backup & restore cleanly at 2.0x text scale', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final db = InventoryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(FreshKeepApp(database: db));
    await tester.pumpAndSettle();

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Backup & restore'));
    await tester.tap(find.text('Backup & restore'));
    await tester.pumpAndSettle();
    expect(find.text('Local JSON backup'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

extension on InventoryDatabase {
  Future<int> loadGuidanceCatalogCountForCheck() async => guidanceCatalog.length;
}
