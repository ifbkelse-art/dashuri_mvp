import 'package:equatable/equatable.dart';

/// A coarse city (F4), e.g. `{id: pune, name: Pune}`.
final class City extends Equatable {
  const City({required this.id, required this.name, this.state});

  final String id;
  final String name;
  final String? state;

  @override
  List<Object?> get props => [id, name, state];
}

enum HostAvailability {
  available,
  busy,
  offline;

  static HostAvailability parse(String v) =>
      values.asNameMap()[v] ?? HostAvailability.offline;
}

final class HostCard extends Equatable {
  const HostCard({
    required this.userId,
    required this.displayName,
    required this.photoUrl,
    required this.languages,
    required this.level,
    required this.ratePerMinute,
    required this.availability,
    this.city,
    this.age,
    this.isVerified = false,
  });

  final String userId;
  final String displayName;
  final String? photoUrl;

  /// ISO 639-1 codes, e.g. `hi`, `en`.
  final List<String> languages;
  final int level;

  /// Diamonds per minute, set by the host (server value).
  final int ratePerMinute;

  /// `available`, `busy` or `offline`.
  final String availability;
  final City? city;
  final int? age;
  final bool isVerified;

  HostAvailability get status => HostAvailability.parse(availability);

  @override
  List<Object?> get props => [
    userId,
    displayName,
    photoUrl,
    languages,
    level,
    ratePerMinute,
    availability,
    city,
    age,
    isVerified,
  ];
}

/// Host detail for C07–C09: the card plus bio and photos.
final class HostProfile extends Equatable {
  const HostProfile({required this.card, this.bio, this.photoUrls = const []});

  final HostCard card;
  final String? bio;
  final List<String> photoUrls;

  /// Photos to show; falls back to the card photo.
  List<String> get gallery => photoUrls.isNotEmpty
      ? photoUrls
      : [
          if (card.photoUrl != null && card.photoUrl!.isNotEmpty)
            card.photoUrl!,
        ];

  @override
  List<Object?> get props => [card, bio, photoUrls];
}
