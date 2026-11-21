import 'package:equatable/equatable.dart';

/// Coarse city on a profile (`{id, name, state}`, decision F4).
final class ProfileCity extends Equatable {
  const ProfileCity({required this.id, required this.name, this.state = ''});

  final String id;
  final String name;
  final String state;

  @override
  List<Object?> get props => [id, name, state];
}

/// Gender options (D-03). Private: never shown on public profiles.
enum Gender {
  man('man', 'Man'),
  woman('woman', 'Woman'),
  nonBinary('non_binary', 'Non-binary'),
  preferNotToSay('prefer_not_to_say', 'Prefer not to say');

  const Gender(this.wire, this.label);

  final String wire;
  final String label;

  static Gender? fromWire(String? value) =>
      Gender.values.where((g) => g.wire == value).firstOrNull;
}

final class Profile extends Equatable {
  const Profile({
    required this.userId,
    required this.displayName,
    required this.bio,
    required this.languages,
    required this.photoUrls,
    required this.isHost,
    required this.level,
    this.gender,
    this.city,
  });

  final String userId;
  final String displayName;
  final String? bio;

  /// ISO 639-1 codes, e.g. `hi`, `en`.
  final List<String> languages;
  final List<String> photoUrls;
  final bool isHost;
  final int level;

  /// Own profile only (GET /v1/me/profile).
  final Gender? gender;
  final ProfileCity? city;

  String? get photoUrl => photoUrls.isEmpty ? null : photoUrls.first;

  @override
  List<Object?> get props => [
    userId,
    displayName,
    bio,
    languages,
    photoUrls,
    isHost,
    level,
    gender,
    city,
  ];
}

/// Fields for PATCH /v1/me/profile; null fields are left unchanged.
final class ProfileUpdate extends Equatable {
  const ProfileUpdate({
    this.displayName,
    this.bio,
    this.languages,
    this.gender,
    this.cityId,
    this.clearCity = false,
  });

  final String? displayName;
  final String? bio;
  final List<String>? languages;
  final Gender? gender;
  final String? cityId;

  /// Sends `city_id: null` to remove the city.
  final bool clearCity;

  bool get isEmpty =>
      displayName == null &&
      bio == null &&
      languages == null &&
      gender == null &&
      cityId == null &&
      !clearCity;

  @override
  List<Object?> get props => [
    displayName,
    bio,
    languages,
    gender,
    cityId,
    clearCity,
  ];
}

/// Languages offered in S02 (ISO 639-1 → label).
const profileLanguages = <String, String>{
  'hi': 'Hindi',
  'en': 'English',
  'bn': 'Bengali',
  'mr': 'Marathi',
  'te': 'Telugu',
  'ta': 'Tamil',
  'gu': 'Gujarati',
  'ur': 'Urdu',
  'kn': 'Kannada',
  'or': 'Odia',
  'ml': 'Malayalam',
  'pa': 'Punjabi',
};

/// Limits from the API (`UpdateProfileRequest`) and A08 (name 2–20).
const displayNameMinLength = 2;
const displayNameMaxLength = 20;
const bioMaxLength = 300;
