import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'ocr_service.dart';
import 'sample_ocr_service.dart';

/// Instantiates on-device [MlKitOcrService] on Android/iOS, or [SampleOcrService]
/// on desktop targets where Google ML Kit binary libraries are unavailable.
OcrService createPlatformOcrService() {
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    return MlKitOcrService();
  }
  return SampleOcrService();
}

/// Offline Google ML Kit Latin text recognizer.
class MlKitOcrService implements OcrService {
  TextRecognizer? _recognizer;

  @override
  bool get isOnDeviceSupported => true;

  @override
  String get engineLabel => 'On-device Google ML Kit (Latin)';

  @override
  Future<OcrRecognitionOutput> recognizeImagePath(String filePath) async {
    final stopwatch = Stopwatch()..start();
    _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    final inputImage = InputImage.fromFilePath(filePath);
    final recognized = await _recognizer!.processImage(inputImage);
    stopwatch.stop();
    return OcrRecognitionOutput(
      rawText: recognized.text,
      elapsedMs: stopwatch.elapsedMilliseconds,
      isSample: false,
      engineLabel: engineLabel,
    );
  }

  @override
  Future<void> dispose() async {
    final recognizer = _recognizer;
    _recognizer = null;
    await recognizer?.close();
  }
}
