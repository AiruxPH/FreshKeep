import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/food_photo.dart';

typedef PickFoodPhoto = Future<FoodPhoto?> Function();

Future<FoodPhoto?> pickFoodPhoto() async {
  final file = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (file == null) return null;
  if (await file.length() > FoodPhoto.maxBytes) {
    throw const FormatException('Choose a photo up to 5 MB.');
  }
  final photo = FoodPhoto(await file.readAsBytes());
  // Reject unreadable files before they become part of a saved grocery.
  final codec = await ui.instantiateImageCodec(photo.bytes, targetWidth: 128);
  try {
    final frame = await codec.getNextFrame();
    frame.image.dispose();
  } finally {
    codec.dispose();
  }
  return photo;
}

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
  });
  final FoodPhoto? photo;
  final ValueChanged<FoodPhoto?> onChanged;
  final bool enabled;
  final PickFoodPhoto pick;
  @override
  State<FoodPhotoEditor> createState() => _FoodPhotoEditorState();
}

class _FoodPhotoEditorState extends State<FoodPhotoEditor> {
  bool _picking = false;
  String? _error;
  Future<void> _choose() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final photo = await widget.pick();
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
              : 'Could not open this photo. Try a JPG, PNG or WebP image.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
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
            message: 'Choose a photo for display only. Food names and dates are still entered manually.',
            child: TextButton.icon(
              onPressed: widget.enabled && !_picking ? _choose : null,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                _picking
                    ? 'Opening photo…'
                    : widget.photo == null
                    ? 'Add photo (optional)'
                    : 'Change photo',
              ),
            ),
          ),
          if (widget.photo != null)
            TextButton(
              onPressed: widget.enabled && !_picking
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
