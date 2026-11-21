import 'package:equatable/equatable.dart';

final class HostCard extends Equatable {
  const HostCard({
    required this.userId,
    required this.displayName,
    required this.photoUrl,
    required this.languages,
    required this.level,
    required this.ratePerMinute,
    required this.availability,
  });

  final String userId;
  final String displayName;
  final String? photoUrl;
  final List<String> languages;
  final int level;
  final int ratePerMinute;
  final String availability;

  @override
  List<Object?> get props => [
    userId,
    displayName,
    photoUrl,
    languages,
    level,
    ratePerMinute,
    availability,
  ];
}
