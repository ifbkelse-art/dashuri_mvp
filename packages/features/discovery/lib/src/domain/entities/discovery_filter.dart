import 'package:equatable/equatable.dart';

import 'host_card.dart';

/// D-06 sort orders supported by GET /v1/discovery/hosts.
enum DiscoverySort {
  recommended('recommended', 'Recommended'),
  rateLow('rate_low', 'Rate: low to high'),
  rateHigh('rate_high', 'Rate: high to low');

  const DiscoverySort(this.wire, this.label);

  final String wire;
  final String label;
}

/// Verified Host filter (2026-11-23): All / Verified / Non-Verified.
enum DiscoveryVerification {
  all('all', 'All'),
  verified('verified', 'Verified'),
  nonVerified('non_verified', 'Non-Verified');

  const DiscoveryVerification(this.wire, this.label);

  final String wire;
  final String label;
}

/// Discovery filters (C01 chips, C03 sheet). Empty fields mean "any".
final class DiscoveryFilter extends Equatable {
  const DiscoveryFilter({
    this.language,
    this.city,
    this.sort = DiscoverySort.recommended,
    this.verification = DiscoveryVerification.all,
  });

  /// ISO 639-1 code, e.g. `hi`.
  final String? language;
  final City? city;
  final DiscoverySort sort;
  final DiscoveryVerification verification;

  bool get hasFilters =>
      language != null ||
      city != null ||
      verification != DiscoveryVerification.all;

  /// Number of active filters (sort excluded), for the filter badge.
  int get activeCount =>
      (language == null ? 0 : 1) +
      (city == null ? 0 : 1) +
      (verification == DiscoveryVerification.all ? 0 : 1);

  DiscoveryFilter copyWith({
    String? Function()? language,
    City? Function()? city,
    DiscoverySort? sort,
    DiscoveryVerification? verification,
  }) => DiscoveryFilter(
    language: language == null ? this.language : language(),
    city: city == null ? this.city : city(),
    sort: sort ?? this.sort,
    verification: verification ?? this.verification,
  );

  Map<String, String> toQuery() => {
    'language': ?language,
    'city_id': ?city?.id,
    'sort': sort.wire,
    if (verification != DiscoveryVerification.all)
      'verification': verification.wire,
  };

  @override
  List<Object?> get props => [language, city, sort, verification];
}

/// The languages offered as chips (code → display name).
const discoveryLanguages = <String, String>{
  'hi': 'Hindi',
  'en': 'English',
  'ta': 'Tamil',
  'te': 'Telugu',
  'bn': 'Bengali',
  'mr': 'Marathi',
  'kn': 'Kannada',
  'ml': 'Malayalam',
  'gu': 'Gujarati',
  'pa': 'Punjabi',
  'ur': 'Urdu',
};

/// Display name for a language code (falls back to the code).
String languageName(String code) =>
    discoveryLanguages[code.toLowerCase()] ?? code;
