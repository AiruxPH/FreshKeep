import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshkeep/data/inventory_database.dart';
import 'package:freshkeep/domain/batch.dart';
import 'package:freshkeep/domain/reminder.dart';
import 'package:freshkeep/domain/stock_event.dart';
import 'package:freshkeep/main.dart';
import 'package:freshkeep/reminders/notification_service.dart';
import 'package:freshkeep/reminders/reminder_controller.dart';

class EditTestNotifications implements NotificationService {
  List<PlannedReminder> scheduled = [];
  Completer<void>? changed;
  @override
  bool get supported => true;
  @override
  Future<String> replace(
    List<PlannedReminder> plan, {
    required bool enabled,
    bool requestPermission = false,
  }) async {
    scheduled = List.of(plan);
    if (changed != null && !changed!.isCompleted) changed!.complete();
    return 'Synchronized';
  }

  @override
  Future<void> sendTest() async {}
}

void main() {
  Future<InventoryBatch> seed(InventoryDatabase db) async {
    await db.addBatch(
      BatchDraft(
        name: 'Eggs',
        quantity: 6,
        unit: 'pieces',
        storage: 'Pantry',
        printedDate: '2026-11-04',
      ),
    );
    return (await db.loadBatches()).single;
  }

  test(
    'details edits preserve stock and waste with append-only audit history',
    () async {
      final db = InventoryDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final before = await seed(db);
      await db.recordAction(before.id, StockAction.dispose, 2);
      await db.editBatchDetails(
        before.id,
        BatchDetailsDraft(name: ' Brown eggs ', storage: 'Fridge'),
        expected: before.draft,
      );
      final after = await db.loadBatch(before.id);
      expect(after.draft.name, 'Brown eggs');
      expect(after.draft.printedDate, isNull);
      expect(after.draft.storage, 'Fridge');
      expect(after.draft.quantity, 6);
      expect(after.draft.unit, 'pieces');
      expect(after.remaining, 4);
      expect(await db.disposedQuantity(before.id), 2);
      expect(await db.loadHistory(before.id), hasLength(1));
      final edits = await db.loadDetailsHistory(before.id);
      expect(edits, hasLength(1));
      expect(edits.single.before.name, 'Eggs');
      expect(edits.single.before.printedDate, '2026-11-04');
      expect(edits.single.after.printedDate, isNull);
      expect(edits.single.createdAt.isUtc, isTrue);
      expect((await db.loadReport()).disposals.single.food, 'Brown eggs');
      await expectLater(
        db.customStatement('UPDATE batch_edits SET new_name=old_name'),
        throwsA(anything),
      );
      await expectLater(
        db.customStatement('DELETE FROM batch_edits'),
        throwsA(anything),
      );
    },
  );

  test('stale details are rejected and no-op edits add no history', () async {
    final db = InventoryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final before = await seed(db);
    await db.editBatchDetails(
      before.id,
      BatchDetailsDraft(
        name: 'Eggs',
        storage: 'Pantry',
        printedDate: '2026-11-04',
      ),
      expected: before.draft,
    );
    expect(await db.loadDetailsHistory(before.id), isEmpty);
    await db.editBatchDetails(
      before.id,
      BatchDetailsDraft(name: 'New name', storage: 'Fridge'),
      expected: before.draft,
    );
    await expectLater(
      db.editBatchDetails(
        before.id,
        BatchDetailsDraft(name: 'Stale name', storage: 'Freezer'),
        expected: before.draft,
      ),
      throwsA(isA<StockValidationException>()),
    );
    expect((await db.loadBatch(before.id)).draft.name, 'New name');
    expect(await db.loadDetailsHistory(before.id), hasLength(1));
  });

  test(
    'audit insert failure rolls back the detail update atomically',
    () async {
      final db = InventoryDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final before = await seed(db);
      await db.customStatement(
        "CREATE TRIGGER fail_edit BEFORE INSERT ON batch_edits BEGIN SELECT RAISE(ABORT,'Simulated failure'); END",
      );
      await expectLater(
        db.editBatchDetails(
          before.id,
          BatchDetailsDraft(name: 'Failed edit', storage: 'Fridge'),
          expected: before.draft,
        ),
        throwsA(anything),
      );
      final after = await db.loadBatch(before.id);
      expect(after.draft.name, 'Eggs');
      expect(after.draft.printedDate, '2026-11-04');
      expect(after.draft.storage, 'Pantry');
      expect(await db.loadDetailsHistory(before.id), isEmpty);
    },
  );

  test(
    'v3 migration and reopen retain preferences, stock and new detail history',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'freshkeep_edit_',
      );
      final file = File('${directory.path}/db.sqlite');
      var db = InventoryDatabase(NativeDatabase(file));
      try {
        final before = await seed(db);
        await db.saveReminderSettings(ReminderSettings(enabled: true, hour: 8));
        await db.recordAction(before.id, StockAction.consume, 1);
        await db.customStatement('DROP TABLE batch_edits');
        await db.customStatement('DROP TABLE batch_photos');
        await db.customStatement('ALTER TABLE batches DROP COLUMN printed_time');
        await db.customStatement('PRAGMA user_version=3');
        await db.close();
        db = InventoryDatabase(NativeDatabase(file));
        await db.editBatchDetails(
          before.id,
          BatchDetailsDraft(
            name: 'Eggs',
            storage: 'Fridge',
            printedDate: '2026-11-08',
          ),
          expected: before.draft,
        );
        await db.close();
        db = InventoryDatabase(NativeDatabase(file));
        expect((await db.loadBatch(before.id)).remaining, 5);
        expect((await db.loadReminderSettings()).hour, 8);
        expect((await db.loadReminderSettings()).enabled, isTrue);
        expect((await db.loadBatch(before.id)).draft.printedDate, '2026-11-08');
        expect(await db.loadHistory(before.id), hasLength(1));
        expect(await db.loadDetailsHistory(before.id), hasLength(1));
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test('committed date/name edits replace reminders and clearing date cancels them', () async {
    final db = InventoryDatabase(NativeDatabase.memory());
    final service = EditTestNotifications();
    final controller = ReminderController(
      db,
      service,
      now: () => DateTime(2026, 11, 1, 8),
    );
    try {
      final before = await seed(db);
      await controller.start();
      await controller.save(ReminderSettings(enabled: true));
      expect(service.scheduled, hasLength(4));
      service.changed = Completer<void>();
      await db.editBatchDetails(
        before.id,
        BatchDetailsDraft(
          name: 'New eggs',
          storage: 'Fridge',
          printedDate: '2026-11-08',
        ),
        expected: before.draft,
      );
      await service.changed!.future.timeout(const Duration(seconds: 3));
      expect(
        service.scheduled.every(
          (r) => r.food == 'New eggs' && r.printedDate == '2026-11-08',
        ),
        isTrue,
      );
      final current = await db.loadBatch(before.id);
      service.changed = Completer<void>();
      await db.editBatchDetails(
        before.id,
        BatchDetailsDraft(name: 'New eggs', storage: 'Fridge'),
        expected: current.draft,
      );
      await service.changed!.future.timeout(const Duration(seconds: 3));
      expect(service.scheduled, isEmpty);
      expect(await db.disposedQuantity(before.id), 0);
    } finally {
      controller.dispose();
      await db.close();
    }
  });

  testWidgets(
    'editor cancels cleanly, validates names and refreshes inventory after saving',
    (tester) async {
      final db = InventoryDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final before = await seed(db);
      await db.recordAction(before.id, StockAction.dispose, 2);
      await tester.pumpWidget(FreshKeepApp(database: db));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('View batch details'));
      await tester.tap(find.byTooltip('View batch details'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit batch details'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Starting quantity and unit stay fixed.'),
        findsOneWidget,
      );
      expect(find.byType(TextFormField), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Cancelled');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect((await db.loadBatch(before.id)).draft.name, 'Eggs');
      expect(await db.loadDetailsHistory(before.id), isEmpty);
      await tester.tap(find.byTooltip('Edit batch details'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a food name.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Brown eggs');
      await tester.ensureVisible(find.text('Clear date'));
      await tester.tap(find.text('Clear date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.text('Date unknown'), findsOneWidget);
      expect(find.text('4 pieces remaining'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Details history'), 200);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Details history'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Details updated'));
      await tester.pumpAndSettle();
      expect(find.text('Details updated'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Brown eggs'), findsOneWidget);
      expect(find.text('4 pieces'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
