import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Signed upload URL for one profile photo (POST /v1/me/photos/upload-tickets).
final class PhotoUploadTicket extends Equatable {
  const PhotoUploadTicket({
    required this.photoId,
    required this.uploadUrl,
    required this.expiresAt,
  });

  final String photoId;
  final Uri uploadUrl;
  final DateTime expiresAt;

  @override
  List<Object?> get props => [photoId, uploadUrl, expiresAt];
}

/// A photo chosen by the user, ready to upload.
final class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.contentType});

  final Uint8List bytes;

  /// One of image/jpeg, image/png, image/webp.
  final String contentType;

  static const allowedContentTypes = {'image/jpeg', 'image/png', 'image/webp'};
}
