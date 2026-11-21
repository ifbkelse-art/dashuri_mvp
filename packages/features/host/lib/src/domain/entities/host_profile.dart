import 'package:equatable/equatable.dart';

/// The signed-in user's own profile (GET /v1/me/profile), as the host
/// application needs it (H09, H23).
final class HostProfile extends Equatable {
  const HostProfile({
    required this.userId,
    required this.displayName,
    required this.bio,
    required this.languages,
    required this.photoUrls,
    required this.isHost,
    required this.level,
  });

  final String userId;
  final String displayName;
  final String? bio;
  final List<String> languages;
  final List<String> photoUrls;
  final bool isHost;
  final int level;

  String? get coverPhotoUrl => photoUrls.isEmpty ? null : photoUrls.first;

  @override
  List<Object?> get props => [
    userId,
    displayName,
    bio,
    languages,
    photoUrls,
    isHost,
    level,
  ];
}
