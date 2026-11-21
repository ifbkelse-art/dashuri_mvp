import 'package:equatable/equatable.dart';

/// Server view of the signed-in account (GET /v1/me). Route guards use this,
/// never token claims decoded on the device.
final class AccountStatus extends Equatable {
  const AccountStatus({
    required this.userId,
    required this.ageEligible,
    required this.isHost,
    required this.restriction,
  });

  final String userId;

  /// False until the user passes the 18+ gate. Minor protection is mandatory.
  final bool ageEligible;
  final bool isHost;

  /// Active enforcement (e.g. `suspended`), or null.
  final String? restriction;

  @override
  List<Object?> get props => [userId, ageEligible, isHost, restriction];
}
