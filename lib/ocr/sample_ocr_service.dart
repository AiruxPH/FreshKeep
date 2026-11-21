import 'ocr_service.dart';

/// Sample packaged-food label preset used on web/unsupported targets to exercise
/// draft review honestly without claiming real image text recognition.
class SampleOcrPreset {
  const SampleOcrPreset({
    required this.id,
    required this.title,
    required this.description,
    required this.rawText,
  });

  final String id;
  final String title;
  final String description;
  final String rawText;
}

const List<SampleOcrPreset> sampleOcrPresets = [
  SampleOcrPreset(
    id: 'front-milk',
    title: 'Front label: Fresh Milk',
    description: 'Brand/food name only (no printed date on front)',
    rawText: 'ALPINE DAIRY\nFRESH WHOLE MILK\n1L\nKEEP REFRIGERATED',
  ),
  SampleOcrPreset(
    id: 'back-exp',
    title: 'Back panel: Printed date + MFG',
    description: 'Includes both manufacturing date and BEST BEFORE date',
    rawText: 'MFG 2026-10-01\nBEST BEFORE\n18 DEC 2026\nLOT A4029',
  ),
  SampleOcrPreset(
    id: 'ambiguous-yogurt',
    title: 'Ambiguous numeric date',
    description: 'Greek Yogurt with 04/05/2027 requiring DD/MM vs MM/DD choice',
    rawText: 'Greek Yogurt (Plain)\n500g\nEXP 04/05/2027',
  ),
  SampleOcrPreset(
    id: 'no-date-produce',
    title: 'No printed date',
    description: 'Fresh Mangoes pack with weight only — date stays unknown',
    rawText: 'CARABAO MANGOES\nNET WT 800g\nPRODUCT OF PHILIPPINES',
  ),
];

/// Honest fallback OCR service used on web and desktop when ML Kit is absent.
class SampleOcrService implements OcrService {
  @override
  bool get isOnDeviceSupported => false;

  @override
  String get engineLabel => 'Sample mode (demo text only)';

  @override
  Future<OcrRecognitionOutput> recognizeImagePath(String filePath) async {
    throw UnsupportedError(
      'On-device OCR is only available on Android/iOS builds. Use sample presets or enter manually.',
    );
  }

  @override
  Future<void> dispose() async {}
}
