import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshkeep/data/inventory_database.dart';
import 'package:freshkeep/domain/batch.dart';
import 'package:freshkeep/domain/date_status.dart';
import 'package:freshkeep/main.dart';
import 'package:freshkeep/widgets/batch_date_label.dart';
import 'package:freshkeep/widgets/local_day_scope.dart';
void main() {
  test(
    'classifies unknown, past, today, 1, 3 and 4 days at their boundaries',
    () {
      final now = DateTime(2026, 11, 1, 23, 59);
      expect(dateStatus(null, now), DateStatus.unknown);
      expect(dateStatus('2026-10-31', now), DateStatus.past);
      expect(dateStatus('2026-11-01', now), DateStatus.today);
      expect(dateStatus('2026-11-02', now), DateStatus.soon);
      expect(dateStatus('2026-11-04', now), DateStatus.soon);
      expect(dateStatus('2026-11-05', now), DateStatus.later);
    },
  );

  test('handles leap days and year boundaries', () {
    expect(dateStatus('2028-03-01', DateTime(2028, 2, 28)), DateStatus.soon);
    expect(dateStatus('2028-02-29', DateTime(2028, 3, 1)), DateStatus.past);
    expect(dateStatus('2027-01-01', DateTime(2026, 12, 31)), DateStatus.soon);
    expect(dateStatus('2026-12-31', DateTime(2027, 1, 1)), DateStatus.past);
  });

  test('uses calendar components regardless of time of day', () {
    for (final hour in [0, 12, 23]) {
      expect(
        dateStatus('2026-11-04', DateTime(2026, 11, 1, hour, 59)),
        DateStatus.soon,
      );
      expect(
        dateStatus('2026-11-01', DateTime(2026, 11, 1, hour, 59)),
        DateStatus.today,
      );
    }
  });

  testWidgets('status updates across midnight without reopening the screen', (
    tester,
  ) async {
    var now = DateTime(2026, 11, 1, 23, 59, 59);
    await tester.pumpWidget(
      LocalDayScope(
        now: () => now,
        child: const MaterialApp(
          home: Scaffold(body: BatchDateLabel(printedDate: '2026-11-01')),
        ),
      ),
    );
    expect(find.text('Today'), findsOneWidget);
    now = DateTime(2026, 11, 2, 0, 0, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Past date'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('resume and foreground clock checks pick up a changed day', (
    tester,
  ) async {
    var now = DateTime(2026, 11, 1, 12);
    await tester.pumpWidget(
      LocalDayScope(
        now: () => now,
        child: const MaterialApp(
          home: Scaffold(body: BatchDateLabel(printedDate: '2026-11-04')),
        ),
      ),
    );
    expect(find.text('In 1–3 days'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = DateTime(2026, 11, 4, 12);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Today'), findsOneWidget);
    now = DateTime(2026, 11, 5, 12);
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('Past date'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'past dates display in both screens without changing stock or waste',
    (tester) async {
      final database = InventoryDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.addBatch(
        BatchDraft(
          name: 'Bread',
          quantity: 2,
          unit: 'pieces',
          storage: 'Pantry',
          printedDate: '2000-01-01',
        ),
      );
      await tester.pumpWidget(FreshKeepApp(database: database));
      await tester.pumpAndSettle();
      expect(find.text('Past date'), findsOneWidget);
      expect(find.text('Printed date · 2000-01-01'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('View batch details'));
      await tester.tap(find.byTooltip('View batch details'));
      await tester.pumpAndSettle();
      expect(find.text('Past date'), findsOneWidget);
      final batch = (await database.loadBatches()).single;
      expect(batch.remaining, 2);
      expect(await database.disposedQuantity(batch.id), 0);
      expect(await database.loadHistory(batch.id), isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('hoursLeft status when time is set and within 24 h on same calendar day', () {
    // 10:00 now, item expires at 14:30 same day → hoursLeft
    expect(
      dateStatus('2026-11-01', DateTime(2026, 11, 1, 10, 0), time: '14:30'),
      DateStatus.hoursLeft,
    );
    // 15:00 now, item expired at 14:30 same day → past
    expect(
      dateStatus('2026-11-01', DateTime(2026, 11, 1, 15, 0), time: '14:30'),
      DateStatus.past,
    );
    // No time provided on same day → today (unchanged behaviour)
    expect(
      dateStatus('2026-11-01', DateTime(2026, 11, 1, 10, 0)),
      DateStatus.today,
    );
    // Item is tomorrow, time provided → soon (not hoursLeft)
    expect(
      dateStatus('2026-11-02', DateTime(2026, 11, 1, 10, 0), time: '08:00'),
      DateStatus.soon,
    );
  });

  test('hoursLeftLabel returns correct countdown strings', () {
    // 3 h 45 m remaining
    expect(
      hoursLeftLabel('2026-11-01', '14:45', DateTime(2026, 11, 1, 11, 0)),
      '3h 45m left',
    );
    // Exactly 2 h remaining, no minutes
    expect(
      hoursLeftLabel('2026-11-01', '13:00', DateTime(2026, 11, 1, 11, 0)),
      '2h left',
    );
    // 30 m remaining, no hours
    expect(
      hoursLeftLabel('2026-11-01', '11:30', DateTime(2026, 11, 1, 11, 0)),
      '30m left',
    );
    // Already past → null
    expect(
      hoursLeftLabel('2026-11-01', '10:00', DateTime(2026, 11, 1, 11, 0)),
      isNull,
    );
  });

  testWidgets('hoursLeft chip shows countdown and updates when time passes', (
    tester,
  ) async {
    var now = DateTime(2026, 11, 1, 10, 0);
    await tester.pumpWidget(
      LocalDayScope(
        now: () => now,
        child: const MaterialApp(
          home: Scaffold(
            body: BatchDateLabel(
              printedDate: '2026-11-01',
              printedTime: '14:00',
            ),
          ),
        ),
      ),
    );
    expect(find.text('4h left'), findsOneWidget);
    expect(find.text('Printed date · 2026-11-01 14:00'), findsOneWidget);
    // After the time has passed on the same day → Past date chip
    now = DateTime(2026, 11, 1, 15, 0);
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('Past date'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
