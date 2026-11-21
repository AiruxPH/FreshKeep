import 'package:image_picker/image_picker.dart';

import '../../domain/food_photo.dart';
import 'pick_food_photo_from_source.dart';

/// Captures a display photo using the device camera.
Future<FoodPhoto?> takeFoodPhoto() =>
    pickFoodPhotoFromSource(ImageSource.camera);
