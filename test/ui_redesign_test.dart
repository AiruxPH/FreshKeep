import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshkeep/data/inventory_database.dart';
import 'package:freshkeep/domain/batch.dart';
import 'package:freshkeep/domain/stock_event.dart';
import 'package:freshkeep/main.dart';

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<int> seed(InventoryDatabase db) async {
    await db.addBatch(
      BatchDraft(name: 'Eggs', quantity: 3, unit: 'pieces', storage: 'Fridge'),
    );
    return (await db.loadBatches()).single.id;
  }

  testWidgets(
    'phone navigation is labeled, food appears early and tools are discoverable',
    (tester) async {
      phone(tester);
      final db = InventoryDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final id = await seed(db);
      await tester.pumpWidget(FreshKeepApp(database: db));
      await tester.pumpAndSettle();
      for (final label in ['Inventory', 'Dashboard', 'Waste', 'More']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(
        tester.getTopLeft(find.byKey(ValueKey('batch-$id'))).dy,
        lessThan(844 / 2),
      );
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.text('Reminders'), findsOneWidget);
      expect(find.text('Storage guidance'), findsOneWidget);
      await tester.tap(find.text('Storage guidance'));
      await tester.pumpAndSettle();
      expect(find.text('Storage references for 16 foods'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inventory'));
      await tester.pumpAndSettle();
      expect(find.text('Eggs'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'quick use and snackbar Undo reverse the exact event while preserving older waste',
    (tester) async {
      phone(tester);
      final db = InventoryDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final id = await seed(db);
      final prior = await db.recordAction(id, StockAction.dispose, 1);
      await tester.pumpWidget(FreshKeepApp(database: db));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use'));
      await tester.pumpAndSettle();
      expect(find.text('Use food'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '2');
      await tester.tap(find.byKey(const ValueKey('confirm-stock-action')));
      await tester.pumpAndSettle();
      expect((await db.loadBatch(id)).remaining, 0);
      expect(find.byKey(ValueKey('batch-$id')), findsNothing);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect((await db.loadBatch(id)).remaining, 2);
      expect(await db.disposedQuantity(id), 1);
      final history = await db.loadHistory(id);
      expect(history.last.id, prior);
      expect(history.last.reversed, isFalse);
      expect(history[1].type, 'consume');
      expect(history[1].reversed, isTrue);
      expect(find.byKey(ValueKey('batch-$id')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'full-screen multi-entry keeps Save above the keyboard and saves independently',
    (tester) async {
      phone(tester);
      final db = InventoryDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.pumpWidget(FreshKeepApp(database: db));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add groceries'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      await tester.enterText(find.byType(TextFormField).at(0), 'Eggs');
      await tester.enterText(find.byType(TextFormField).at(1), '2');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(
        tester.getBottomRight(find.byKey(const ValueKey('save-groceries'))).dy,
        lessThanOrEqualTo(544),
      );
      await tester.ensureVisible(find.byKey(const ValueKey('add-grocery-row')));
      await tester.tap(find.byKey(const ValueKey('add-grocery-row')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(2), 'Bread');
      expect(
        tester.getBottomRight(find.byKey(const ValueKey('save-groceries'))).dy,
        lessThanOrEqualTo(544),
      );
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-groceries')));
      await tester.pumpAndSettle();
      final batches = await db.loadBatches();
      expect(batches, hasLength(2));
      expect(batches.map((b) => b.draft.name), ['Bread', 'Eggs']);
      expect(batches.map((b) => b.remaining), [1, 2]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'returning to Inventory from another tab refreshes saved details',
    (tester) async {
      phone(tester);
      final db = InventoryDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final id = await seed(db);
      final before = (await db.loadBatch(id)).draft;
      await tester.pumpWidget(FreshKeepApp(database: db));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();
      await db.editBatchDetails(
        id,
        BatchDetailsDraft(name: 'Brown eggs', storage: 'Fridge'),
        expected: before,
      );
      await tester.tap(find.text('Inventory'));
      await tester.pumpAndSettle();
      expect(find.text('Brown eggs'), findsOneWidget);
      expect(find.text('Eggs'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('large phone text and wide-screen navigation remain usable', (
    tester,
  ) async {
    phone(tester);
    final db = InventoryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seed(db);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(FreshKeepApp(database: db));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('Reminders'), findsOneWidget);
    expect(tester.takeException(), isNull);
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.view.physicalSize = const Size(1280, 900);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    await tester.tap(find.text('Inventory'));
    await tester.pumpAndSettle();
    expect(find.text('Eggs'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
