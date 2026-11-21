import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshkeep/batch_details_screen.dart';
import 'package:freshkeep/data/guidance_catalog.dart';
import 'package:freshkeep/data/inventory_database.dart';
import 'package:freshkeep/domain/batch.dart';
import 'package:freshkeep/domain/date_status.dart';
import 'package:freshkeep/domain/guidance/add_calendar_days.dart';
import 'package:freshkeep/domain/guidance/find_guidance_rule.dart';
import 'package:freshkeep/domain/guidance/guidance_selection.dart';
import 'package:freshkeep/domain/guidance/resolve_effective_date.dart';
import 'package:freshkeep/domain/inventory_query.dart';
import 'package:freshkeep/domain/reminder.dart';
import 'package:freshkeep/domain/stock_event.dart';
import 'package:freshkeep/domain/storage_guidance.dart';
import 'package:freshkeep/widgets/local_day_scope.dart';

void main() {
  test('addCalendarDays crosses month, leap-day and year boundaries', () {
    expect(addCalendarDays('2026-11-28', 4), '2026-12-02');
    expect(addCalendarDays('2028-02-28', 2), '2028-03-01');
    expect(addCalendarDays('2026-12-30', 3), '2027-01-02');
    expect(() => addCalendarDays('2026-02-30', 1), throwsArgumentError);
  });

  test('BatchGuidance computes single and ranged windows and rejects invalid inputs', () {
    final milk = findGuidanceRule('milk')!;
    final milkSelection = BatchGuidance.fromRule(
      rule: milk,
      anchorEvent: 'Opened',
      anchorDate: '2026-11-10',
    );
    expect(milkSelection.suggestedDate, '2026-11-17');
    expect(milkSelection.suggestedEndDate, '2026-11-17');
    expect(milkSelection.hasRange, isFalse);

    final chicken = findGuidanceRule('chicken-raw')!;
    final chickenSelection = BatchGuidance.fromRule(
      rule: chicken,
      anchorEvent: 'Purchased',
      anchorDate: '2026-11-10',
    );
    expect(chickenSelection.suggestedDate, '2026-11-11');
    expect(chickenSelection.suggestedEndDate, '2026-11-12');
    expect(chickenSelection.hasRange, isTrue);

    expect(
      () => BatchGuidance.fromRule(
        rule: milk,
        anchorEvent: '   ',
        anchorDate: '2026-11-10',
      ),
      throwsArgumentError,
    );
    expect(
      () => BatchGuidance.fromRule(
        rule: milk,
        anchorEvent: 'Opened',
        anchorDate: '2026-02-30',
      ),
      throwsArgumentError,
    );
  });

  test('BatchDraft enforces storage match and resolveEffectiveDate keeps printed priority', () {
    final milk = findGuidanceRule('milk')!;
    final fridgeGuidance = BatchGuidance.fromRule(
      rule: milk,
      anchorEvent: 'Opened',
      anchorDate: '2026-11-01',
    );
    expect(
      () => BatchDraft(
        name: 'Milk',
        quantity: 1,
        unit: 'pieces',
        storage: 'Pantry',
        guidance: fridgeGuidance,
      ),
      throwsArgumentError,
    );

    final withBoth = BatchDraft(
      name: 'Milk',
      quantity: 1,
      unit: 'pieces',
      storage: 'Fridge',
      printedDate: '2026-11-05',
      printedTime: '14:00',
      guidance: fridgeGuidance,
    );
    final effBoth = resolveEffectiveDate(withBoth);
    expect(effBoth.source, EffectiveDateSource.printed);
    expect(effBoth.date, '2026-11-05');
    expect(effBoth.time, '14:00');

    final withGuidanceOnly = BatchDraft(
      name: 'Milk',
      quantity: 1,
      unit: 'pieces',
      storage: 'Fridge',
      guidance: fridgeGuidance,
    );
    final effSuggested = resolveEffectiveDate(withGuidanceOnly);
    expect(effSuggested.source, EffectiveDateSource.suggested);
    expect(effSuggested.date, '2026-11-08');
    expect(effSuggested.time, isNull);
  });

  test('inventory query and reminder planning honor suggested dates and clear cleanly', () {
    final milkRule = findGuidanceRule('milk')!;
    final suggestedBatch = InventoryBatch(
      id: 1,
      remaining: 2,
      draft: BatchDraft(
        name: 'Milk',
        quantity: 2,
        unit: 'pieces',
        storage: 'Fridge',
        guidance: BatchGuidance.fromRule(
          rule: milkRule,
          anchorEvent: 'Opened',
          anchorDate: '2026-11-01', // suggested: 2026-11-08
        ),
      ),
    );
    final printedEarlier = InventoryBatch(
      id: 2,
      remaining: 1,
      draft: BatchDraft(
        name: 'Yogurt',
        quantity: 1,
        unit: 'pieces',
        storage: 'Fridge',
        printedDate: '2026-11-06',
      ),
    );

    final now = DateTime(2026, 11, 5, 8);
    expect(
      queryInventory(
        [suggestedBatch, printedEarlier],
        now,
        status: DateStatus.soon,
      ).map((b) => b.id),
      [2, 1],
    );
    expect(
      queryInventory(
        [suggestedBatch, printedEarlier],
        now,
        sort: InventorySort.soonestDate,
      ).map((b) => b.id),
      [2, 1],
    );

    final plan = planReminders(
      [suggestedBatch],
      ReminderSettings(enabled: true, hour: 9, leadDays: 1),
      DateTime(2026, 11, 6, 8),
    );
    expect(plan, hasLength(2));
    expect(plan.first.printedDate, '2026-11-08');
    expect(plan.first.dateSource, 'suggested');
    expect(plan.last.at, DateTime(2026, 11, 8, 9, 0));
  });

  test('v6 upgrade to v7 preserves data and persists/audits/clears batch guidance', () async {
    final dir = await Directory.systemTemp.createTemp('freshkeep_v7_');
    final file = File('${dir.path}/v6.sqlite');
    var db = InventoryDatabase(NativeDatabase(file));
    try {
      await db.customStatement('PRAGMA foreign_keys = OFF');
      await db.customStatement('DROP TABLE batches');
      await db.customStatement('''
        CREATE TABLE batches (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 100),
          starting_qty INTEGER NOT NULL CHECK(starting_qty BETWEEN 1 AND 1000000000),
          unit TEXT NOT NULL CHECK(unit IN ('pieces', 'g', 'mL')),
          storage TEXT NOT NULL CHECK(storage IN ('Pantry', 'Fridge', 'Freezer')),
          printed_date TEXT,
          date_source TEXT NOT NULL CHECK(date_source IN ('printed', 'unknown')),
          printed_time TEXT,
          created_at TEXT NOT NULL
        )
      ''');
      await db.customStatement(
        "INSERT INTO batches(name,starting_qty,unit,storage,printed_date,date_source,printed_time,created_at) VALUES('Sushi',1,'pieces','Fridge','2026-11-20','printed','18:00','2026-11-01T00:00:00Z')",
      );
      await db.customStatement(
        "INSERT INTO batches(name,starting_qty,unit,storage,printed_date,date_source,printed_time,created_at) VALUES('Milk',500,'mL','Fridge',NULL,'unknown',NULL,'2026-11-01T00:00:00Z')",
      );
      await db.customStatement('ALTER TABLE batch_edits DROP COLUMN guidance_change');
      await db.customStatement('PRAGMA user_version = 6');
      await db.close();

      db = InventoryDatabase(NativeDatabase(file));
      final batches = await db.loadBatches();
      expect(batches, hasLength(2));
      final milk = batches.firstWhere((b) => b.draft.name == 'Milk');
      final sushi = batches.firstWhere((b) => b.draft.name == 'Sushi');
      expect(sushi.draft.printedTime, '18:00');
      expect(milk.draft.guidance, isNull);

      final selection = BatchGuidance.fromRule(
        rule: guidanceCatalog.firstWhere((r) => r.id == 'milk'),
        anchorEvent: 'Opened',
        anchorDate: '2026-11-10',
      );
      await db.editBatchDetails(
        milk.id,
        BatchDetailsDraft(name: milk.draft.name, storage: milk.draft.storage),
        expected: milk.draft,
        updateGuidance: true,
        guidance: selection,
      );

      await db.close();
      db = InventoryDatabase(NativeDatabase(file));
      final updated = await db.loadBatch(milk.id);
      expect(updated.draft.guidance?.suggestedDate, '2026-11-17');
      expect(updated.draft.guidance?.anchorEvent, 'Opened');
      expect(
        (await db.loadDetailsHistory(milk.id)).single.guidanceChange,
        contains('Guidance applied: Milk'),
      );

      // Moving Milk to Pantry without clearing Fridge guidance fails atomically.
      await expectLater(
        db.editBatchDetails(
          milk.id,
          BatchDetailsDraft(name: updated.draft.name, storage: 'Pantry'),
          expected: updated.draft,
        ),
        throwsA(isA<StockValidationException>()),
      );
      expect((await db.loadBatch(milk.id)).draft.storage, 'Fridge');

      await db.editBatchDetails(
        milk.id,
        BatchDetailsDraft(name: updated.draft.name, storage: updated.draft.storage),
        expected: updated.draft,
        updateGuidance: true,
        guidance: null,
      );
      expect((await db.loadBatch(milk.id)).draft.guidance, isNull);
      expect(
        (await db.loadDetailsHistory(milk.id)).first.guidanceChange,
        'Guidance cleared',
      );
    } finally {
      await db.close();
      await dir.delete(recursive: true);
    }
  });

  testWidgets('applies and clears calculated storage guidance from BatchDetailsScreen without altering stock', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = InventoryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.addBatch(
      BatchDraft(
        name: 'Milk',
        quantity: 500,
        unit: 'mL',
        storage: 'Fridge',
      ),
    );
    final batchId = (await db.loadBatches()).single.id;
    final todayIso = BatchDraft.dateOnly(DateTime.now());
    final expectedSuggested = addCalendarDays(todayIso, 7);

    await tester.pumpWidget(
      LocalDayScope(
        child: MaterialApp(
          home: BatchDetailsScreen(database: db, batchId: batchId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Date unknown'), findsOneWidget);

    await tester.ensureVisible(find.text('Storage guidance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Storage guidance'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No suggested date is set.'), findsOneWidget);
    await tester.ensureVisible(find.text('Use to calculate suggested date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use to calculate suggested date'));
    await tester.pumpAndSettle();

    final saveBtn = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save suggested date'),
    );
    expect(saveBtn.onPressed, isNull);

    await tester.tap(find.text('Select starting date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(
      find.text('Suggested review date: $expectedSuggested'),
      findsOneWidget,
    );
    await tester.tap(find.text('Save suggested date'));
    await tester.pumpAndSettle();

    expect(find.text('Suggested date · $expectedSuggested'), findsOneWidget);
    expect(find.text('Suggested storage guidance'), findsOneWidget);
    final afterSave = await db.loadBatch(batchId);
    expect(afterSave.remaining, 500);
    expect(await db.loadHistory(batchId), isEmpty);
    expect(await db.disposedQuantity(batchId), 0);

    await tester.ensureVisible(find.text('Clear suggested date'));
    await tester.tap(find.text('Clear suggested date'));
    await tester.pumpAndSettle();

    expect(find.text('Date unknown'), findsOneWidget);
    expect(find.text('Suggested storage guidance'), findsNothing);
    expect(StorageGuidance.catalogVersion, '2026-11-01.1');
    await tester.pumpWidget(const SizedBox());
  });
}
