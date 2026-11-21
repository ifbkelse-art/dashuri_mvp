import 'package:equatable/equatable.dart';

/// What V01/V06 show before a paid call: the host's current rate and the
/// customer's available balance (both from the server).
final class PreCallInfo extends Equatable {
  const PreCallInfo({
    required this.hostUserId,
    required this.hostName,
    required this.ratePerMinute,
    required this.availability,
    required this.availableDiamonds,
    this.hostPhotoUrl,
    this.hostAge,
    this.approxPaisePerDiamondMilli,
  });

  final String hostUserId;
  final String hostName;
  final String? hostPhotoUrl;
  final int? hostAge;
  final int ratePerMinute;

  /// `available`, `busy` or `offline`.
  final String availability;
  final int availableDiamonds;

  /// ₹ estimate basis × 1000 (D-07); null when the server did not send it.
  final int? approxPaisePerDiamondMilli;

  /// The server requires 60 s of balance at the host's rate to start (S6).
  /// Shown before the request; the server re-checks authoritatively.
  int get minimumToStart => ratePerMinute;

  bool get hasMinimumBalance => availableDiamonds >= minimumToStart;

  bool get isAvailable => availability == 'available';

  /// Approximate paise per minute, or null when unknown.
  int? get approxPaisePerMinute => approxPaisePerDiamondMilli == null
      ? null
      : (ratePerMinute * approxPaisePerDiamondMilli! / 1000).round();

  /// Whole seconds of talk time the balance covers (display hint only).
  int get talkTimeSeconds =>
      ratePerMinute <= 0 ? 0 : availableDiamonds * 60 ~/ ratePerMinute;

  @override
  List<Object?> get props => [
    hostUserId,
    hostName,
    hostPhotoUrl,
    hostAge,
    ratePerMinute,
    availability,
    availableDiamonds,
    approxPaisePerDiamondMilli,
  ];
}
