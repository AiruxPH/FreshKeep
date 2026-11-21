import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/food_photo.dart';
import 'photo_picker/pick_food_photo_from_source.dart';
import 'photo_picker/take_food_photo.dart';

export 'photo_picker/recover_lost_photo.dart';
export 'photo_picker/take_food_photo.dart';

typedef PickFoodPhoto = Future<FoodPhoto?> Function();

Future<FoodPhoto?> pickFoodPhoto() =>
    pickFoodPhotoFromSource(ImageSource.gallery);

class FoodPhotoView extends StatelessWidget {
  const FoodPhotoView({
    super.key,
    required this.photo,
    required this.label,
    this.size = 64,
  });
  final FoodPhoto photo;
  final String label;
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Image.memory(
      photo.bytes,
      width: size,
      height: size,
      fit: BoxFit.cover,
      cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
      semanticLabel: label,
      errorBuilder: (_, error, stack) => SizedBox(
        width: size,
        height: size,
        child: const Tooltip(
          message: 'Photo could not be displayed',
          child: Icon(Icons.broken_image_outlined),
        ),
      ),
    ),
  );
}

/// Selection stays in the parent draft until its Save button is pressed.
class FoodPhotoEditor extends StatefulWidget {
  const FoodPhotoEditor({
    super.key,
    required this.photo,
    required this.onChanged,
    this.enabled = true,
    this.pick = pickFoodPhoto,
    this.capture = takeFoodPhoto,
  });
  final FoodPhoto? photo;
  final ValueChanged<FoodPhoto?> onChanged;
  final bool enabled;
  final PickFoodPhoto pick;
  final PickFoodPhoto capture;
  @override
  State<FoodPhotoEditor> createState() => _FoodPhotoEditorState();
}

class _FoodPhotoEditorState extends State<FoodPhotoEditor> {
  String? _pickingSource;
  String? _error;
  Future<void> _choose(PickFoodPhoto sourcePicker, String source) async {
    setState(() {
      _pickingSource = source;
      _error = null;
    });
    try {
      final photo = await sourcePicker();
      if (mounted && widget.enabled && photo != null) widget.onChanged(photo);
    } catch (error) {
      assert(() {
        debugPrint('Photo selection failed: $error');
        return true;
      }());
      if (mounted) {
        setState(
          () => _error = error is FormatException
              ? error.message.toString()
              : source == 'camera'
              ? 'Could not take a photo. Check camera access or try choosing from gallery.'
              : 'Could not open this photo. Try a JPG, PNG or WebP image.',
        );
      }
    } finally {
      if (mounted) setState(() => _pickingSource = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _pickingSource != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.photo != null)
          FoodPhotoView(
            photo: widget.photo!,
            label: 'Selected food photo',
            size: 96,
          ),
        Wrap(
          spacing: 8,
          children: [
            Tooltip(
              message:
                  'Choose a photo for display only. Food names and dates are still entered manually.',
              child: TextButton.icon(
                onPressed: widget.enabled && !busy
                    ? () => _choose(widget.pick, 'gallery')
                    : null,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  _pickingSource == 'gallery'
                      ? 'Opening photo…'
                      : widget.photo == null
                      ? 'Add photo (optional)'
                      : 'Change photo',
                ),
              ),
            ),
            Tooltip(
              message:
                  'Take a photo for display only. Food names and dates are still entered manually.',
              child: TextButton.icon(
                onPressed: widget.enabled && !busy
                    ? () => _choose(widget.capture, 'camera')
                    : null,
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(
                  _pickingSource == 'camera' ? 'Opening camera…' : 'Take photo',
                ),
              ),
            ),
            if (widget.photo != null)
              TextButton(
                onPressed: widget.enabled && !busy
                    ? () {
                        setState(() => _error = null);
                        widget.onChanged(null);
                      }
                    : null,
                child: const Text('Remove photo'),
              ),
          ],
        ),
        if (widget.photo != null || _error != null)
          const Text('Display only · Up to 5 MB · Saved on this device'),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }
}
