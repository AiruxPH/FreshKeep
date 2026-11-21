import 'package:flutter/material.dart';

/// Displays an honest notice explaining whether OCR runs on-device (Android)
/// or in web/desktop sample mode, and emphasizing draft review.
class OcrStatusBanner extends StatelessWidget {
  const OcrStatusBanner({
    super.key,
    required this.isOnDeviceSupported,
    required this.engineLabel,
  });

  final bool isOnDeviceSupported;
  final String engineLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = isOnDeviceSupported
        ? scheme.primaryContainer
        : scheme.secondaryContainer;
    final fg = isOnDeviceSupported
        ? scheme.onPrimaryContainer
        : scheme.onSecondaryContainer;
    return Card(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isOnDeviceSupported
                  ? Icons.document_scanner_outlined
                  : Icons.science_outlined,
              color: fg,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOnDeviceSupported
                        ? 'Experiment · On-device text scan (offline)'
                        : 'Experiment · Sample mode (demo text only)',
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: fg),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isOnDeviceSupported
                        ? '$engineLabel. Reads visible packaging text into an editable draft — never saves automatically or guesses dates from food appearance.'
                        : 'Real camera OCR requires Android or iOS. Use sample presets below to test multi-side draft review without claiming real image recognition.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: fg),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
