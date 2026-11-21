import 'package:image_picker/image_picker.dart';

import '../domain/food_photo.dart';
import '../widgets/photo_picker/decode_picked_photo.dart';

/// Decoded packaging photo paired with its temporary path for on-device ML Kit.
class PickedScanImage {
  const PickedScanImage({
    required this.sourceLabel,
    this.filePath,
    this.photo,
  });

  final String sourceLabel;
  final String? filePath;
  final FoodPhoto? photo;
}

typedef PickScanImage = Future<PickedScanImage?> Function(ImageSource source);

/// Prompts the device camera or gallery and validates the selected image.
Future<PickedScanImage?> pickScanImageFromSource(ImageSource source) async {
  final picked = await ImagePicker().pickImage(source: source);
  if (picked == null) return null;
  final photo = await decodePickedPhoto(picked);
  if (photo == null) return null;
  return PickedScanImage(
    sourceLabel: source == ImageSource.camera ? 'Camera photo' : 'Gallery photo',
    filePath: picked.path,
    photo: photo,
  );
}
