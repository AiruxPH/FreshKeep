import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshkeep/data/inventory_database.dart';
import 'package:freshkeep/domain/batch.dart';
import 'package:freshkeep/domain/food_photo.dart';
import 'package:freshkeep/domain/stock_event.dart';
import 'package:freshkeep/edit_batch_dialog.dart';
import 'package:freshkeep/widgets/food_photo.dart';

FoodPhoto photo() => FoodPhoto(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAIAAAD8GO2jAAAAK0lEQVR4nO3NQQkAAAgEMKMZxUgX2RQ+hMH+q86cKoFAIBAIBAKBQJAnwQI8I8A9r3relAAAAABJRU5ErkJggg==',
  ),
);
BatchDraft draft({FoodPhoto? image}) => BatchDraft(
  name: 'Eggs',
  quantity: 6,
  unit: 'pieces',
  storage: 'Fridge',
  printedDate: '2026-11-04',
  photo: image,
);
BatchDetailsDraft details(BatchDraft batch) => BatchDetailsDraft(
  name: batch.name,
  storage: batch.storage,
  printedDate: batch.printedDate,
);

void main() {
  test('photo bytes are bounded and immutable snapshots', () {
    final input = Uint8List.fromList([1, 2, 3]);
    final image = FoodPhoto(input);
    input[0] = 9;
    expect(image.bytes.first, 1);
    final exported = image.bytes;
    exported[0] = 9;
    expect(image.bytes.first, 1);
    expect(() => FoodPhoto(Uint8List(0)), throwsFormatException);
    expect(
      () => FoodPhoto(Uint8List(FoodPhoto.maxBytes + 1)),
      throwsFormatException,
    );
  });

  test('photo changes preserve stock, date and append-only history; stale photo edit rejected', () async {
    final db = InventoryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.addBatch(draft());
    final before = (await db.loadBatches()).single;
    await db.recordAction(before.id, StockAction.dispose, 1);
    await db.editBatchDetails(
      before.id,
      details(before.draft),
      expected: before.draft,
      updatePhoto: true,
      photo: photo(),
    );
    final withPhoto = await db.loadBatch(before.id);
    expect(withPhoto.draft.photo!.sameAs(photo()), isTrue);
    expect(withPhoto.remaining, 5);
    expect(withPhoto.draft.printedDate, before.draft.printedDate);
    expect(await db.disposedQuantity(before.id), 1);
    expect(await db.loadHistory(before.id), hasLength(1));
    expect(
      (await db.loadDetailsHistory(before.id)).single.photoChange,
      'Photo added',
    );
    await expectLater(
      db.editBatchDetails(
        before.id,
        details(before.draft),
        expected: before.draft,
        updatePhoto: true,
      ),
      throwsA(isA<StockValidationException>()),
    );
    // Metadata-only edits must not erase a newer photo.
    await db.editBatchDetails(
      before.id,
      BatchDetailsDraft(
        name: 'Fresh eggs',
        storage: 'Fridge',
        printedDate: before.draft.printedDate,
      ),
      expected: before.draft,
    );
    final renamed = await db.loadBatch(before.id);
    expect(renamed.draft.photo, isNotNull);
    await db.editBatchDetails(
      before.id,
      details(renamed.draft),
      expected: renamed.draft,
      updatePhoto: true,
    );
    expect((await db.loadBatch(before.id)).draft.photo, isNull);
    expect(
      (await db.loadDetailsHistory(before.id)).first.photoChange,
      'Photo removed',
    );
  });

  test('v4 migration and file reopen preserve existing data and independent batch photos', () async {
    final directory = await Directory.systemTemp.createTemp(
      'freshkeep_photos_',
    );
    final file = File('${directory.path}/db.sqlite');
    var db = InventoryDatabase(NativeDatabase(file));
    try {
      await db.addBatch(draft());
      final original = (await db.loadBatches()).single;
      await db.recordAction(original.id, StockAction.consume, 1);
      await db.editBatchDetails(
        original.id,
        BatchDetailsDraft(name: 'Older eggs', storage: 'Fridge'),
        expected: original.draft,
      );
      await db.customStatement('DROP TABLE batch_photos');
      await db.customStatement(
        'ALTER TABLE batch_edits DROP COLUMN photo_change',
      );
      await db.customStatement(
        'ALTER TABLE batch_edits DROP COLUMN guidance_change',
      );
      await db.customStatement('ALTER TABLE batches DROP COLUMN printed_time');
      await db.customStatement(
        'ALTER TABLE batches DROP COLUMN guidance_rule_id',
      );
      await db.customStatement(
        'ALTER TABLE batches DROP COLUMN guidance_catalog_version',
      );
      await db.customStatement(
        'ALTER TABLE batches DROP COLUMN guidance_anchor_event',
      );
      await db.customStatement(
        'ALTER TABLE batches DROP COLUMN guidance_anchor_date',
      );
      await db.customStatement(
        'ALTER TABLE batches DROP COLUMN suggested_date',
      );
      await db.customStatement('PRAGMA user_version=4');
      await db.close();
      db = InventoryDatabase(NativeDatabase(file));
      final migrated = await db.loadBatch(original.id);
      expect(migrated.draft.name, 'Older eggs');
      expect(migrated.remaining, 5);
      expect(migrated.draft.photo, isNull);
      expect(await db.loadDetailsHistory(original.id), hasLength(1));
      await db.addBatches([draft(image: photo()), draft()]);
      await db.close();
      db = InventoryDatabase(NativeDatabase(file));
      final batches = await db.loadBatches();
      expect(batches, hasLength(3));
      expect(batches[0].draft.photo, isNull);
      expect(batches[1].draft.photo!.sameAs(photo()), isTrue);
      expect(batches[2].remaining, 5);
    } finally {
      await db.close();
      await directory.delete(recursive: true);
    }
  });

  test('a failed photo write rolls back all new batches and an existing photo edit', () async {
    final db = InventoryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.addBatch(draft(image: photo()));
    final before = (await db.loadBatches()).single;
    await db.customStatement(
      "CREATE TRIGGER reject_photo BEFORE INSERT ON batch_photos BEGIN SELECT RAISE(ABORT, 'simulated failure'); END",
    );
    await expectLater(
      db.addBatches([draft(), draft(image: photo())]),
      throwsA(isA<Exception>()),
    );
    expect(await db.loadBatches(), hasLength(1));
    await db.customStatement(
      "CREATE TRIGGER reject_photo_audit BEFORE INSERT ON batch_edits BEGIN SELECT RAISE(ABORT, 'simulated failure'); END",
    );
    await expectLater(
      db.editBatchDetails(
        before.id,
        details(before.draft),
        expected: before.draft,
        updatePhoto: true,
      ),
      throwsA(isA<Exception>()),
    );
    expect(
      (await db.loadBatch(before.id)).draft.photo!.sameAs(photo()),
      isTrue,
    );
    expect(await db.loadDetailsHistory(before.id), isEmpty);
  });

  testWidgets('picker cancellation and failure keep the selected photo', (
    tester,
  ) async {
    FoodPhoto? selected = photo();
    var fail = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => FoodPhotoEditor(
              photo: selected,
              onChanged: (value) => setState(() => selected = value),
              pick: () async {
                if (fail) {
                  throw const FormatException('Choose a photo up to 5 MB.');
                }
                return null;
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Change photo'));
    await tester.pumpAndSettle();
    expect(selected, isNotNull);
    fail = true;
    await tester.tap(find.text('Change photo'));
    await tester.pumpAndSettle();
    expect(selected, isNotNull);
    expect(find.text('Choose a photo up to 5 MB.'), findsOneWidget);
    await tester.tap(find.text('Remove photo'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
  });

  testWidgets(
    'photo edit is saved explicitly and cancellation keeps stored image',
    (tester) async {
      final db = InventoryDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.addBatch(draft());
      var batch = (await db.loadBatches()).single;
      Future<void> open() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<bool>(
                    context: context,
                    builder: (_) => EditBatchDialog(
                      database: db,
                      batch: batch,
                      pickPhoto: () async => photo(),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
      }

      await open();
      await tester.tap(find.text('Add photo (optional)'));
      await tester.pumpAndSettle();
      expect((await db.loadBatch(batch.id)).draft.photo, isNull);
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      batch = await db.loadBatch(batch.id);
      expect(batch.draft.photo, isNotNull);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect((await db.loadBatch(batch.id)).draft.photo, isNotNull);
    },
  );

  testWidgets('camera capture supports capture, cancellation, failure and explicit edit save', (
    tester,
  ) async {
    FoodPhoto? selected = photo();
    var mode = 'cancel';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => FoodPhotoEditor(
              photo: selected,
              onChanged: (value) => setState(() => selected = value),
              capture: () async {
                if (mode == 'error') throw StateError('Camera unavailable');
                if (mode == 'capture') return photo();
                return null;
              },
            ),
          ),
        ),
      ),
    );
    expect(find.text('Take photo'), findsOneWidget);
    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();
    expect(selected, isNotNull);
    mode = 'error';
    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();
    expect(selected, isNotNull);
    expect(
      find.text(
        'Could not take a photo. Check camera access or try choosing from gallery.',
      ),
      findsOneWidget,
    );
    selected = null;
    mode = 'capture';
    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();
    expect(selected, isNotNull);

    final db = InventoryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.addBatch(draft());
    final batch = (await db.loadBatches()).single;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => EditBatchDialog(
                  database: db,
                  batch: batch,
                  takePhoto: () async => photo(),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();
    expect((await db.loadBatch(batch.id)).draft.photo, isNull);
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect((await db.loadBatch(batch.id)).draft.photo, isNotNull);
  });
}
