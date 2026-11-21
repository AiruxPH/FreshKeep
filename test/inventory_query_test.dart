import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshkeep/data/inventory_database.dart';
import 'package:freshkeep/domain/batch.dart';
import 'package:freshkeep/domain/date_status.dart';
import 'package:freshkeep/domain/inventory_query.dart';
import 'package:freshkeep/inventory_screen.dart';
import 'package:freshkeep/main.dart';
import 'package:freshkeep/widgets/local_day_scope.dart';

void main() {
  InventoryBatch batch(
    int id,
    String name, {
    String storage = 'Fridge',
    String? date,
    int remaining = 2,
  }) => InventoryBatch(
    id: id,
    remaining: remaining,
    draft: BatchDraft(
      name: name,
      quantity: 2,
      unit: 'pieces',
      storage: storage,
      printedDate: date,
    ),
  );
  final now = DateTime(2026, 11, 1, 12);

  test(
    'combines case-insensitive word search, storage, date and stock filters',
    () {
      final batches = [
        batch(1, 'Fresh milk', date: '2026-11-02'),
        batch(2, 'Fresh milk', storage: 'Pantry'),
        batch(3, 'Fresh milk', date: '2026-11-02', remaining: 0),
        batch(4, 'Eggs', date: '2026-11-02'),
      ];
      expect(
        queryInventory(
          batches,
          now,
          search: ' MILK  fresh ',
          storage: 'Fridge',
          status: DateStatus.soon,
          stock: StockFilter.active,
        ).map((b) => b.id),
        [1],
      );
      expect(
        queryInventory(
          batches,
          now,
          search: 'milk',
          stock: StockFilter.depleted,
        ).map((b) => b.id),
        [3],
      );
      expect(
        queryInventory(
          batches,
          now,
          status: DateStatus.unknown,
        ).map((b) => b.id),
        [2],
      );
      expect(queryInventory(batches, now, search: 'missing'), isEmpty);
    },
  );

  test('soonest date puts past dates first, unknown last, and ties newest first without mutating input', () {
    final batches = [
      batch(1, 'Unknown'),
      batch(2, 'Future', date: '2026-11-08'),
      batch(3, 'Past', date: '2026-10-31'),
      batch(4, 'Same date', date: '2026-11-08'),
      batch(5, 'Unknown two'),
    ];
    expect(
      queryInventory(
        batches,
        now,
        sort: InventorySort.soonestDate,
      ).map((b) => b.id),
      [3, 4, 2, 5, 1],
    );
    expect(batches.map((b) => b.id), [1, 2, 3, 4, 5]);
    expect(queryInventory(batches, now).map((b) => b.id), [5, 4, 3, 2, 1]);
  });

  test('name sorting is case-insensitive and date filters change with the local calendar', () {
    final batches = [
      batch(1, 'banana', date: '2026-11-01'),
      batch(2, 'apple'),
      batch(3, 'APPLE'),
    ];
    expect(
      queryInventory(batches, now, sort: InventorySort.name).map((b) => b.id),
      [3, 2, 1],
    );
    expect(
      queryInventory(batches, now, status: DateStatus.today).map((b) => b.id),
      [1],
    );
    expect(
      queryInventory(batches, DateTime(2026, 11, 2), status: DateStatus.today),
      isEmpty,
    );
    expect(
      queryInventory(
        batches,
        DateTime(2026, 11, 2),
        status: DateStatus.past,
      ).map((b) => b.id),
      [1],
    );
  });

  testWidgets(
    'search/filter combinations show no matches and reset without changing records',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = InventoryDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.addBatches([
        BatchDraft(
          name: 'Milk',
          quantity: 2,
          unit: 'pieces',
          storage: 'Fridge',
          printedDate: '2060-11-02',
        ),
        BatchDraft(
          name: 'Milk',
          quantity: 1,
          unit: 'pieces',
          storage: 'Pantry',
        ),
        BatchDraft(
          name: 'Bread',
          quantity: 1,
          unit: 'pieces',
          storage: 'Pantry',
        ),
      ]);
      await tester.pumpWidget(FreshKeepApp(database: db));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search inventory'),
        'MILK',
      );
      await tester.pumpAndSettle();
      expect(find.text('Showing 2 of 3 batches'), findsOneWidget);
      await tester.ensureVisible(find.text('Filters and sort'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filters and sort'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('All storage'));
      await tester.tap(find.text('All storage'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fridge').last);
      await tester.pumpAndSettle();
      expect(find.text('Showing 1 of 3 batches'), findsOneWidget);
      await tester.ensureVisible(find.text('All dates'));
      await tester.tap(find.text('All dates'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Date unknown').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Show all batches'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('No batches match your search and filters.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Show all batches'));
      await tester.pumpAndSettle();
      expect(find.text('Showing 3 of 3 batches'), findsOneWidget);
      expect(await db.loadBatches(), hasLength(3));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'search and active-only filter survive returning after depletion',
    (tester) async {
      final db = InventoryDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.addBatches([
        BatchDraft(
          name: 'Milk',
          quantity: 2,
          unit: 'pieces',
          storage: 'Fridge',
        ),
        BatchDraft(
          name: 'Milk',
          quantity: 1,
          unit: 'pieces',
          storage: 'Pantry',
        ),
      ]);
      await tester.pumpWidget(FreshKeepApp(database: db));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search inventory'),
        'milk',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Filters and sort'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filters and sort'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Active only'));
      await tester.tap(find.text('Active only'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Active only').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Filters and sort'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filters and sort'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('View batch details').first);
      await tester.tap(find.byTooltip('View batch details').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '1');
      await tester.tap(find.byKey(const ValueKey('confirm-stock-action')));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Showing 1 of 2 batches'), findsOneWidget);
      expect(find.text('milk'), findsOneWidget);
      expect((await db.loadBatches()).where((b) => b.depleted), hasLength(1));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'selected date filter refreshes at midnight without changing inventory',
    (tester) async {
      final db = InventoryDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      var clock = DateTime(2026, 11, 1, 23, 59, 59);
      await db.addBatch(
        BatchDraft(
          name: 'Eggs',
          quantity: 2,
          unit: 'pieces',
          storage: 'Fridge',
          printedDate: '2026-11-01',
        ),
      );
      await tester.pumpWidget(
        LocalDayScope(
          now: () => clock,
          child: MaterialApp(home: InventoryScreen(database: db)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Filters and sort'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filters and sort'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('All dates'));
      await tester.tap(find.text('All dates'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Today').last);
      await tester.pumpAndSettle();
      expect(find.text('Showing 1 of 1 batch'), findsOneWidget);
      clock = DateTime(2026, 11, 2, 0, 0, 1);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Showing 0 of 1 batch'), findsOneWidget);
      expect((await db.loadBatches()).single.remaining, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
