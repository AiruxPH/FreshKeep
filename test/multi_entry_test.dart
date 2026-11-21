import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshkeep/data/inventory_database.dart';
import 'package:freshkeep/domain/batch.dart';
import 'package:freshkeep/domain/stock_event.dart';
import 'package:freshkeep/main.dart';

class DelayedDatabase extends InventoryDatabase {
  DelayedDatabase() : super(NativeDatabase.memory());
  final gate = Completer<void>();
  int calls = 0;
  @override
  Future<void> addBatches(List<BatchDraft> drafts) async {
    calls++;
    await gate.future;
    await super.addBatches(drafts);
  }
}

void main() {
  BatchDraft draft(String name, {String? date, int quantity = 1}) => BatchDraft(
    name: name,
    quantity: quantity,
    unit: 'pieces',
    storage: 'Pantry',
    printedDate: date,
  );

  test(
    'group save preserves separate batches and dates for identical foods',
    () async {
      final db = InventoryDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.addBatches([
        draft('Milk', date: '2026-11-10'),
        draft('Milk', date: '2026-11-12'),
      ]);
      final rows = await db.loadBatches();
      expect(rows, hasLength(2));
      expect(rows.map((r) => r.draft.printedDate), [
        '2026-11-12',
        '2026-11-10',
      ]);
      expect(rows.map((r) => r.id).toSet(), hasLength(2));
      expect(() => db.addBatches([]), throwsArgumentError);
    },
  );

  test('failure in a later insert rolls back every new row and retains old inventory', () async {
    final db = InventoryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.addBatch(draft('Existing'));
    await db.customStatement(
      "CREATE TRIGGER reject_test BEFORE INSERT ON batches WHEN NEW.name='Fail' BEGIN SELECT RAISE(ABORT,'Simulated failure'); END",
    );
    await expectLater(
      db.addBatches([draft('First new'), draft('Fail')]),
      throwsA(anything),
    );
    expect((await db.loadBatches()).map((r) => r.draft.name), ['Existing']);
  });

  test('previous names deduplicate case-insensitively, newest spelling first, including depleted batches', () async {
    final db = InventoryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.addBatches([draft('Milk'), draft('Eggs'), draft(' MILK ')]);
    final id = (await db.loadBatches()).first.id;
    await db.recordAction(id, StockAction.consume, 1);
    expect(await db.previousFoodNames(), ['MILK', 'Eggs']);
  });

  testWidgets(
    'invalid row saves nothing; removing it preserves the other draft',
    (tester) async {
      final db = InventoryDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.pumpWidget(FreshKeepApp(database: db));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add groceries'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Eggs');
      await tester.enterText(find.byType(TextFormField).at(1), '6');
      await tester.ensureVisible(find.byKey(const ValueKey('add-grocery-row')));
      await tester.tap(find.byKey(const ValueKey('add-grocery-row')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-groceries')));
      await tester.pumpAndSettle();
      expect(await db.loadBatches(), isEmpty);
      expect(find.text('Enter a food name.'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Remove grocery 2'));
      await tester.tap(find.byTooltip('Remove grocery 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-groceries')));
      await tester.pumpAndSettle();
      expect((await db.loadBatches()).single.draft.quantity, 6);
      expect(find.text('Eggs'), findsOneWidget);
    },
  );

  testWidgets('multi-row save keeps rows independent and cancel adds nothing', (
    tester,
  ) async {
    final db = InventoryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(FreshKeepApp(database: db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add groceries'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Eggs');
    await tester.enterText(find.byType(TextFormField).at(1), '6');
    await tester.ensureVisible(find.byKey(const ValueKey('add-grocery-row')));
    await tester.tap(find.byKey(const ValueKey('add-grocery-row')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextFormField).at(2));
    await tester.enterText(find.byType(TextFormField).at(2), 'Bread');
    await tester.enterText(find.byType(TextFormField).at(3), '2');
    await tester.tap(find.byKey(const ValueKey('save-groceries')));
    await tester.pumpAndSettle();
    expect((await db.loadBatches()).map((r) => r.draft.quantity), [2, 6]);
    await tester.tap(find.text('Add groceries'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('add-grocery-row')));
    await tester.tap(find.byKey(const ValueKey('add-grocery-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await db.loadBatches(), hasLength(2));
  });

  testWidgets('selecting a searched name does not copy old quantity or date', (
    tester,
  ) async {
    final db = InventoryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.addBatch(draft('Fresh milk', date: '2026-11-12', quantity: 12));
    await tester.pumpWidget(FreshKeepApp(database: db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add groceries'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'MIL');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Fresh milk'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-groceries')));
    await tester.pumpAndSettle();
    final added = (await db.loadBatches()).first.draft;
    expect(added.name, 'Fresh milk');
    expect(added.quantity, 1);
    expect(added.printedDate, isNull);
  });

  testWidgets(
    'failed save keeps rows editable and retries without duplicates',
    (tester) async {
      final db = InventoryDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.loadBatches();
      await db.customStatement(
        "CREATE TRIGGER reject_test BEFORE INSERT ON batches BEGIN SELECT RAISE(ABORT,'Simulated failure'); END",
      );
      await tester.pumpWidget(FreshKeepApp(database: db));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add groceries'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Eggs');
      await tester.tap(find.byKey(const ValueKey('save-groceries')));
      await tester.pumpAndSettle();
      expect(find.textContaining('No rows were saved.'), findsOneWidget);
      expect(await db.loadBatches(), isEmpty);
      await db.customStatement('DROP TRIGGER reject_test');
      await tester.tap(find.byKey(const ValueKey('save-groceries')));
      await tester.pumpAndSettle();
      expect((await db.loadBatches()).single.draft.name, 'Eggs');
    },
  );

  testWidgets('in-flight save disables duplicate submissions and editing', (
    tester,
  ) async {
    final db = DelayedDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(FreshKeepApp(database: db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add groceries'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Eggs');
    await tester.tap(find.byKey(const ValueKey('save-groceries')));
    await tester.pump();
    expect(find.text('Saving…'), findsOneWidget);
    await tester.tap(find.text('Saving…'));
    await tester.pump();
    expect(db.calls, 1);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField).first).enabled,
      isFalse,
    );
    db.gate.complete();
    await tester.pumpAndSettle();
    expect(await db.loadBatches(), hasLength(1));
  });
}
