import 'dart:typed_data';

/// An owned, immutable image; no temporary picker paths are persisted.
class FoodPhoto {
  factory FoodPhoto(Uint8List data) {
    if (data.isEmpty || data.length > maxBytes) {
      throw const FormatException('Choose a photo up to 5 MB.');
    }
    return FoodPhoto._(Uint8List.fromList(data));
  }
  const FoodPhoto._(this._bytes);
  static const maxBytes = 5 * 1024 * 1024;
  final Uint8List _bytes;
  // Native typed arrays are required at Flutter web / SQLite boundaries.
  // Return a copy so callers cannot mutate the reviewed draft.
  Uint8List get bytes => Uint8List.fromList(_bytes);

  bool sameAs(FoodPhoto? other) {
    if (other == null || _bytes.length != other._bytes.length) return false;
    for (var i = 0; i < _bytes.length; i++) {
      if (_bytes[i] != other._bytes[i]) return false;
    }
    return true;
  }
}
