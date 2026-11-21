import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshkeep/data/inventory_database.dart';
import 'package:freshkeep/domain/batch.dart';
import 'package:freshkeep/domain/stock_event.dart';
import 'package:freshkeep/main.dart';

void main() {
  late InventoryDatabase database;
  late int id;
  setUp(() async {
    database = InventoryDatabase(NativeDatabase.memory());
    await database.addBatch(
      BatchDraft(name: 'Eggs', quantity: 6, unit: 'pieces', storage: 'Fridge'),
    );
    id = (await database.loadBatches()).single.id;
  });
  tearDown(() => database.close());

  test(
    'consume, dispose and actual-stock corrections keep waste separate',
    () async {
      await database.recordAction(id, StockAction.consume, 2);
      await database.recordAction(id, StockAction.dispose, 1, reason: 'Broken');
      await database.recordAction(id, StockAction.correct, 5);
      expect((await database.loadBatch(id)).remaining, 5);
      expect(await database.disposedQuantity(id), 1);
      final history = await database.loadHistory(id);
      expect(history.map((e) => e.delta), [2, -1, -2]);
      expect(history[1].reason, 'Broken');
      expect(history.every((e) => e.createdAt.isUtc), isTrue);
    },
  );

  test(
    'rejects overdraw, zero consumption, negative correction and no-op',
    () async {
      for (final action in [StockAction.consume, StockAction.dispose]) {
        for (final qty in [-1, 0, 7]) {
          await expectLater(
            database.recordAction(id, action, qty),
            throwsA(isA<StockValidationException>()),
          );
        }
      }
      for (final qty in [-1, 6, 1000000001]) {
        await expectLater(
          database.recordAction(id, StockAction.correct, qty),
          throwsA(isA<StockValidationException>()),
        );
      }
      expect(await database.loadHistory(id), isEmpty);
      expect((await database.loadBatch(id)).remaining, 6);
    },
  );

  test(
    'depleted batches retain history and reactivate after positive correction',
    () async {
      await database.recordAction(id, StockAction.consume, 6);
      expect((await database.loadBatch(id)).depleted, isTrue);
      await database.recordAction(id, StockAction.correct, 2);
      expect((await database.loadBatch(id)).depleted, isFalse);
      expect(await database.disposedQuantity(id), 0);
    },
  );

  test(
    'undo disposal restores stock and waste without changing history',
    () async {
      await database.recordAction(id, StockAction.dispose, 2);
      final event = (await database.loadHistory(id)).single;
      expect(event.reason, 'Unspecified');
      await database.undoEvent(id, event.id);
      expect((await database.loadBatch(id)).remaining, 6);
      expect(await database.disposedQuantity(id), 0);
      expect((await database.loadHistory(id)).last.reversed, isTrue);
      await expectLater(
        database.undoEvent(id, event.id),
        throwsA(isA<StockValidationException>()),
      );
      expect(await database.loadHistory(id), hasLength(2));
      await expectLater(
        database.customStatement('DELETE FROM events'),
        throwsA(anything),
      );
      await expectLater(
        database.customStatement('UPDATE events SET delta=1'),
        throwsA(anything),
      );
    },
  );

  test('undo cannot make stock negative after later consumption', () async {
    await database.recordAction(id, StockAction.correct, 10);
    final correction = (await database.loadHistory(id)).single;
    await database.recordAction(id, StockAction.consume, 9);
    await expectLater(
      database.undoEvent(id, correction.id),
      throwsA(isA<StockValidationException>()),
    );
    expect((await database.loadBatch(id)).remaining, 1);
  });

  test('stale forms and competing withdrawals cannot overdraw stock', () async {
    await database.recordAction(id, StockAction.consume, 1);
    await expectLater(
      database.recordAction(id, StockAction.correct, 4, expectedRemaining: 6),
      throwsA(isA<StockValidationException>()),
    );
    final outcomes = await Future.wait(
      [4, 4].map((qty) async {
        try {
          await database.recordAction(id, StockAction.consume, qty);
          return true;
        } on StockValidationException {
          return false;
        }
      }),
    );
    expect(outcomes.where((success) => success), hasLength(1));
    expect((await database.loadBatch(id)).remaining, 1);
  });

  test(
    'v1 upgrade keeps old inventory and persists new events after reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'freshkeep_migration_',
      );
      final file = File('${directory.path}/legacy.sqlite');
      var legacy = InventoryDatabase(NativeDatabase(file));
      try {
        await legacy.addBatch(
          BatchDraft(name: 'Rice', quantity: 500, unit: 'g', storage: 'Pantry'),
        );
        // Reconstruct the v1 schema: it had batches only, and user_version=1.
        await legacy.customStatement('DROP TABLE events');
        await legacy.customStatement('DROP TABLE reminder_settings');
        await legacy.customStatement('DROP TABLE batch_edits');
        await legacy.customStatement('DROP TABLE batch_photos');
        await legacy.customStatement(
          'ALTER TABLE batches DROP COLUMN printed_time',
        );
        await legacy.customStatement(
          'ALTER TABLE batches DROP COLUMN guidance_rule_id',
        );
        await legacy.customStatement(
          'ALTER TABLE batches DROP COLUMN guidance_catalog_version',
        );
        await legacy.customStatement(
          'ALTER TABLE batches DROP COLUMN guidance_anchor_event',
        );
        await legacy.customStatement(
          'ALTER TABLE batches DROP COLUMN guidance_anchor_date',
        );
        await legacy.customStatement(
          'ALTER TABLE batches DROP COLUMN suggested_date',
        );
        await legacy.customStatement('PRAGMA user_version = 1');
        await legacy.close();
        legacy = InventoryDatabase(NativeDatabase(file));
        final batch = (await legacy.loadBatches()).single;
        expect(batch.remaining, 500);
        await legacy.recordAction(batch.id, StockAction.dispose, 100);
        await legacy.close();
        legacy = InventoryDatabase(NativeDatabase(file));
        expect((await legacy.loadBatches()).single.remaining, 400);
        expect(await legacy.disposedQuantity(batch.id), 100);
        expect(await legacy.loadHistory(batch.id), hasLength(1));
      } finally {
        await legacy.close();
        await directory.delete(recursive: true);
      }
    },
  );

  testWidgets(
    'manage batch validates actions, cancels cleanly, and refreshes inventory',
    (tester) async {
      await tester.pumpWidget(FreshKeepApp(database: database));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('View batch details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '7');
      await tester.tap(find.byKey(const ValueKey('confirm-stock-action')));
      await tester.pumpAndSettle();
      expect(
        find.text('This quantity exceeds the remaining stock.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextFormField).first, '2');
      await tester.tap(find.byKey(const ValueKey('confirm-stock-action')));
      await tester.pumpAndSettle();
      expect(find.text('4 pieces remaining'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '1');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await database.disposedQuantity(id), 0);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('4 pieces'), findsOneWidget);
      expect(await database.loadHistory(id), hasLength(1));
    },
  );
}
