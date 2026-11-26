import 'package:equatable/equatable.dart';

/// Host lifecycle states from `HostStatus.state`.
abstract final class HostStates {
  static const notApplied = 'not_applied';
  static const applied = 'applied';
  static const kycPending = 'kyc_pending';
  static const approved = 'approved';
  static const suspended = 'suspended';
}

/// KYC states from `HostStatus.kyc_state` (`hosting.hosts.kyc_state`).
abstract final class KycStates {
  static const notStarted = 'not_started';
  static const inProgress = 'in_progress';
  static const approved = 'approved';
  static const rejected = 'rejected';
}

/// GET /v1/host. The `today_*` fields and `kyc_rejection_reason` are MVP
/// additions (contract 2.7); they are null when the server omits them.
final class HostStatus extends Equatable {
  const HostStatus({
    required this.state,
    required this.kycState,
    required this.isAvailable,
    required this.ratePerMinute,
    required this.minRatePerMinute,
    required this.maxRatePerMinute,
    required this.freeCallOptIn,
    this.todayEarnedBeans,
    this.todayCalls,
    this.kycRejectionReason,
    this.level,
    this.verificationStatus = 'not_applied',
    this.verificationNote,
    this.levelMaxRatePerMinute,
    this.nextLevelMaxRatePerMinute,
    this.verifiedRateThreshold = 3000,
    this.onlineSessionId,
    this.onlineSince,
  });

  /// The status of an account that has never applied (GET /v1/host → 404 or
  /// `state: not_applied`).
  static const notApplied = HostStatus(
    state: HostStates.notApplied,
    kycState: KycStates.notStarted,
    isAvailable: false,
    ratePerMinute: 500,
    minRatePerMinute: 500,
    maxRatePerMinute: 1000,
    freeCallOptIn: false,
  );

  final String state;
  final String kycState;
  final bool isAvailable;
  final int ratePerMinute;
  final int minRatePerMinute;
  final int maxRatePerMinute;
  final bool freeCallOptIn;
  final int? todayEarnedBeans;
  final int? todayCalls;
  final String? kycRejectionReason;

  // Verified Host + level pricing (2026-11-23). [maxRatePerMinute] is the
  // highest price this host may set now; [levelMaxRatePerMinute] is the
  // level's ceiling (level × 1,000), reachable above [verifiedRateThreshold]
  // only as an active Verified Host. Null when an older server omits them.
  final int? level;
  final String verificationStatus;
  final String? verificationNote;
  final int? levelMaxRatePerMinute;
  final int? nextLevelMaxRatePerMinute;
  final int verifiedRateThreshold;

  /// The open online session (2026-11-26); null when offline or when the
  /// server does not report sessions yet.
  final String? onlineSessionId;
  final DateTime? onlineSince;

  /// ACTIVE Verified Host (premium badge; not the hosting KYC).
  bool get isVerified => verificationStatus == 'verified';

  /// The level allows more than this host may charge without verification.
  bool get verificationWouldRaiseLimit =>
      !isVerified && (levelMaxRatePerMinute ?? 0) > maxRatePerMinute;

  bool get hasApplied => state != HostStates.notApplied;
  bool get isApproved => state == HostStates.approved;
  bool get isSuspended => state == HostStates.suspended;
  bool get kycRejected => kycState == KycStates.rejected;
  bool get kycInProgress => kycState == KycStates.inProgress;
  bool get kycApproved => kycState == KycStates.approved;
  bool get kycNotStarted => kycState == KycStates.notStarted;

  HostStatus copyWith({bool? isAvailable, bool? freeCallOptIn}) => HostStatus(
    state: state,
    kycState: kycState,
    isAvailable: isAvailable ?? this.isAvailable,
    ratePerMinute: ratePerMinute,
    minRatePerMinute: minRatePerMinute,
    maxRatePerMinute: maxRatePerMinute,
    freeCallOptIn: freeCallOptIn ?? this.freeCallOptIn,
    todayEarnedBeans: todayEarnedBeans,
    todayCalls: todayCalls,
    kycRejectionReason: kycRejectionReason,
    level: level,
    verificationStatus: verificationStatus,
    verificationNote: verificationNote,
    levelMaxRatePerMinute: levelMaxRatePerMinute,
    nextLevelMaxRatePerMinute: nextLevelMaxRatePerMinute,
    verifiedRateThreshold: verifiedRateThreshold,
    onlineSessionId: onlineSessionId,
    onlineSince: onlineSince,
  );

  @override
  List<Object?> get props => [
    state,
    kycState,
    isAvailable,
    ratePerMinute,
    minRatePerMinute,
    maxRatePerMinute,
    freeCallOptIn,
    todayEarnedBeans,
    todayCalls,
    kycRejectionReason,
    level,
    verificationStatus,
    verificationNote,
    levelMaxRatePerMinute,
    nextLevelMaxRatePerMinute,
    verifiedRateThreshold,
    onlineSessionId,
    onlineSince,
  ];
}
