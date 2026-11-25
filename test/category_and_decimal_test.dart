import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshkeep/add_groceries_dialog.dart';
import 'package:freshkeep/data/inventory_database.dart';
import 'package:freshkeep/domain/backup/backup_models.dart';
import 'package:freshkeep/domain/backup/parse_backup.dart';
import 'package:freshkeep/domain/backup/serialize_backup.dart';
import 'package:freshkeep/domain/batch.dart';
import 'package:freshkeep/domain/food_category.dart';
import 'package:freshkeep/domain/inventory_query.dart';
import 'package:freshkeep/domain/quantity/format_quantity.dart';
import 'package:freshkeep/domain/quantity/quantity_math.dart';
import 'package:freshkeep/domain/quantity/validate_quantity.dart';
import 'package:freshkeep/domain/stock_event.dart';
import 'package:freshkeep/inventory_screen.dart';
import 'package:freshkeep/widgets/local_day_scope.dart';

void main() {
  group('Food categories & decimal quantities — domain', () {
    test('normalizes categories and rejects unsupported values', () {
      expect(FoodCategory.normalize(null), 'Other');
      expect(FoodCategory.normalize('   '), 'Other');
      expect(FoodCategory.normalize('Dairy & Eggs'), 'Dairy & Eggs');
      expect(
        () => FoodCategory.normalize('UnknownCategory'),
        throwsArgumentError,
      );
    });

    test('validates whole-number pieces and up-to-2-decimal g/mL', () {
      expect(
        BatchDraft(
          name: 'Eggs',
          quantity: 6,
          unit: 'pieces',
          storage: 'Fridge',
          category: 'Dairy & Eggs',
        ).quantity,
        6,
      );
      expect(
        () => BatchDraft(
          name: 'Eggs',
          quantity: 1.5,
          unit: 'pieces',
          storage: 'Fridge',
        ),
        throwsArgumentError,
      );

      final flour = BatchDraft(
        name: 'Flour',
        quantity: 250.75,
        unit: 'g',
        storage: 'Pantry',
        category: 'Grains & Bakery',
      );
      expect(flour.quantity, 250.75);
      expect(flour.category, 'Grains & Bakery');

      final milk = BatchDraft(
        name: 'Milk',
        quantity: 0.5,
        unit: 'mL',
        storage: 'Fridge',
      );
      expect(milk.quantity, 0.5);

      expect(
        () => BatchDraft(
          name: 'Spice',
          quantity: 1.234,
          unit: 'g',
          storage: 'Pantry',
        ),
        throwsArgumentError,
      );
      expect(parseQuantityInput('1.5', 'pieces'), isNull);
      expect(parseQuantityInput('1.25', 'g'), 1.25);
      expect(parseQuantityInput('1.255', 'g'), isNull);
    });

    test('exact hundredths arithmetic avoids float drift and formats cleanly', () {
      final afterConsume = subtractQuantities(1.5, 0.3);
      expect(afterConsume, 1.2);
      final afterDispose = subtractQuantities(afterConsume, 1.2);
      expect(afterDispose, 0);
      expect(toScaledUnits(afterDispose), 0);

      expect(formatQuantityValue(5.0), '5');
      expect(formatQuantityValue(1.50), '1.5');
      expect(formatQuantityValue(0.25), '0.25');
      expect(quantityLabel(1, 'pieces'), '1 piece');
      expect(quantityLabel(2, 'pieces'), '2 pieces');
      expect(quantityLabel(1.5, 'g'), '1.5 g');
      expect(quantityLabel(0.25, 'mL'), '0.25 mL');

      expect(
        stockDelta(StockAction.consume, 0.3, 1.5, unit: 'g'),
        -0.3,
      );
      expect(
        () => stockDelta(StockAction.consume, 0.5, 2, unit: 'pieces'),
        throwsA(isA<StockValidationException>()),
      );
    });

    test('queryInventory searches by category and filters by category', () {
      final batches = [
        InventoryBatch(
          id: 1,
          remaining: 6,
          draft: BatchDraft(
            name: 'Eggs',
            quantity: 6,
            unit: 'pieces',
            storage: 'Fridge',
            category: 'Dairy & Eggs',
          ),
        ),
        InventoryBatch(
          id: 2,
          remaining: 250.5,
          draft: BatchDraft(
            name: 'Spinach',
            quantity: 250.5,
            unit: 'g',
            storage: 'Fridge',
            category: 'Produce',
          ),
        ),
      ];
      final now = DateTime(2026, 11, 25);

      final bySearch = queryInventory(batches, now, search: 'produce');
      expect(bySearch.map((b) => b.id), [2]);

      final byFilter = queryInventory(
        batches,
        now,
        category: 'Dairy & Eggs',
      );
      expect(byFilter.map((b) => b.id), [1]);
    });
  });

  group('Food categories & decimal quantities — database & backup', () {
    test('persists categories, decimal stock actions, undo, edits, and report totals', () async {
      final dir = await Directory.systemTemp.createTemp('freshkeep_v9_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/freshkeep.sqlite');

      final db = InventoryDatabase(NativeDatabase(file));
      await db.addBatch(
        BatchDraft(
          name: 'Oats',
          quantity: 1.5,
          unit: 'g',
          storage: 'Pantry',
          category: 'Grains & Bakery',
        ),
      );
      final batch = (await db.loadBatches()).single;
      expect(batch.draft.category, 'Grains & Bakery');
      expect(batch.remaining, 1.5);

      await db.recordAction(batch.id, StockAction.consume, 0.3);
      final disposeId = await db.recordAction(
        batch.id,
        StockAction.dispose,
        1.2,
        reason: 'Spilled',
      );
      var updated = await db.loadBatch(batch.id);
      expect(updated.remaining, 0);
      expect(updated.depleted, isTrue);

      final reportWhileDepleted = await db.loadReport();
      expect(reportWhileDepleted.remainingByUnit['g'], 0);
      expect(reportWhileDepleted.disposedByUnit['g'], 1.2);

      await db.undoEvent(batch.id, disposeId);
      updated = await db.loadBatch(batch.id);
      expect(updated.remaining, 1.2);
      expect(updated.depleted, isFalse);

      await db.editBatchDetails(
        batch.id,
        BatchDetailsDraft(
          name: 'Oats',
          storage: 'Pantry',
          category: 'Canned & Dry',
        ),
        expected: updated.draft,
      );
      final edits = await db.loadDetailsHistory(batch.id);
      expect(edits.single.before.category, 'Grains & Bakery');
      expect(edits.single.after.category, 'Canned & Dry');

      await db.close();

      final reopened = InventoryDatabase(NativeDatabase(file));
      addTearDown(reopened.close);
      final reloaded = (await reopened.loadBatches()).single;
      expect(reloaded.draft.category, 'Canned & Dry');
      expect(reloaded.remaining, 1.2);
    });

    test('backup round-trips categories and decimals and accepts legacy v8 JSON', () async {
      final db = InventoryDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await db.addBatch(
        BatchDraft(
          name: 'Soy Milk',
          quantity: 500.5,
          unit: 'mL',
          storage: 'Fridge',
          category: 'Beverages',
        ),
      );
      final batch = (await db.loadBatches()).single;
      await db.recordAction(batch.id, StockAction.consume, 125.25);

      final exported = await db.exportBackup(includePhotos: false);
      final rawJson = serializeBackup(exported);
      final parsed = parseBackup(rawJson);
      expect(parsed.batches.single.category, 'Beverages');
      expect(parsed.batches.single.startingQty, 500.5);
      expect(parsed.events.single.delta, -125.25);

      final restoredDb = InventoryDatabase(NativeDatabase.memory());
      addTearDown(restoredDb.close);
      await restoredDb.importBackup(parsed, mode: BackupImportMode.replace);
      final restored = (await restoredDb.loadBatches()).single;
      expect(restored.draft.category, 'Beverages');
      expect(restored.remaining, 375.25);

      // Legacy v8 JSON without category fields defaults cleanly to 'Other'.
      final legacyMap = jsonDecode(rawJson) as Map<String, dynamic>;
      (legacyMap['batches'] as List).first.remove('category');
      final legacyParsed = parseBackup(jsonEncode(legacyMap));
      expect(legacyParsed.batches.single.category, 'Other');
    });

    test('migrates v8 database losslessly to v9 and allows decimal actions', () async {
      final dir = await Directory.systemTemp.createTemp('freshkeep_v8_to_v9_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/legacy.sqlite');

      // Seed a realistic v8 schema directly.
      final seed = InventoryDatabase(NativeDatabase(file));
      await seed.customStatement('PRAGMA foreign_keys = OFF');
      await seed.customStatement('DROP TABLE batches');
      await seed.customStatement('DROP TABLE events');
      await seed.customStatement('DROP TABLE batch_edits');
      await seed.customStatement('''
        CREATE TABLE batches (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 100),
          starting_qty INTEGER NOT NULL CHECK(starting_qty BETWEEN 1 AND 1000000000),
          unit TEXT NOT NULL CHECK(unit IN ('pieces', 'g', 'mL')),
          storage TEXT NOT NULL CHECK(storage IN ('Pantry', 'Fridge', 'Freezer')),
          printed_date TEXT,
          date_source TEXT NOT NULL CHECK(date_source IN ('printed', 'unknown')),
          printed_time TEXT,
          guidance_rule_id TEXT,
          guidance_catalog_version TEXT,
          guidance_anchor_event TEXT,
          guidance_anchor_date TEXT,
          suggested_date TEXT,
          created_at TEXT NOT NULL
        )
      ''');
      await seed.customStatement('''
        CREATE TABLE events (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          batch_id INTEGER NOT NULL REFERENCES batches(id),
          type TEXT NOT NULL CHECK(type IN ('consume','dispose','correct','reverse')),
          delta INTEGER NOT NULL CHECK(delta != 0),
          reason TEXT,
          created_at TEXT NOT NULL,
          reverses_id INTEGER UNIQUE REFERENCES events(id),
          CHECK((type = 'reverse' AND reverses_id IS NOT NULL) OR
                (type != 'reverse' AND reverses_id IS NULL)),
          CHECK(type NOT IN ('consume','dispose') OR delta < 0)
        )
      ''');
      await seed.customStatement('''
        CREATE TABLE batch_edits (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          batch_id INTEGER NOT NULL REFERENCES batches(id),
          old_name TEXT NOT NULL, new_name TEXT NOT NULL,
          old_storage TEXT NOT NULL, new_storage TEXT NOT NULL,
          old_date TEXT, new_date TEXT, created_at TEXT NOT NULL,
          photo_change TEXT, guidance_change TEXT
        )
      ''');
      await seed.customStatement(
        "INSERT INTO batches (id, name, starting_qty, unit, storage, date_source, created_at) "
        "VALUES (1, 'Rice', 500, 'g', 'Pantry', 'unknown', '2026-11-01T00:00:00Z')",
      );
      await seed.customStatement(
        "INSERT INTO events (id, batch_id, type, delta, created_at) "
        "VALUES (1, 1, 'consume', -100, '2026-11-02T00:00:00Z')",
      );
      await seed.customStatement('PRAGMA user_version = 8');
      await seed.close();

      final upgraded = InventoryDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);

      final batch = (await upgraded.loadBatches()).single;
      expect(batch.draft.name, 'Rice');
      expect(batch.draft.category, 'Other');
      expect(batch.remaining, 400);

      // Now record a decimal consumption on the upgraded batch.
      await upgraded.recordAction(batch.id, StockAction.consume, 50.5);
      expect((await upgraded.loadBatch(batch.id)).remaining, 349.5);
    });
  });

  group('Food categories & decimal quantities — widgets', () {
    testWidgets('AddGroceriesScreen saves decimal g with chosen category and rejects decimal pieces', (tester) async {
      final db = InventoryDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await tester.pumpWidget(
        MaterialApp(home: AddGroceriesScreen(database: db)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Butter');
      await tester.enterText(find.byType(TextFormField).at(1), '1.5');
      await tester.tap(find.byKey(const ValueKey('save-groceries')));
      await tester.pumpAndSettle();

      // Default unit is pieces, so 1.5 must be rejected.
      expect(find.textContaining('whole number'), findsOneWidget);

      // Switch unit to g.
      await tester.tap(find.text('pieces'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('g').last);
      await tester.pumpAndSettle();

      // Expand Storage & date and pick Dairy & Eggs.
      await tester.ensureVisible(find.text('Storage & date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Storage & date'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Other'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dairy & Eggs').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('save-groceries')));
      await tester.pumpAndSettle();

      final saved = (await db.loadBatches()).single;
      expect(saved.draft.name, 'Butter');
      expect(saved.draft.quantity, 1.5);
      expect(saved.draft.unit, 'g');
      expect(saved.draft.category, 'Dairy & Eggs');
    });

    testWidgets('InventoryScreen searches by category and filters by category dropdown', (tester) async {
      final db = InventoryDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await db.addBatches([
        BatchDraft(
          name: 'Bananas',
          quantity: 4,
          unit: 'pieces',
          storage: 'Pantry',
          category: 'Produce',
        ),
        BatchDraft(
          name: 'Cheddar',
          quantity: 120.5,
          unit: 'g',
          storage: 'Fridge',
          category: 'Dairy & Eggs',
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: LocalDayScope(
            now: () => DateTime(2026, 11, 25),
            child: InventoryScreen(database: db),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('120.5 g'), findsOneWidget);
      expect(find.text('Produce'), findsOneWidget);
      expect(find.text('Dairy & Eggs'), findsOneWidget);

      // Search by category name.
      await tester.enterText(find.byType(TextField).first, 'produce');
      await tester.pumpAndSettle();
      expect(find.text('Bananas'), findsOneWidget);
      expect(find.text('Cheddar'), findsNothing);

      // Reset and use Category filter dropdown.
      await tester.tap(find.text('Reset filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filters and sort'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All categories'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dairy & Eggs').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filters and sort'));
      await tester.pumpAndSettle();
      expect(find.text('Cheddar'), findsOneWidget);
      expect(find.text('Bananas'), findsNothing);
    });
  });
}
