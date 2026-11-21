import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshkeep/data/inventory_database.dart';
import 'package:freshkeep/domain/batch.dart';
import 'package:freshkeep/domain/format_remaining_duration.dart';
import 'package:freshkeep/domain/stock_event.dart';
import 'package:freshkeep/intro/onboarding_screen.dart';
import 'package:freshkeep/intro/splash_screen.dart';
import 'package:freshkeep/main.dart';
import 'package:freshkeep/widgets/toast/freshkeep_toast_card.dart';

void main() {
  test('formatRemainingDuration scales across weeks, days, hours, minutes and seconds', () {
    final now = DateTime(2026, 11, 1, 10, 0, 0);

    expect(formatRemainingDuration(null, now), 'Date unknown');
    expect(formatRemainingDuration('2026-10-31', now), 'Past date');
    expect(
      formatRemainingDuration('2026-11-01', now, time: '09:59'),
      'Past date',
    );
    expect(formatRemainingDuration('2026-11-01', now), 'Today');

    // Weeks (>= 7 days)
    expect(formatRemainingDuration('2026-11-08', now), '1 week left');
    expect(formatRemainingDuration('2026-11-11', now), '1 week 3 days left');
    expect(formatRemainingDuration('2026-11-15', now), '2 weeks left');
    expect(
      formatRemainingDuration('2026-11-08', now, time: '12:00'),
      '1 week left',
    );

    // Days (1–6 days)
    expect(formatRemainingDuration('2026-11-02', now), '1 day left');
    expect(formatRemainingDuration('2026-11-04', now), '3 days left');
    expect(formatRemainingDuration('2026-11-07', now), '6 days left');

    // Hours (< 24h, including across midnight)
    expect(
      formatRemainingDuration('2026-11-01', now, time: '14:00'),
      '4 hours left',
    );
    expect(
      formatRemainingDuration('2026-11-01', now, time: '13:45'),
      '3 hours 45 mins left',
    );
    expect(
      formatRemainingDuration(
        '2026-11-02',
        DateTime(2026, 11, 1, 20, 0),
        time: '08:00',
      ),
      '12 hours left',
    );

    // Minutes (< 1h)
    expect(
      formatRemainingDuration('2026-11-01', now, time: '10:30'),
      '30 minutes left',
    );
    expect(
      formatRemainingDuration('2026-11-01', now, time: '10:01'),
      '1 minute left',
    );

    // Seconds (< 1 min)
    expect(
      formatRemainingDuration(
        '2026-11-01',
        DateTime(2026, 11, 1, 10, 0, 15),
        time: '10:01',
      ),
      '45 seconds left',
    );
    expect(
      formatRemainingDuration(
        '2026-11-01',
        DateTime(2026, 11, 1, 10, 0, 59),
        time: '10:01',
      ),
      '1 second left',
    );
  });

  testWidgets('quick action toast auto-dismisses after timeout and supports immediate Undo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = InventoryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.addBatch(
      BatchDraft(name: 'Eggs', quantity: 4, unit: 'pieces', storage: 'Fridge'),
    );
    final id = (await db.loadBatches()).single.id;

    await tester.pumpWidget(FreshKeepApp(database: db));
    await tester.pumpAndSettle();

    // Quick Use shows auto-dismissing toast with Undo.
    await tester.tap(find.text('Use'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '1');
    await tester.tap(find.byKey(const ValueKey('confirm-stock-action')));
    await tester.pumpAndSettle();

    expect(find.byType(FreshKeepToastCard), findsOneWidget);
    expect(find.text('Food use recorded.'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    // Wait past the 4-second auto-dismiss duration.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.byType(FreshKeepToastCard), findsNothing);
    expect(find.text('Food use recorded.'), findsNothing);
    expect((await db.loadBatch(id)).remaining, 3);

    // Quick Discard shows toast, and tapping Undo immediately dismisses and restores stock.
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '1');
    await tester.tap(find.byKey(const ValueKey('confirm-stock-action')));
    await tester.pumpAndSettle();

    expect(find.text('Waste recorded.'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.byType(FreshKeepToastCard), findsNothing);
    expect((await db.loadBatch(id)).remaining, 3);
    expect(await db.disposedQuantity(id), 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('splash shows on every launch and onboarding only appears on first open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final dir = await Directory.systemTemp.createTemp('freshkeep_onboarding_');
    final file = File('${dir.path}/db.sqlite');
    var db = InventoryDatabase(NativeDatabase(file));
    try {
      expect(await db.hasCompletedOnboarding(), isFalse);

      // First launch: Splash -> Onboarding -> Get started -> Inventory.
      await tester.pumpWidget(
        FreshKeepApp(
          database: db,
          showSplash: true,
          showOnboardingIfNeeded: true,
          splashDuration: const Duration(milliseconds: 200),
        ),
      );
      await tester.pump();
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);

      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
      expect(find.text('My groceries'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('intro-continue')));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.text('My groceries'), findsOneWidget);
      expect(await db.hasCompletedOnboarding(), isTrue);

      await tester.pumpWidget(const SizedBox());
      await db.close();

      // Second launch with persisted DB: Splash -> directly to Inventory.
      db = InventoryDatabase(NativeDatabase(file));
      await tester.pumpWidget(
        FreshKeepApp(
          database: db,
          showSplash: true,
          showOnboardingIfNeeded: true,
          splashDuration: const Duration(milliseconds: 200),
        ),
      );
      await tester.pump();
      expect(find.byType(SplashScreen), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.text('My groceries'), findsOneWidget);

      // Verify large text scaling on OnboardingScreen does not throw layout overflows.
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onContinue: () {})),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    } finally {
      await db.close();
      await dir.delete(recursive: true);
    }
  });

  test('v7 upgrade to v8 creates app_preferences and preserves existing inventory', () async {
    final dir = await Directory.systemTemp.createTemp('freshkeep_v8_');
    final file = File('${dir.path}/v7.sqlite');
    var db = InventoryDatabase(NativeDatabase(file));
    try {
      await db.addBatch(
        BatchDraft(
          name: 'Milk',
          quantity: 500,
          unit: 'mL',
          storage: 'Fridge',
          printedDate: '2026-11-25',
          printedTime: '10:30',
        ),
      );
      await db.customStatement('DROP TABLE app_preferences');
      await db.customStatement('PRAGMA user_version = 7');
      await db.close();

      db = InventoryDatabase(NativeDatabase(file));
      expect(await db.hasCompletedOnboarding(), isFalse);
      final loaded = (await db.loadBatches()).single;
      expect(loaded.draft.name, 'Milk');
      expect(loaded.draft.printedTime, '10:30');
      await db.markOnboardingCompleted();
      expect(await db.hasCompletedOnboarding(), isTrue);
    } finally {
      await db.close();
      await dir.delete(recursive: true);
    }
  });

  test('loadRecentUndoableEvents returns newest-first unreversed actions and excludes reversals', () async {
    final db = InventoryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.addBatch(
      BatchDraft(name: 'Milk', quantity: 500, unit: 'mL', storage: 'Fridge'),
    );
    await db.addBatch(
      BatchDraft(name: 'Eggs', quantity: 6, unit: 'pieces', storage: 'Fridge'),
    );
    final batches = await db.loadBatches();
    final eggs = batches.firstWhere((b) => b.draft.name == 'Eggs');
    final milk = batches.firstWhere((b) => b.draft.name == 'Milk');

    final e1 = await db.recordAction(milk.id, StockAction.consume, 200);
    final e2 = await db.recordAction(eggs.id, StockAction.dispose, 1, reason: 'Cracked');
    final e3 = await db.recordAction(eggs.id, StockAction.correct, 4);
    await db.undoEvent(eggs.id, e2);

    final undoable = await db.loadRecentUndoableEvents();
    expect(undoable.map((a) => a.eventId), [e3, e1]);
    expect(undoable.first.actionSummary, 'Corrected -1 piece');
    expect(undoable.last.actionSummary, 'Used 200 mL');
  });

  testWidgets('recent undo sheet restores a depleted item after toast auto-dismisses', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = InventoryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.addBatch(
      BatchDraft(name: 'Yogurt', quantity: 2, unit: 'pieces', storage: 'Fridge'),
    );
    final id = (await db.loadBatches()).single.id;

    await tester.pumpWidget(FreshKeepApp(database: db));
    await tester.pumpAndSettle();

    // Consume all 2 pieces so the item leaves the default In stock view.
    await tester.tap(find.text('Use'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '2');
    await tester.tap(find.byKey(const ValueKey('confirm-stock-action')));
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey('batch-$id')), findsNothing);
    expect(find.byType(FreshKeepToastCard), findsOneWidget);

    // Let the toast disappear completely.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.byType(FreshKeepToastCard), findsNothing);

    // Use the AppBar Undo recent actions sheet to restore the depleted batch.
    await tester.tap(find.byKey(const ValueKey('recent-undo-button')));
    await tester.pumpAndSettle();
    expect(find.text('Undo recent actions'), findsOneWidget);
    expect(find.textContaining('Used 2 pieces'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey('batch-$id')), findsOneWidget);
    expect((await db.loadBatch(id)).remaining, 2);
    final history = await db.loadHistory(id);
    expect(history, hasLength(2));
    expect(history.first.type, 'reverse');
    expect(history.last.reversed, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}
