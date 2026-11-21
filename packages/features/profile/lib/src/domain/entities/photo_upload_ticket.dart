import 'package:equatable/equatable.dart';

final class PhotoUploadTicket extends Equatable {
  const PhotoUploadTicket({
    required this.photoId,
    required this.uploadUrl,
    required this.expiresAt,
  });

  final String photoId;
  final String uploadUrl;
  final DateTime expiresAt;

  @override
  List<Object?> get props => [photoId, uploadUrl, expiresAt];
}
