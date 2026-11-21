import 'package:flutter_test/flutter_test.dart';
import 'package:freshkeep/domain/batch.dart';

void main() {
  BatchDraft draft({
    String name = ' Eggs ',
    int qty = 6,
    String unit = 'pieces',
    String? date,
    String? time,
  }) => BatchDraft(
    name: name,
    quantity: qty,
    unit: unit,
    storage: 'Fridge',
    printedDate: date,
    printedTime: time,
  );
  test('normalizes name and retains unknown date', () {
    expect(draft().name, 'Eggs');
    expect(draft().printedDate, isNull);
    expect(draft().printedTime, isNull);
  });
  test('rejects invalid stock and unsupported units', () {
    for (final qty in [0, -1, 1000000001]) {
      expect(() => draft(qty: qty), throwsArgumentError);
    }
    expect(() => draft(name: '  '), throwsArgumentError);
    expect(() => draft(unit: 'kg'), throwsArgumentError);
  });
  test('date-only data rejects overflow and accepts leap day', () {
    expect(() => draft(date: '2026-02-30'), throwsArgumentError);
    expect(draft(date: '2028-02-29').printedDate, '2028-02-29');
  });
  test('rejects printed time without a printed date', () {
    expect(() => draft(time: '10:30'), throwsArgumentError);
  });
  test('rejects malformed time strings', () {
    for (final bad in ['25:00', '10:60', 'noon', '10', '10:30:00']) {
      expect(() => draft(date: '2026-11-20', time: bad), throwsArgumentError,
          reason: 'expected rejection for "$bad"');
    }
  });
  test('accepts valid times and formats them correctly', () {
    final d = draft(date: '2026-11-20', time: '09:05');
    expect(d.printedTime, '09:05');
    expect(d.dateTimeLabel, '2026-11-20 09:05');
    expect(draft(date: '2026-11-20').dateTimeLabel, '2026-11-20');
    expect(draft().dateTimeLabel, 'Date unknown');
  });
  test('timeOnly pads single-digit hours and minutes', () {
    expect(BatchDraft.timeOnly(9, 5), '09:05');
    expect(BatchDraft.timeOnly(23, 59), '23:59');
    expect(BatchDraft.timeOnly(0, 0), '00:00');
  });
}
