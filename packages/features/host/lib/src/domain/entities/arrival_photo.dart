import 'package:equatable/equatable.dart';

/// Server status of an arrival photo (hosting.arrival_photos.status).
enum ArrivalPhotoStatus {
  awaitingUpload,
  pendingReview,
  approved,
  rejected;

  static ArrivalPhotoStatus parse(String? v) => switch (v) {
    'awaiting_upload' => awaitingUpload,
    'approved' => approved,
    'rejected' => rejected,
    _ => pendingReview,
  };
}

/// The host's optional photo for the CURRENT online session. It belongs to
/// that session only and is never reused; customers see it as "Captured N
/// minutes ago" (never as live video or identity verification).
final class ArrivalPhoto extends Equatable {
  const ArrivalPhoto({
    required this.photoId,
    required this.sessionId,
    required this.status,
    this.capturedAt,
    this.photoUrl,
    this.reason,
  });

  final String photoId;
  final String sessionId;
  final ArrivalPhotoStatus status;
  final DateTime? capturedAt;

  /// Short-lived signed URL of the host's own photo.
  final String? photoUrl;

  /// Why it was rejected (when rejected).
  final String? reason;

  @override
  List<Object?> get props => [
    photoId,
    sessionId,
    status,
    capturedAt,
    photoUrl,
    reason,
  ];
}

/// Signed upload target for one arrival photo.
final class ArrivalUploadTicket extends Equatable {
  const ArrivalUploadTicket({
    required this.photoId,
    required this.sessionId,
    required this.uploadUrl,
    required this.expiresAt,
    required this.maxBytes,
  });

  final String photoId;
  final String sessionId;
  final Uri uploadUrl;
  final DateTime expiresAt;
  final int maxBytes;

  @override
  List<Object?> get props => [
    photoId,
    sessionId,
    uploadUrl,
    expiresAt,
    maxBytes,
  ];
}
