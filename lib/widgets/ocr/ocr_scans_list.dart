import 'package:flutter/material.dart';

import '../../domain/ocr/ocr_models.dart';
import '../food_photo.dart';

/// Displays captured/sampled label inputs with remove actions and raw OCR logs.
class OcrScansList extends StatelessWidget {
  const OcrScansList({
    super.key,
    required this.scans,
    required this.onRemove,
    this.enabled = true,
  });

  final List<OcrPhotoScan> scans;
  final ValueChanged<String> onRemove;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (scans.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No label scans added yet. Scan one side for the food name and another side if the printed date is on the back or lid.',
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < scans.length; i++)
          _OcrScanCard(
            index: i,
            scan: scans[i],
            enabled: enabled,
            onRemove: () => onRemove(scans[i].id),
          ),
      ],
    );
  }
}

class _OcrScanCard extends StatelessWidget {
  const _OcrScanCard({
    required this.index,
    required this.scan,
    required this.enabled,
    required this.onRemove,
  });

  final int index;
  final OcrPhotoScan scan;
  final bool enabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (scan.photo != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: FoodPhotoView(
                      photo: scan.photo!,
                      label: 'Scan ${index + 1}',
                      size: 52,
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan ${index + 1} · ${scan.sourceLabel}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        scan.isSample
                            ? 'Sample preset text (not real camera OCR)'
                            : 'On-device recognition · ${scan.elapsedMs} ms',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove scan ${index + 1}',
                  onPressed: enabled ? onRemove : null,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Raw recognized text'),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    scan.rawText.trim().isEmpty
                        ? '(No text detected in this image)'
                        : scan.rawText,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
