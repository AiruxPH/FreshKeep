import 'package:image_picker/image_picker.dart';

import '../../domain/food_photo.dart';
import 'decode_picked_photo.dart';

/// Prompts the platform photo picker for [source] and validates the image.
Future<FoodPhoto?> pickFoodPhotoFromSource(ImageSource source) async {
  final file = await ImagePicker().pickImage(source: source);
  return decodePickedPhoto(file);
}
