import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/food_photo.dart';
import 'decode_picked_photo.dart';

/// Recovers an image if Android killed and recreated the activity while the
/// external gallery or camera picker was open.
Future<FoodPhoto?> recoverLostPhoto() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  try {
    final response = await ImagePicker().retrieveLostData();
    if (response.isEmpty || response.file == null) return null;
    return await decodePickedPhoto(response.file);
  } catch (_) {
    return null;
  }
}
