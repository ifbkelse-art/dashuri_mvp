import 'package:equatable/equatable.dart';

/// Header data for C01/C02. Each part is optional: a failed read hides
/// that part instead of breaking the page.
final class DiscoveryHome extends Equatable {
  const DiscoveryHome({
    this.displayName,
    this.availableDiamonds,
    this.onlineCount,
    this.freeCallAvailable = false,
  });

  final String? displayName;
  final int? availableDiamonds;
  final int? onlineCount;

  /// The Free Call Card is unused and usable on this device (C02).
  final bool freeCallAvailable;

  @override
  List<Object?> get props => [
    displayName,
    availableDiamonds,
    onlineCount,
    freeCallAvailable,
  ];
}
