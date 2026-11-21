import 'dart:ui' as ui;

import 'package:image_picker/image_picker.dart';

import '../../domain/food_photo.dart';

/// Validates and decodes an [XFile] picked from gallery, camera, or lost data.
Future<FoodPhoto?> decodePickedPhoto(XFile? file) async {
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
