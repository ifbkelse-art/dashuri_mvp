import 'package:feature_reels/feature_reels.dart';
import 'package:image_picker/image_picker.dart';

/// EXPERIMENT — Reels video picker on the existing `image_picker`
/// dependency: camera recording (capped at 60 s, rear camera) or gallery.
final class DeviceReelVideoPicker implements ReelVideoPicker {
  DeviceReelVideoPicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  @override
  Future<PickedVideo?> pick(ReelVideoSource source) async {
    final file = await _picker.pickVideo(
      source: source == ReelVideoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxDuration: const Duration(seconds: 60),
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final name = file.name.toLowerCase();
    return PickedVideo(
      bytes: bytes,
      contentType: name.endsWith('.mov') ? 'video/quicktime' : 'video/mp4',
      name: file.name,
    );
  }
}
