import 'package:equatable/equatable.dart';

/// Device coordinates reduced to 2 decimal places (≈ 1 km) before they leave
/// the device. They are sent once to resolve a city and never stored.
final class CoarseCoordinates extends Equatable {
  CoarseCoordinates(double latitude, double longitude)
    : latitude = round2(latitude),
      longitude = round2(longitude);

  final double latitude;
  final double longitude;

  static double round2(double v) => (v * 100).roundToDouble() / 100;

  @override
  List<Object?> get props => [latitude, longitude];
}
