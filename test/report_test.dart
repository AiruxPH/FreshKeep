import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshkeep/data/inventory_database.dart';
import 'package:freshkeep/domain/batch.dart';
import 'package:freshkeep/domain/stock_event.dart';
import 'package:freshkeep/main.dart';
import 'package:freshkeep/report_screen.dart';

class RecoverableDatabase extends InventoryDatabase {
  RecoverableDatabase() : super(NativeDatabase.memory());
  bool fail = true;
  @override
  loadReport() => fail
      ? Future.error(StateError('Simulated read failure'))
      : super.loadReport();
}

void main() {
  late InventoryDatabase database;
  setUp(() => database = InventoryDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  Future<int> add(String name, int qty, String unit) async {
    await database.addBatch(
      BatchDraft(name: name, quantity: qty, unit: unit, storage: 'Pantry'),
    );
    return (await database.loadBatches()).first.id;
  }

  Future<void> seed() async {
    final eggs = await add('Eggs', 6, 'pieces');
    await database.recordAction(eggs, StockAction.dispose, 2);
    await database.recordAction(eggs, StockAction.consume, 1);
    await database.recordAction(eggs, StockAction.correct, 5);
    final rice = await add('Rice', 1000, 'g');
    await database.recordAction(
      rice,
      StockAction.dispose,
      100,
      reason: 'Spilled',
    );
    final milk = await add('Milk', 500, 'mL');
    await database.recordAction(milk, StockAction.dispose, 50);
    await database.undoEvent(milk, (await database.loadHistory(milk)).first.id);
    final bread = await add('Bread', 1, 'pieces');
    await database.recordAction(bread, StockAction.dispose, 1);
  }

  test(
    'empty reports return zero counts and separate zero unit totals',
    () async {
      final report = await database.loadReport();
      expect(report.batches, isEmpty);
      expect(report.activeBatches, 0);
      expect(report.depletedBatches, 0);
      expect(report.disposals, isEmpty);
      expect(report.remainingByUnit, {'pieces': 0, 'g': 0, 'mL': 0});
      expect(report.disposedByUnit, {'pieces': 0, 'g': 0, 'mL': 0});
    },
  );

  test('known dataset groups units and excludes consumption, corrections and undone disposals', () async {
    await seed();
    final report = await database.loadReport();
    expect(report.batches, hasLength(4));
    expect(report.activeBatches, 3);
    expect(report.depletedBatches, 1);
    expect(report.remainingByUnit, {'pieces': 5, 'g': 900, 'mL': 500});
    expect(report.disposedByUnit, {'pieces': 3, 'g': 100, 'mL': 0});
    expect(report.disposals.map((entry) => entry.food), [
      'Bread',
      'Rice',
      'Eggs',
    ]);
    expect(report.disposals[1].reason, 'Spilled');
    expect(report.disposals.last.reason, 'Unspecified');
    expect(report.disposals.every((entry) => entry.createdAt.isUtc), isTrue);
    for (final batch in report.batches) {
      expect(
        report.disposals
            .where((entry) => entry.batchId == batch.id)
            .fold<int>(0, (total, entry) => total + entry.quantity),
        await database.disposedQuantity(batch.id),
      );
    }
  });

  test(
    'same food in separate batches aggregates only compatible units',
    () async {
      final first = await add('Rice', 1000, 'g');
      final second = await add('Rice', 500, 'g');
      await add('Rice', 2, 'pieces');
      await database.recordAction(first, StockAction.dispose, 100);
      await database.recordAction(second, StockAction.dispose, 50);
      final report = await database.loadReport();
      expect(report.remainingByUnit, {'pieces': 2, 'g': 1350, 'mL': 0});
      expect(report.disposedByUnit, {'pieces': 0, 'g': 150, 'mL': 0});
      expect(report.disposals.map((entry) => entry.batchId).toSet(), {
        first,
        second,
      });
    },
  );

  testWidgets(
    'narrow dashboard and waste log refresh after undo through batch history',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await seed();
      await tester.pumpWidget(FreshKeepApp(database: database));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Dashboard'));
      await tester.pumpAndSettle();
      expect(find.text('Quantities by unit'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('900'), 200);
      expect(find.text('900'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Open waste log'), 200);
      await tester.tap(find.text('Open waste log'));
      await tester.pumpAndSettle();
      expect(find.text('3 disposal events'), findsOneWidget);
      expect(find.text('Reason: Spilled'), findsOneWidget);
      expect(find.text('Milk'), findsNothing);
      await tester.tap(find.text('View batch history').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Batch history'));
      await tester.tap(find.text('Batch history'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Undo entry'));
      await tester.tap(find.text('Undo entry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo entry').last);
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('2 disposal events'), findsOneWidget);
      expect(find.text('Bread'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect((await database.loadReport()).activeBatches, 4);
      expect(find.text('0'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('empty waste log and report retry are recoverable', (
    tester,
  ) async {
    final recoverable = RecoverableDatabase();
    addTearDown(recoverable.close);
    await recoverable.addBatch(
      BatchDraft(
        name: 'Saved groceries',
        quantity: 2,
        unit: 'pieces',
        storage: 'Pantry',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: ReportScreen(database: recoverable, wasteLog: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    recoverable.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('0 disposal events'), findsOneWidget);
    expect(find.textContaining('No recorded waste.'), findsOneWidget);
    expect(
      (await recoverable.loadBatches()).single.draft.name,
      'Saved groceries',
    );
  });
}
