import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshkeep/data/inventory_database.dart';
import 'package:freshkeep/domain/batch.dart';
import 'package:freshkeep/domain/dashboard_summary.dart';
import 'package:freshkeep/domain/inventory_report.dart';
import 'package:freshkeep/domain/stock_event.dart';
import 'package:freshkeep/domain/waste_query.dart';
import 'package:freshkeep/report_screen.dart';
import 'package:freshkeep/widgets/local_day_scope.dart';

void main() {
  test('DashboardSummary groups date attention, storage counts and top reasons accurately', () {
    final now = DateTime(2026, 11, 10, 10, 0);
    final report = InventoryReport(
      batches: [
        InventoryBatch(
          id: 1,
          remaining: 2,
          draft: BatchDraft(
            name: 'Past Bread',
            quantity: 2,
            unit: 'pieces',
            storage: 'Pantry',
            printedDate: '2026-11-09',
          ),
        ),
        InventoryBatch(
          id: 2,
          remaining: 1,
          draft: BatchDraft(
            name: 'Sushi',
            quantity: 1,
            unit: 'pieces',
            storage: 'Fridge',
            printedDate: '2026-11-10',
            printedTime: '14:00',
          ),
        ),
        InventoryBatch(
          id: 3,
          remaining: 1,
          draft: BatchDraft(
            name: 'Milk',
            quantity: 500,
            unit: 'mL',
            storage: 'Fridge',
            printedDate: '2026-11-12',
          ),
        ),
        InventoryBatch(
          id: 4,
          remaining: 1,
          draft: BatchDraft(
            name: 'Peas',
            quantity: 400,
            unit: 'g',
            storage: 'Freezer',
            printedDate: '2026-11-25',
          ),
        ),
        InventoryBatch(
          id: 5,
          remaining: 1,
          draft: BatchDraft(
            name: 'Rice',
            quantity: 500,
            unit: 'g',
            storage: 'Pantry',
          ),
        ),
        InventoryBatch(
          id: 6,
          remaining: 0,
          draft: BatchDraft(
            name: 'Used Eggs',
            quantity: 6,
            unit: 'pieces',
            storage: 'Fridge',
            printedDate: '2026-11-01',
          ),
        ),
      ],
      disposals: [
        WasteEntry(
          id: 1,
          batchId: 1,
          food: 'Bread',
          quantity: 1,
          unit: 'pieces',
          reason: 'Moldy',
          createdAt: DateTime.utc(2026, 11, 9),
        ),
        WasteEntry(
          id: 2,
          batchId: 3,
          food: 'Milk',
          quantity: 100,
          unit: 'mL',
          reason: 'Expired',
          createdAt: DateTime.utc(2026, 11, 10),
        ),
        WasteEntry(
          id: 3,
          batchId: 1,
          food: 'Bread',
          quantity: 1,
          unit: 'pieces',
          reason: 'Moldy',
          createdAt: DateTime.utc(2026, 11, 10),
        ),
      ],
    );

    final summary = DashboardSummary.fromReport(report, now);
    expect(summary.pastCount, 1);
    expect(summary.urgentCount, 1);
    expect(summary.soonCount, 1);
    expect(summary.laterCount, 1);
    expect(summary.unknownCount, 1);
    expect(summary.attentionCount, 3);
    expect(summary.byStorage, {'Pantry': 2, 'Fridge': 2, 'Freezer': 1});
    expect(summary.topReasons.map((r) => (r.reason, r.count)), [
      ('Moldy', 2),
      ('Expired', 1),
    ]);
  });

  test('queryWasteLog filters by search, unit, reason, date range and sorts cleanly', () {
    final now = DateTime(2026, 11, 20, 12, 0);
    final entries = [
      WasteEntry(
        id: 1,
        batchId: 1,
        food: 'Rice',
        quantity: 250,
        unit: 'g',
        reason: 'Spilled',
        createdAt: DateTime(2026, 10, 1, 9, 0).toUtc(),
      ),
      WasteEntry(
        id: 2,
        batchId: 2,
        food: 'Milk',
        quantity: 500,
        unit: 'mL',
        reason: 'Expired',
        createdAt: DateTime(2026, 11, 10, 9, 0).toUtc(),
      ),
      WasteEntry(
        id: 3,
        batchId: 3,
        food: 'Apple',
        quantity: 2,
        unit: 'pieces',
        reason: 'Unspecified',
        createdAt: DateTime(2026, 11, 18, 9, 0).toUtc(),
      ),
      WasteEntry(
        id: 4,
        batchId: 4,
        food: 'Bread',
        quantity: 4,
        unit: 'pieces',
        reason: 'Moldy',
        createdAt: DateTime(2026, 11, 19, 9, 0).toUtc(),
      ),
    ];

    expect(distinctWasteReasons(entries), [
      'Expired',
      'Moldy',
      'Spilled',
      'Unspecified',
    ]);
    expect(queryWasteLog(entries, now, search: 'spilled').map((e) => e.id), [1]);
    expect(queryWasteLog(entries, now, unit: 'pieces').map((e) => e.id), [3, 4]);
    expect(
      queryWasteLog(entries, now, reason: 'moldy').map((e) => e.id),
      [4],
    );
    expect(
      queryWasteLog(
        entries,
        now,
        dateRange: WasteDateRange.last7Days,
      ).map((e) => e.id),
      [3, 4],
    );
    expect(
      queryWasteLog(
        entries,
        now,
        dateRange: WasteDateRange.last30Days,
      ).map((e) => e.id),
      [2, 3, 4],
    );
    expect(
      queryWasteLog(entries, now, sort: WasteSort.newest).map((e) => e.id),
      [4, 3, 2, 1],
    );
    expect(
      queryWasteLog(entries, now, sort: WasteSort.oldest).map((e) => e.id),
      [1, 2, 3, 4],
    );
    expect(
      queryWasteLog(entries, now, sort: WasteSort.largestQty).map((e) => e.id),
      [2, 1, 4, 3],
    );
    expect(
      queryWasteLog(entries, now, sort: WasteSort.foodName).map((e) => e.id),
      [3, 4, 2, 1],
    );
    expect(wasteTotalsByUnit(entries), {'pieces': 6, 'g': 250, 'mL': 500});
  });

  testWidgets('redesigned dashboard and waste log search/filter/reset cleanly without mutating DB', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = InventoryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.addBatches([
      BatchDraft(
        name: 'Rice',
        quantity: 1000,
        unit: 'g',
        storage: 'Pantry',
      ),
      BatchDraft(
        name: 'Eggs',
        quantity: 6,
        unit: 'pieces',
        storage: 'Fridge',
        printedDate: '2026-11-02',
      ),
    ]);
    final batches = await db.loadBatches();
    final eggs = batches.firstWhere((b) => b.draft.name == 'Eggs');
    final rice = batches.firstWhere((b) => b.draft.name == 'Rice');
    await db.recordAction(rice.id, StockAction.dispose, 150, reason: 'Spilled');
    await db.recordAction(eggs.id, StockAction.dispose, 2, reason: 'Cracked');

    await tester.pumpWidget(
      LocalDayScope(
        now: () => DateTime(2026, 11, 1, 12, 0),
        child: MaterialApp(home: ReportScreen(database: db)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kitchen overview'), findsOneWidget);
    expect(find.text('Date attention'), findsOneWidget);
    expect(find.text('Quantities by unit'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Top waste reasons'), 200);
    expect(find.text('Top waste reasons'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(find.text('Open waste log'), 200);
    await tester.tap(find.text('Open waste log'));
    await tester.pumpAndSettle();

    expect(find.text('2 disposal events'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Search waste log'),
      'spilled',
    );
    await tester.pumpAndSettle();
    expect(find.text('Showing 1 of 2 disposal events'), findsOneWidget);
    expect(find.text('Rice'), findsOneWidget);
    expect(find.text('Eggs'), findsNothing);

    await tester.tap(find.text('Filters and sort'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All units'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('pieces').last);
    await tester.pumpAndSettle();

    expect(
      find.text('No waste entries match your search and filters.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Reset filters').last);
    await tester.pumpAndSettle();
    expect(find.text('Rice'), findsOneWidget);
    expect(find.text('Eggs'), findsOneWidget);
    expect((await db.loadReport()).disposals, hasLength(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
