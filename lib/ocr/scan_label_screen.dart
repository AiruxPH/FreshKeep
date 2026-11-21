import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../add_groceries_dialog.dart';
import '../data/inventory_database.dart';
import '../domain/food_photo.dart';
import '../domain/ocr/merge_ocr_scans.dart';
import '../domain/ocr/ocr_models.dart';
import '../widgets/ocr/ocr_date_review_card.dart';
import '../widgets/ocr/ocr_scans_list.dart';
import '../widgets/ocr/ocr_status_banner.dart';
import '../widgets/toast/show_freshkeep_toast.dart';
import 'ocr_service.dart';
import 'pick_scan_image.dart';
import 'sample_ocr_service.dart';

/// Separate on-device ML Kit text recognition experiment for single packaged
/// grocery items. Always produces an editable draft and never saves directly.
class ScanLabelScreen extends StatefulWidget {
  const ScanLabelScreen({
    super.key,
    this.ocrService,
    this.pickImage = pickScanImageFromSource,
    this.database,
    this.returnDraftOnly = false,
  });

  final OcrService? ocrService;
  final PickScanImage pickImage;
  final InventoryDatabase? database;
  final bool returnDraftOnly;

  @override
  State<ScanLabelScreen> createState() => _ScanLabelScreenState();
}

class _ScanLabelScreenState extends State<ScanLabelScreen> {
  late final OcrService _service;
  late final bool _ownsService;
  final _nameController = TextEditingController();
  final _scans = <OcrPhotoScan>[];

  OcrDraftResult _merged = mergeOcrScans(const []);
  String? _selectedDate;
  bool _nameEditedManually = false;
  bool _dateEditedManually = false;
  bool _attachPhoto = true;
  bool _busy = false;
  String? _error;
  FoodPhoto? _fallbackPhoto;
  int _nextScanId = 1;

  @override
  void initState() {
    super.initState();
    if (widget.ocrService != null) {
      _service = widget.ocrService!;
      _ownsService = false;
    } else {
      _service = createOcrService();
      _ownsService = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    if (_ownsService) {
      _service.dispose();
    }
    super.dispose();
  }

  FoodPhoto? get _firstPhoto {
    for (final scan in _scans) {
      if (scan.photo != null) return scan.photo;
    }
    return _fallbackPhoto;
  }

  void _recomputeDraft() {
    final merged = mergeOcrScans(_scans);
    _merged = merged;
    if (!_nameEditedManually || _nameController.text.trim().isEmpty) {
      if (merged.suggestedName != null) {
        _nameController.text = merged.suggestedName!;
        _nameEditedManually = false;
      } else if (!_nameEditedManually) {
        _nameController.text = '';
      }
    }
    if (!_dateEditedManually) {
      _selectedDate = merged.dateResult.printedDate;
    }
  }

  Future<void> _scanFromSource(ImageSource source) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    PickedScanImage? picked;
    try {
      picked = await widget.pickImage(source);
      if (!mounted || picked == null) return;
      if (picked.filePath == null || picked.filePath!.trim().isEmpty) {
        if (picked.photo != null) {
          _fallbackPhoto ??= picked.photo;
        }
        setState(() {
          _error =
              'Could not read the selected image path for text scanning. You can enter details manually.';
        });
        return;
      }
      final recognized = await _service.recognizeImagePath(picked.filePath!);
      if (!mounted) return;
      setState(() {
        _scans.add(
          OcrPhotoScan(
            id: 'scan-${_nextScanId++}',
            sourceLabel: picked!.sourceLabel,
            rawText: recognized.rawText,
            elapsedMs: recognized.elapsedMs,
            isSample: recognized.isSample,
            photo: picked.photo,
          ),
        );
        _recomputeDraft();
      });
    } catch (error) {
      if (!mounted) return;
      if (picked?.photo != null) {
        _fallbackPhoto ??= picked!.photo;
      }
      setState(() {
        _error = error is FormatException
            ? error.message.toString()
            : 'Text recognition failed on this image. You can try another photo or enter details manually.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _addSamplePreset(SampleOcrPreset preset) {
    if (_busy) return;
    setState(() {
      _error = null;
      _scans.add(
        OcrPhotoScan(
          id: 'sample-${_nextScanId++}',
          sourceLabel: preset.title,
          rawText: preset.rawText,
          elapsedMs: 0,
          isSample: true,
        ),
      );
      _recomputeDraft();
    });
  }

  void _removeScan(String id) {
    setState(() {
      _scans.removeWhere((scan) => scan.id == id);
      _error = null;
      _recomputeDraft();
    });
  }

  Future<void> _continueToReview() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(
        () => _error = 'Enter or scan a food name before reviewing the draft.',
      );
      return;
    }
    if (name.length > 100) {
      setState(() => _error = 'Use at most 100 characters for the food name.');
      return;
    }
    final summary = _scans.isEmpty
        ? null
        : _scans.map((s) => '${s.sourceLabel}: ${s.rawText}').join('\n---\n');
    final draft = OcrGroceryDraft(
      name: name,
      printedDate: _selectedDate,
      photo: _attachPhoto ? _firstPhoto : null,
      fromSampleMode: _scans.any((s) => s.isSample),
      rawOcrSummary: summary,
    );

    if (widget.returnDraftOnly || widget.database == null) {
      Navigator.pop(context, draft);
      return;
    }

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => AddGroceriesScreen(
          database: widget.database!,
          initialDrafts: [draft],
          ocrService: widget.ocrService,
          pickScanImage: widget.pickImage,
        ),
      ),
    );
    if (saved == true && mounted) {
      showFreshKeepToast(context, message: 'Groceries saved to inventory.');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = _firstPhoto;
    final hasAnySample = _scans.any((s) => s.isSample);
    return Scaffold(
      appBar: AppBar(title: const Text('Scan label (experiment)')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              OcrStatusBanner(
                isOnDeviceSupported: _service.isOnDeviceSupported,
                engineLabel: _service.engineLabel,
              ),
              const SizedBox(height: 8),
              if (_service.isOnDeviceSupported)
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      key: const ValueKey('ocr-take-photo'),
                      onPressed: _busy
                          ? null
                          : () => _scanFromSource(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(
                        _scans.isEmpty ? 'Take label photo' : 'Add camera photo',
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('ocr-pick-photo'),
                      onPressed: _busy
                          ? null
                          : () => _scanFromSource(ImageSource.gallery),
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Choose label photo'),
                    ),
                  ],
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Try a sample packaged label',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Combine a front label with a back panel to preview multi-side scanning.',
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final preset in sampleOcrPresets)
                              ActionChip(
                                key: ValueKey('sample-preset-${preset.id}'),
                                avatar: const Icon(Icons.add, size: 18),
                                label: Text(preset.title),
                                onPressed: _busy
                                    ? null
                                    : () => _addSamplePreset(preset),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (_busy) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
              ],
              if (hasAnySample)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Sample text only — verify real labels directly before relying on dates.',
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Scanned sides · ${_scans.length}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              OcrScansList(
                scans: _scans,
                onRemove: _removeScan,
                enabled: !_busy,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Editable draft name',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const ValueKey('ocr-name-field'),
                        controller: _nameController,
                        enabled: !_busy,
                        maxLength: 100,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Food name',
                          hintText: 'Scanned or entered manually',
                          counterText: '',
                        ),
                        onChanged: (value) {
                          _nameEditedManually = value.trim().isNotEmpty;
                          if (_error != null) setState(() => _error = null);
                        },
                      ),
                      if (photo != null) ...[
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Attach scanned photo to batch'),
                          value: _attachPhoto,
                          onChanged: _busy
                              ? null
                              : (value) => setState(() => _attachPhoto = value),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OcrDateReviewCard(
                dateResult: _merged.dateResult,
                selectedDate: _selectedDate,
                enabled: !_busy,
                onDateChanged: (date) => setState(() {
                  _selectedDate = date;
                  _dateEditedManually = true;
                }),
              ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            top: false,
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      if (MediaQuery.textScalerOf(context).scale(1) > 1.5) ...[
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FilledButton(
                                key: const ValueKey('use-ocr-draft'),
                                onPressed: _busy ? null : _continueToReview,
                                child: Text(
                                  widget.returnDraftOnly
                                      ? 'Use draft'
                                      : 'Review in Add groceries',
                                ),
                              ),
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            key: const ValueKey('use-ocr-draft'),
                            onPressed: _busy ? null : _continueToReview,
                            child: Text(
                              widget.returnDraftOnly
                                  ? 'Use draft'
                                  : 'Review in Add groceries',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
