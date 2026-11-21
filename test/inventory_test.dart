import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshkeep/data/inventory_database.dart';
import 'package:freshkeep/domain/batch.dart';
import 'package:freshkeep/main.dart';

void main() {
  test(
    'SQLite keeps separate batches and dates after closing and reopening',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'freshkeep_test_',
      );
      final file = File('${directory.path}/inventory.sqlite');
      var database = InventoryDatabase(NativeDatabase(file));
      try {
        await database.addBatch(
          BatchDraft(
            name: 'Milk',
            quantity: 500,
            unit: 'mL',
            storage: 'Fridge',
            printedDate: '2026-11-05',
          ),
        );
        await database.addBatch(
          BatchDraft(
            name: 'Milk',
            quantity: 250,
            unit: 'mL',
            storage: 'Fridge',
          ),
        );
        await database.close();
        database = InventoryDatabase(NativeDatabase(file));
        final batches = await database.loadBatches();
        expect(batches, hasLength(2));
        expect(batches.first.draft.quantity, 250);
        expect(batches.first.draft.printedDate, isNull);
        expect(batches.last.draft.printedDate, '2026-11-05');
        expect(batches.first.id, isNot(batches.last.id));
      } finally {
        await database.close();
        await directory.delete(recursive: true);
      }
    },
  );

  testWidgets('manual entry validates, saves, and cancellation adds nothing', (
    tester,
  ) async {
    final database = InventoryDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(FreshKeepApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add groceries'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-groceries')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a food name.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Eggs');
    await tester.enterText(find.byType(TextFormField).at(1), '6');
    await tester.ensureVisible(find.byKey(const ValueKey('save-groceries')));
    await tester.tap(find.byKey(const ValueKey('save-groceries')));
    await tester.pumpAndSettle();
    expect(find.text('Eggs'), findsOneWidget);
    expect(find.text('6 pieces'), findsOneWidget);
    expect(find.text('Date unknown'), findsOneWidget);
    await tester.tap(find.text('Add groceries'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Unsaved food');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await database.loadBatches(), hasLength(1));
    expect(find.text('Unsaved food'), findsNothing);
  });
}
