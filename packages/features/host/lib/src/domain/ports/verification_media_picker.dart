import '../entities/host_photo.dart';

/// Captures Verified Host evidence. The host feature has no camera
/// dependency, so the app registers an implementation in GetIt. Without
/// one, the Verified Host page explains that uploads are not available in
/// this build instead of showing dead buttons.
///
/// Evidence is uploaded to a PRIVATE bucket for staff review only; it is
/// never used as a profile photo and no biometric template is created.
abstract interface class VerificationMediaPicker {
  /// A short selfie video (front camera). Null when cancelled.
  Future<PickedPhoto?> recordFaceVideo();

  /// A photo of an identity document. Null when cancelled.
  Future<PickedPhoto?> pickIdImage();
}
