import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshkeep/add_groceries_dialog.dart';
import 'package:freshkeep/data/inventory_database.dart';
import 'package:freshkeep/domain/food_photo.dart';
import 'package:freshkeep/domain/ocr/merge_ocr_scans.dart';
import 'package:freshkeep/domain/ocr/ocr_models.dart';
import 'package:freshkeep/domain/ocr/parse_food_name.dart';
import 'package:freshkeep/domain/ocr/parse_printed_date.dart';
import 'package:freshkeep/main.dart';
import 'package:freshkeep/ocr/ocr_service.dart';
import 'package:freshkeep/ocr/pick_scan_image.dart';
import 'package:freshkeep/ocr/sample_ocr_service.dart';
import 'package:freshkeep/ocr/scan_label_screen.dart';
import 'package:image_picker/image_picker.dart';

FoodPhoto _samplePhoto() => FoodPhoto(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAIAAAD8GO2jAAAAK0lEQVR4nO3NQQkAAAgEMKMZxUgX2RQ+hMH+q86cKoFAIBAIBAKBQJAnwQI8I8A9r3relAAAAABJRU5ErkJggg==',
  ),
);

class _FakeOnDeviceOcrService implements OcrService {
  _FakeOnDeviceOcrService(this._handler);

  final Future<OcrRecognitionOutput> Function(String filePath) _handler;
  int calls = 0;

  @override
  bool get isOnDeviceSupported => true;

  @override
  String get engineLabel => 'Test ML Kit OCR';

  @override
  Future<OcrRecognitionOutput> recognizeImagePath(String filePath) async {
    calls++;
    return _handler(filePath);
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  test('parsePrintedDate parses ISO, named months, cues, and excludes MFG dates', () {
    expect(parsePrintedDate('EXP 2027-03-15').printedDate, '2027-03-15');
    expect(parsePrintedDate('BEST BEFORE\n18 DEC 2026').printedDate, '2026-12-18');
    expect(parsePrintedDate('USE BY Nov 18, 2026').printedDate, '2026-11-18');
    expect(parsePrintedDate('USE BY 25/12/2026').printedDate, '2026-12-25');
    expect(parsePrintedDate('EXP 12/25/2026').printedDate, '2026-12-25');
    expect(parsePrintedDate('BB 08/08/2027').printedDate, '2027-08-08');

    final withMfg = parsePrintedDate(
      'MFG 2026-01-10\nEXP 15 NOV 2026',
    );
    expect(withMfg.printedDate, '2026-11-15');

    final sameLineMfgIso = parsePrintedDate(
      'MFG: 2026-01-01 EXP: 2027-02-03',
    );
    expect(sameLineMfgIso.printedDate, '2027-02-03');

    final sameLineMfgAmbiguous = parsePrintedDate(
      'MFG: 2026-01-01 EXP: 02/03/2027',
    );
    expect(sameLineMfgAmbiguous.printedDate, isNull);
    expect(sameLineMfgAmbiguous.ambiguousCandidates, hasLength(2));

    // Manufacturing-only date must stay unknown.
    expect(parsePrintedDate('MFG 2026-01-10\nLOT 42').printedDate, isNull);
  });

  test('parsePrintedDate flags ambiguity, handles month-only, and rejects invalid dates', () {
    final ambiguous = parsePrintedDate('EXP 04/05/2027');
    expect(ambiguous.printedDate, isNull);
    expect(ambiguous.isAmbiguous, isTrue);
    expect(
      ambiguous.ambiguousCandidates.map((c) => c.label),
      ['2027-05-04 (DD/MM)', '2027-04-05 (MM/DD)'],
    );

    final monthOnly = parsePrintedDate('BEST BEFORE NOV 2026');
    expect(monthOnly.printedDate, isNull);
    expect(monthOnly.isMonthOnly, isTrue);
    expect(monthOnly.ambiguousCandidates.single.isoDate, '2026-11-30');

    final leapMonthOnly = parsePrintedDate('EXP 02/2028');
    expect(leapMonthOnly.printedDate, isNull);
    expect(leapMonthOnly.ambiguousCandidates.single.isoDate, '2028-02-29');

    final shortMonthOnly = parsePrintedDate('EXP 11/26');
    expect(shortMonthOnly.printedDate, isNull);
    expect(shortMonthOnly.isMonthOnly, isTrue);
    expect(shortMonthOnly.ambiguousCandidates.single.isoDate, '2026-11-30');

    // Uncued MM/YY must stay unknown so random codes/ratios do not match.
    final uncuedShort = parsePrintedDate('LOT 11/26');
    expect(uncuedShort.printedDate, isNull);
    expect(uncuedShort.ambiguousCandidates, isEmpty);

    // Invalid calendar date (Feb 30) must NOT fall back to 02/2027 month-only!
    final invalid = parsePrintedDate('EXP 30/02/2027');
    expect(invalid.printedDate, isNull);
    expect(invalid.ambiguousCandidates, isEmpty);

    // Missing date stays unknown.
    final noDate = parsePrintedDate('CARABAO MANGOES\nNET WT 800g');
    expect(noDate.printedDate, isNull);
    expect(noDate.ambiguousCandidates, isEmpty);
  });

  test('parseFoodName filters barcodes, weights, prices, dates, and label headers', () {
    expect(
      parseFoodName('ALPINE DAIRY\nFRESH WHOLE MILK\n500g'),
      'Alpine Dairy',
    );
    expect(
      parseFoodName('NUTRITION FACTS\nCalories 120\nGreek Yogurt (Plain)\nEXP 2027-01-01'),
      'Greek Yogurt (Plain)',
    );
    expect(
      parseFoodName('4800012345678\n1kg\n₱125.00\nhttps://example.com\nBEST BEFORE 2027-01-01'),
      isNull,
    );
  });

  test('mergeOcrScans combines front-of-pack name with back-panel date and flags conflicts', () {
    final merged = mergeOcrScans([
      const OcrPhotoScan(
        id: '1',
        sourceLabel: 'Front',
        rawText: 'FRESH WHOLE MILK\n1L',
        elapsedMs: 12,
        isSample: false,
      ),
      const OcrPhotoScan(
        id: '2',
        sourceLabel: 'Back',
        rawText: 'MFG 2026-10-01\nBEST BEFORE\n18 DEC 2026',
        elapsedMs: 14,
        isSample: false,
      ),
    ]);
    expect(merged.suggestedName, 'Fresh Whole Milk');
    expect(merged.dateResult.printedDate, '2026-12-18');

    final conflicting = mergeOcrScans([
      const OcrPhotoScan(
        id: '1',
        sourceLabel: 'Side A',
        rawText: 'Milk\nEXP 2026-12-18',
        elapsedMs: 10,
        isSample: false,
      ),
      const OcrPhotoScan(
        id: '2',
        sourceLabel: 'Side B',
        rawText: 'EXP 2026-12-25',
        elapsedMs: 10,
        isSample: false,
      ),
    ]);
    expect(conflicting.dateResult.printedDate, isNull);
    expect(conflicting.dateResult.ambiguousCandidates, hasLength(2));
  });

  test('createOcrService selects ML Kit on mobile and honest sample mode on desktop', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final desktopService = createOcrService();
    expect(desktopService.isOnDeviceSupported, isFalse);
    await desktopService.dispose();

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final mobileService = createOcrService();
    expect(mobileService.isOnDeviceSupported, isTrue);
    await mobileService.dispose();
  });

  testWidgets('Sample mode combines front + back presets into editable AddGroceriesScreen without auto-saving', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = InventoryDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ScanLabelScreen(
          database: db,
          ocrService: SampleOcrService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Experiment · Sample mode (demo text only)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sample-preset-front-milk')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('sample-preset-back-exp')),
    );
    await tester.tap(find.byKey(const ValueKey('sample-preset-back-exp')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Selected date: 2026-12-18'));
    expect(find.text('Selected date: 2026-12-18'), findsOneWidget);
    // Nothing saved automatically before explicit review & save.
    expect(await db.loadBatches(), isEmpty);

    await tester.tap(find.byKey(const ValueKey('use-ocr-draft')));
    await tester.pumpAndSettle();

    expect(find.text('Add groceries'), findsOneWidget);
    expect(find.textContaining('Drafted from label scan.'), findsOneWidget);
    expect(find.text('2026-12-18'), findsWidgets);
    // Still unsaved until Save groceries is pressed!
    expect(await db.loadBatches(), isEmpty);

    await tester.tap(find.byKey(const ValueKey('save-groceries')));
    await tester.pumpAndSettle();

    final saved = await db.loadBatches();
    expect(saved, hasLength(1));
    expect(saved.single.draft.name, 'Alpine Dairy');
    expect(saved.single.draft.printedDate, '2026-12-18');
  });

  testWidgets('Ambiguous sample date keeps unknown until explicitly chosen; cancel writes nothing', (tester) async {
    final db = InventoryDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ScanLabelScreen(
          database: db,
          ocrService: SampleOcrService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('sample-preset-ambiguous-yogurt')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('ocr-candidate-2027-05-04')));
    expect(find.text('Date unknown'), findsOneWidget);
    expect(find.byKey(const ValueKey('ocr-candidate-2027-05-04')), findsOneWidget);
    expect(find.byKey(const ValueKey('ocr-candidate-2027-04-05')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ocr-candidate-2027-05-04')));
    await tester.pumpAndSettle();
    expect(find.text('Selected date: 2027-05-04'), findsOneWidget);

    // Cancel leaves DB empty
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await db.loadBatches(), isEmpty);
  });

  testWidgets('On-device fake OCR scans front/back photos, preserves manual edit, handles errors, and saves cleanly', (tester) async {
    final db = InventoryDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    var failNextOcr = false;
    final ocr = _FakeOnDeviceOcrService((path) async {
      if (failNextOcr) {
        throw StateError('Simulated recognizer error');
      }
      if (path == '/tmp/front.jpg') {
        return const OcrRecognitionOutput(
          rawText: 'OAT MILK BARISTA\n1L',
          elapsedMs: 18,
          isSample: false,
          engineLabel: 'Test ML Kit OCR',
        );
      }
      return const OcrRecognitionOutput(
        rawText: 'USE BY 22 NOV 2026',
        elapsedMs: 21,
        isSample: false,
        engineLabel: 'Test ML Kit OCR',
      );
    });

    final photo = _samplePhoto();
    await tester.pumpWidget(
      MaterialApp(
        home: AddGroceriesScreen(
          database: db,
          ocrService: ocr,
          pickScanImage: (source) async => PickedScanImage(
            sourceLabel: source == ImageSource.camera ? 'Camera' : 'Gallery',
            filePath: source == ImageSource.camera
                ? '/tmp/front.jpg'
                : '/tmp/back.jpg',
            photo: photo,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('scan-label-button')));
    await tester.tap(find.byKey(const ValueKey('scan-label-button')));
    await tester.pumpAndSettle();

    // First scan (camera -> front label)
    await tester.tap(find.byKey(const ValueKey('ocr-take-photo')));
    await tester.pumpAndSettle();
    expect(find.text('Oat Milk Barista'), findsOneWidget);

    // User refines the food name manually before taking a second photo
    await tester.enterText(
      find.byKey(const ValueKey('ocr-name-field')),
      'Barista Oat Milk',
    );
    await tester.pumpAndSettle();

    // Second scan fails once -> error shown, manual draft preserved
    failNextOcr = true;
    await tester.ensureVisible(find.byKey(const ValueKey('ocr-pick-photo')));
    await tester.tap(find.byKey(const ValueKey('ocr-pick-photo')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Text recognition failed'), findsOneWidget);
    expect(find.text('Barista Oat Milk'), findsOneWidget);

    // Second scan succeeds -> date populated, edited name preserved
    failNextOcr = false;
    await tester.ensureVisible(find.byKey(const ValueKey('ocr-pick-photo')));
    await tester.tap(find.byKey(const ValueKey('ocr-pick-photo')));
    await tester.pumpAndSettle();
    expect(find.text('Barista Oat Milk'), findsOneWidget);
    await tester.ensureVisible(find.text('Selected date: 2026-11-22'));
    expect(find.text('Selected date: 2026-11-22'), findsOneWidget);
    expect(ocr.calls, 3);

    // Return draft to AddGroceriesScreen and commit
    await tester.tap(find.byKey(const ValueKey('use-ocr-draft')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-groceries')));
    await tester.pumpAndSettle();

    final saved = await db.loadBatches();
    expect(saved, hasLength(1));
    expect(saved.single.draft.name, 'Barista Oat Milk');
    expect(saved.single.draft.printedDate, '2026-11-22');
    expect(saved.single.draft.photo!.sameAs(photo), isTrue);
  });

  testWidgets('More tab opens Label scanner (OCR experiment) cleanly at 2.0x text scale', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final db = InventoryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(FreshKeepApp(database: db));
    await tester.pumpAndSettle();

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Label scanner (OCR experiment)'));
    await tester.tap(find.text('Label scanner (OCR experiment)'));
    await tester.pumpAndSettle();
    expect(find.text('Scan label (experiment)'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
