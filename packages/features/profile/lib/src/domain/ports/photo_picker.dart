import 'package:equatable/equatable.dart';

/// Image bytes picked by the user, ready to upload.
final class PickedPhoto extends Equatable {
  const PickedPhoto({required this.bytes, required this.contentType});

  final List<int> bytes;

  /// `image/jpeg`, `image/png` or `image/webp`.
  final String contentType;

  @override
  List<Object?> get props => [bytes.length, contentType];
}

/// Device photo picker. No implementation ships yet: the repo has no image
/// picker dependency. When the app registers one in DI, S02 enables
/// "Change photo"; until then the page says photo upload is unavailable.
abstract interface class PhotoPicker {
  /// Null when the user cancelled.
  Future<PickedPhoto?> pick();
}
