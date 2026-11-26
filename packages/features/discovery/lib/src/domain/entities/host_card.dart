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

/// A recent photo the host captured in the app when the current online
/// session started (2026-11-26). It is NOT live video and NOT identity
/// verification: always shown as "Captured N minutes ago".
final class HostArrivalPhoto extends Equatable {
  const HostArrivalPhoto({
    required this.url,
    required this.capturedAt,
    this.id,
  });

  /// The photo id from the API (to report this photo).
  final String? id;

  /// Short-lived signed URL.
  final String url;

  /// Server time the photo was taken/uploaded.
  final DateTime capturedAt;

  /// The photo id from the signed path (`<host id>/<photo id>.jpg`), used to
  /// report this specific photo; null if the URL has another shape.
  String? get photoId {
    if (id != null) return id;
    final seg = Uri.tryParse(url)?.pathSegments ?? const <String>[];
    if (seg.isEmpty) return null;
    final last = seg.last;
    return last.endsWith('.jpg') ? last.substring(0, last.length - 4) : null;
  }

  @override
  List<Object?> get props => [url, capturedAt];
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
    this.arrivalPhoto,
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

  /// Optional photo from the current online session (null when none).
  final HostArrivalPhoto? arrivalPhoto;

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
    arrivalPhoto,
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
