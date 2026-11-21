import 'package:equatable/equatable.dart';

/// Server view of the signed-in account (GET /v1/me). Route guards use this,
/// never token claims decoded on the device.
final class AccountStatus extends Equatable {
  const AccountStatus({
    required this.userId,
    required this.ageEligible,
    required this.isHost,
    required this.restriction,
    this.profileComplete = false,
    this.rulesAccepted = false,
    this.hostState,
  });

  final String userId;

  /// False until the user passes the 18+ gate. Minor protection is mandatory.
  final bool ageEligible;
  final bool isHost;

  /// Active enforcement (e.g. `suspended`), or null.
  final String? restriction;

  /// Display name and gender are set (A08/A11).
  final bool profileComplete;

  /// The current community rules version was accepted (A13).
  final bool rulesAccepted;

  /// `applied|kyc_pending|approved|suspended`, or null when never applied.
  final String? hostState;

  /// An approved host can use the host shell.
  bool get isApprovedHost => isHost && hostState == 'approved';

  /// Restrictions that lock the whole app to the account-status page.
  bool get isLockedOut => restriction == 'suspended' || restriction == 'banned';

  @override
  List<Object?> get props => [
    userId,
    ageEligible,
    isHost,
    restriction,
    profileComplete,
    rulesAccepted,
    hostState,
  ];
}
