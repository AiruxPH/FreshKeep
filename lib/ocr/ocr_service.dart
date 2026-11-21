import 'mlkit_ocr_service_stub.dart'
    if (dart.library.io) 'mlkit_ocr_service_io.dart'
    as platform;

/// Result of running OCR (or sample text fallback) on a single item image.
class OcrRecognitionOutput {
  const OcrRecognitionOutput({
    required this.rawText,
    required this.elapsedMs,
    required this.isSample,
    required this.engineLabel,
  });

  final String rawText;
  final int elapsedMs;
  final bool isSample;
  final String engineLabel;
}

/// Platform-separated text recognition contract so Android runs on-device ML Kit
/// while web/unsupported desktop platforms compile cleanly without `dart:io`.
abstract class OcrService {
  bool get isOnDeviceSupported;
  String get engineLabel;

  Future<OcrRecognitionOutput> recognizeImagePath(String filePath);
  Future<void> dispose();
}

/// Instantiates the platform-appropriate [OcrService].
OcrService createOcrService() => platform.createPlatformOcrService();
