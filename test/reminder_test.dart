import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshkeep/data/inventory_database.dart';
import 'package:freshkeep/domain/batch.dart';
import 'package:freshkeep/domain/reminder.dart';
import 'package:freshkeep/domain/stock_event.dart';
import 'package:freshkeep/reminder_screen.dart';
import 'package:freshkeep/reminders/notification_service.dart';
import 'package:freshkeep/reminders/reminder_controller.dart';

class FakeNotifications implements NotificationService {
  List<PlannedReminder> scheduled = [];
  bool fail = false;
  bool permissionRequested = false;
  Completer<void>? replaced;
  @override
  bool get supported => true;
  @override
  Future<String> replace(
    List<PlannedReminder> plan, {
    required bool enabled,
    bool requestPermission = false,
  }) async {
    if (fail) throw StateError('Simulated platform failure');
    permissionRequested = requestPermission;
    scheduled = List.of(plan);
    if (replaced != null && !replaced!.isCompleted) replaced!.complete();
    return enabled ? 'Test schedule synchronized.' : 'Reminders are off.';
  }

  @override
  Future<void> sendTest() async {}
}

void main() {
  InventoryBatch batch(
    int id, {
    String? date = '2026-11-04',
    String? time,
    int remaining = 2,
  }) => InventoryBatch(
    id: id,
    remaining: remaining,
    draft: BatchDraft(
      name: 'Food $id',
      quantity: 2,
      unit: 'pieces',
      storage: 'Fridge',
      printedDate: date,
      printedTime: time,
    ),
  );

  test('plans calendar lead days through date day with stable unique IDs', () {
    final plan = planReminders(
      [batch(1), batch(2)],
      ReminderSettings(hour: 9),
      DateTime(2026, 11, 1, 8),
    );
    expect(plan, hasLength(8));
    expect(plan.map((r) => r.id).toSet(), hasLength(8));
    expect(plan.first.at, DateTime(2026, 11, 1, 9));
    expect(plan.last.at, DateTime(2026, 11, 4, 9));
    expect(
      planReminders(
        [batch(1)],
        ReminderSettings(leadDays: 1),
        DateTime(2026, 11, 1),
      ),
      hasLength(2),
    );
  });

  test('excludes unknown, past, depleted and already elapsed alert times', () {
    final now = DateTime(2026, 11, 4, 10);
    expect(
      planReminders(
        [
          batch(1, date: null),
          batch(2, date: '2026-11-03'),
          batch(3, remaining: 0),
          batch(4),
        ],
        ReminderSettings(),
        now,
      ),
      isEmpty,
    );
    final future = planReminders(
      [batch(5, date: '2026-11-05')],
      ReminderSettings(hour: 9),
      now,
    );
    expect(future, hasLength(1));
    expect(future.single.at, DateTime(2026, 11, 5, 9));
  });

  test('handles leap/year boundaries using local calendar dates', () {
    final leap = planReminders(
      [batch(1, date: '2028-03-01')],
      ReminderSettings(leadDays: 1),
      DateTime(2028, 2, 28),
    );
    expect(leap.first.at, DateTime(2028, 2, 29, 9));
    final year = planReminders(
      [batch(2, date: '2027-01-01')],
      ReminderSettings(leadDays: 1),
      DateTime(2026, 12, 30),
    );
    expect(year.first.at, DateTime(2026, 12, 31, 9));
    expect(() => ReminderSettings(hour: 24), throwsArgumentError);
    expect(() => ReminderSettings(minute: 60), throwsArgumentError);
    expect(() => ReminderSettings(leadDays: 2), throwsArgumentError);
  });

  test(
    'settings persist across reopen and v2 upgrade preserves stock/history',
    () async {
      final dir = await Directory.systemTemp.createTemp('freshkeep_reminders_');
      final file = File('${dir.path}/db.sqlite');
      var db = InventoryDatabase(NativeDatabase(file));
      try {
        await db.addBatch(
          BatchDraft(
            name: 'Milk',
            quantity: 3,
            unit: 'pieces',
            storage: 'Fridge',
            printedDate: '2026-11-04',
          ),
        );
        final id = (await db.loadBatches()).single.id;
        await db.recordAction(id, StockAction.consume, 1);
        await db.customStatement('DROP TABLE reminder_settings');
        await db.customStatement('DROP TABLE batch_edits');
        await db.customStatement('DROP TABLE batch_photos');
        await db.customStatement('ALTER TABLE batches DROP COLUMN printed_time');
        await db.customStatement('PRAGMA user_version=2');
        await db.close();
        db = InventoryDatabase(NativeDatabase(file));
        expect((await db.loadReminderSettings()).enabled, isFalse);
        expect((await db.loadBatch(id)).remaining, 2);
        expect(await db.loadHistory(id), hasLength(1));
        await db.saveReminderSettings(
          ReminderSettings(enabled: true, hour: 7, minute: 45, leadDays: 1),
        );
        await db.close();
        db = InventoryDatabase(NativeDatabase(file));
        final settings = await db.loadReminderSettings();
        expect(
          [settings.enabled, settings.hour, settings.minute, settings.leadDays],
          [true, 7, 45, 1],
        );
        expect((await db.loadBatch(id)).remaining, 2);
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test('sync clears alerts after depletion, restores on undo, and cancels when disabled', () async {
    final db = InventoryDatabase(NativeDatabase.memory());
    final service = FakeNotifications();
    final controller = ReminderController(
      db,
      service,
      now: () => DateTime(2026, 11, 1, 8),
    );
    try {
      await db.addBatch(
        BatchDraft(
          name: 'Milk',
          quantity: 2,
          unit: 'pieces',
          storage: 'Fridge',
          printedDate: '2026-11-04',
        ),
      );
      await controller.start();
      expect(service.scheduled, isEmpty);
      await controller.save(ReminderSettings(enabled: true));
      expect(service.scheduled, hasLength(4));
      expect(service.permissionRequested, isTrue);
      final id = (await db.loadBatches()).single.id;
      service.replaced = Completer<void>();
      await db.recordAction(id, StockAction.consume, 2);
      await service.replaced!.future.timeout(const Duration(seconds: 3));
      expect(service.scheduled, isEmpty);
      await db.undoEvent(id, (await db.loadHistory(id)).first.id);
      await controller.refresh();
      expect(service.scheduled, hasLength(4));
      await controller.save(ReminderSettings(enabled: false));
      expect(service.scheduled, isEmpty);
      expect(controller.plan, hasLength(4));
    } finally {
      controller.dispose();
      await db.close();
    }
  });

  test(
    'platform failure preserves preferences and inventory and supports retry',
    () async {
      final db = InventoryDatabase(NativeDatabase.memory());
      final service = FakeNotifications()..fail = true;
      final controller = ReminderController(db, service);
      try {
        await db.addBatch(
          BatchDraft(
            name: 'Eggs',
            quantity: 2,
            unit: 'pieces',
            storage: 'Fridge',
          ),
        );
        await controller.save(ReminderSettings(enabled: true));
        expect(controller.failed, isTrue);
        expect((await db.loadReminderSettings()).enabled, isTrue);
        expect((await db.loadBatches()).single.remaining, 2);
        service.fail = false;
        await controller.refresh();
        expect(controller.failed, isFalse);
      } finally {
        controller.dispose();
        await db.close();
      }
    },
  );

  testWidgets(
    'web settings save and preview clearly avoid claiming native delivery',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = InventoryDatabase(NativeDatabase.memory());
      final controller = ReminderController(
        db,
        PreviewNotifications(),
        now: () => DateTime(2026, 11, 1, 8),
      );
      addTearDown(() async {
        controller.dispose();
        await db.close();
      });
      await db.addBatch(
        BatchDraft(
          name: 'Milk',
          quantity: 2,
          unit: 'pieces',
          storage: 'Fridge',
          printedDate: '2026-11-04',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ReminderScreen(database: db, controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Web preview'), findsOneWidget);
      expect(find.text('Upcoming alerts · 4'), findsOneWidget);
      expect(find.text('Send test notification'), findsNothing);
      await tester.tap(find.byType(SwitchListTile));
      await tester.ensureVisible(find.text('Save reminder settings'));
      await tester.tap(find.text('Save reminder settings'));
      await tester.pumpAndSettle();
      expect((await db.loadReminderSettings()).enabled, isTrue);
      expect(
        find.textContaining('No device notifications are scheduled'),
        findsOneWidget,
      );
      expect((await db.loadBatches()).single.remaining, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('uses printedTime for expiry-day alert while lead days use settings time', () {
    final plan = planReminders(
      [batch(1, date: '2026-11-04', time: '14:30')],
      ReminderSettings(hour: 9, minute: 0, leadDays: 1),
      DateTime(2026, 11, 3, 8, 0),
    );
    expect(plan, hasLength(2));
    // Lead day (Nov 3) uses settings time 09:00
    expect(plan.first.at, DateTime(2026, 11, 3, 9, 0));
    // Expiry day (Nov 4) uses printedTime 14:30
    expect(plan.last.at, DateTime(2026, 11, 4, 14, 30));
  });

  test('v5 upgrade to v6 adds printed_time and preserves existing rows', () async {
    final dir = await Directory.systemTemp.createTemp('freshkeep_v6_');
    final file = File('${dir.path}/db.sqlite');
    var db = InventoryDatabase(NativeDatabase(file));
    try {
      await db.addBatch(
        BatchDraft(
          name: 'Sushi',
          quantity: 1,
          unit: 'pieces',
          storage: 'Fridge',
          printedDate: '2026-11-20',
          printedTime: '18:00',
        ),
      );
      await db.close();
      // Reopen and verify printedTime persisted
      db = InventoryDatabase(NativeDatabase(file));
      final loaded = (await db.loadBatches()).single;
      expect(loaded.draft.printedDate, '2026-11-20');
      expect(loaded.draft.printedTime, '18:00');

      // Simulate a v5 database (no printed_time column) and verify migration
      await db.close();
      final v5File = File('${dir.path}/v5.sqlite');
      var v5Db = InventoryDatabase(NativeDatabase(v5File));
      await v5Db.customStatement('PRAGMA foreign_keys = OFF');
      await v5Db.customStatement('DROP TABLE batches');
      await v5Db.customStatement('''
        CREATE TABLE batches (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 100),
          starting_qty INTEGER NOT NULL CHECK(starting_qty BETWEEN 1 AND 1000000000),
          unit TEXT NOT NULL CHECK(unit IN ('pieces', 'g', 'mL')),
          storage TEXT NOT NULL CHECK(storage IN ('Pantry', 'Fridge', 'Freezer')),
          printed_date TEXT,
          date_source TEXT NOT NULL CHECK(date_source IN ('printed', 'unknown')),
          created_at TEXT NOT NULL
        )
      ''');
      await v5Db.customStatement(
        "INSERT INTO batches(name,starting_qty,unit,storage,printed_date,date_source,created_at) VALUES('Milk',2,'pieces','Fridge','2026-11-25','printed','2026-11-01T00:00:00Z')",
      );
      await v5Db.customStatement('PRAGMA user_version = 5');
      await v5Db.close();

      v5Db = InventoryDatabase(NativeDatabase(v5File));
      try {
        final migrated = (await v5Db.loadBatches()).single;
        expect(migrated.draft.name, 'Milk');
        expect(migrated.draft.printedDate, '2026-11-25');
        expect(migrated.draft.printedTime, isNull);
      } finally {
        await v5Db.close();
      }
    } finally {
      await db.close();
      await dir.delete(recursive: true);
    }
  });
}
