import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshkeep/data/guidance_catalog.dart';
import 'package:freshkeep/data/inventory_database.dart';
import 'package:freshkeep/domain/batch.dart';
import 'package:freshkeep/guidance_screen.dart';
import 'package:freshkeep/main.dart';

void main() {
  test('case-insensitive searches distinguish conditions and storage', () {
    expect(searchGuidance('EGGS').map((r) => r.id), [
      'eggs-raw',
      'eggs-hard-cooked',
    ]);
    expect(searchGuidance('hard cooked eggs').single.id, 'eggs-hard-cooked');
    expect(searchGuidance('cooked rice').single.id, 'rice-cooked');
    expect(searchGuidance('mango').single.id, 'mango-ripe');
    expect(searchGuidance('milk', storage: 'Pantry'), isEmpty);
    expect(searchGuidance('milk', storage: 'Fridge').single.id, 'milk');
  });

  test('unsupported food and storage receive no invented fallback', () {
    expect(searchGuidance('Instant noodles'), isEmpty);
    expect(searchGuidance('', storage: 'Freezer'), isEmpty);
    expect(searchGuidance('raw chicken cooked'), isEmpty);
  });

  testWidgets(
    'offline catalog searches show source, condition and reference-only meaning',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: GuidanceScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Storage references for 16 foods'), findsOneWidget);
      expect(find.textContaining('No suggested date is set.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'mango');
      await tester.pumpAndSettle();
      expect(find.text('Fridge · Up to 5 days'), findsOneWidget);
      expect(
        find.text(
          'Applies to: Whole, ripe mangoes; refrigerate only once ripe',
        ),
        findsOneWidget,
      );
      expect(find.text('Source: National Mango Board'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Instant noodles');
      await tester.pumpAndSettle();
      expect(find.text('0 matching references'), findsOneWidget);
      expect(find.textContaining('No estimate is provided.'), findsOneWidget);
    },
  );

  testWidgets('storage filters keep pantry and fridge conditions separate', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GuidanceScreen(foodName: 'milk', storage: 'Pantry'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('0 matching references'), findsOneWidget);
    await tester.tap(find.text('Fridge'));
    await tester.pumpAndSettle();
    expect(find.text('1 matching references'), findsOneWidget);
    expect(find.text('Fridge · 1 week'), findsOneWidget);
    await tester.ensureVisible(find.text('Source details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Source details'));
    await tester.pumpAndSettle();
    expect(
      find.text('Page 4 · Dairy · Milk, plain or flavored'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Freezer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Freezer'));
    await tester.pumpAndSettle();
    expect(find.text('0 matching references'), findsOneWidget);
  });

  testWidgets('batch guidance preserves printed date, stock, and history', (
    tester,
  ) async {
    final database = InventoryDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.addBatch(
      BatchDraft(
        name: 'Milk',
        quantity: 500,
        unit: 'mL',
        storage: 'Fridge',
        printedDate: '2026-11-12',
      ),
    );
    await tester.pumpWidget(FreshKeepApp(database: database));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('View batch details'));
    await tester.tap(find.byTooltip('View batch details'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Storage guidance'));
    await tester.tap(find.text('Storage guidance'));
    await tester.pumpAndSettle();
    expect(find.text('1 matching references'), findsOneWidget);
    expect(find.textContaining('No suggested date is set.'), findsOneWidget);
    final batch = (await database.loadBatches()).single;
    expect(batch.draft.printedDate, '2026-11-12');
    expect(batch.remaining, 500);
    expect(await database.loadHistory(batch.id), isEmpty);
    expect(await database.disposedQuantity(batch.id), 0);
    await tester.pumpWidget(const SizedBox());
  });
}
