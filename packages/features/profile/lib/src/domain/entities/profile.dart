import 'package:equatable/equatable.dart';

final class Profile extends Equatable {
  const Profile({
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
