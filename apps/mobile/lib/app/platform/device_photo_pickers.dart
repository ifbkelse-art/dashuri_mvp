import 'dart:typed_data';

import 'package:feature_host/feature_host.dart' as host;
import 'package:feature_profile/feature_profile.dart' as profile;
import 'package:image_picker/image_picker.dart';

/// Picks one photo from the gallery, downscaled on-device (max 1600 px,
/// JPEG quality 85) so uploads stay small. Returns null on cancel.
Future<(List<int>, String)?> _pick(ImagePicker picker) async {
  final file = await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 85,
    requestFullMetadata: false,
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  final name = file.name.toLowerCase();
  final type = name.endsWith('.png')
      ? 'image/png'
      : name.endsWith('.webp')
      ? 'image/webp'
      : 'image/jpeg';
  return (bytes, type);
}

/// Profile (S02) photo picker backed by the platform photo picker.
final class DevicePhotoPicker implements profile.PhotoPicker {
  DevicePhotoPicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  @override
  Future<profile.PickedPhoto?> pick() async {
    final picked = await _pick(_picker);
    if (picked == null) return null;
    return profile.PickedPhoto(bytes: picked.$1, contentType: picked.$2);
  }
}

/// Host profile setup (H09) photo picker.
final class DeviceHostPhotoPicker implements host.HostPhotoPicker {
  DeviceHostPhotoPicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  @override
  Future<host.PickedPhoto?> pickPhoto() async {
    final picked = await _pick(_picker);
    if (picked == null) return null;
    return host.PickedPhoto(
      bytes: Uint8List.fromList(picked.$1),
      contentType: picked.$2,
    );
  }
}

/// Verified Host evidence: a short front-camera face video and a camera
/// photo of an ID document. Uploaded to a PRIVATE bucket for staff review;
/// nothing is processed on the device.
final class DeviceVerificationMediaPicker
    implements host.VerificationMediaPicker {
  DeviceVerificationMediaPicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  @override
  Future<host.PickedPhoto?> recordFaceVideo() async {
    final file = await _picker.pickVideo(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxDuration: const Duration(seconds: 10),
    );
    if (file == null) return null;
    final name = file.name.toLowerCase();
    return host.PickedPhoto(
      bytes: await file.readAsBytes(),
      contentType: name.endsWith('.mov') ? 'video/quicktime' : 'video/mp4',
    );
  }

  @override
  Future<host.PickedPhoto?> pickIdImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 90,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    final name = file.name.toLowerCase();
    return host.PickedPhoto(
      bytes: await file.readAsBytes(),
      contentType: name.endsWith('.png') ? 'image/png' : 'image/jpeg',
    );
  }
}
