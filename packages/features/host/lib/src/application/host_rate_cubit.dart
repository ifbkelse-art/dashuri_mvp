import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/host_earnings.dart';
import '../domain/entities/host_status.dart';
import '../domain/usecases/get_host_status.dart';
import '../domain/usecases/set_rate.dart';

enum HostRateStatus { loading, loadFailed, ready, saving, saved }

enum RateError {
  belowMinimum,
  abovePlatformMaximum,
  aboveLevelLimit,

  /// Above 3,000 D/min without an active Verified Host status.
  requiresVerification,
}

final class HostRateState extends Equatable {
  const HostRateState({
    this.status = HostRateStatus.loading,
    this.host,
    this.rate = BeanRules.minRate,
    this.error,
    this.failure,
  });

  final HostRateStatus status;
  final HostStatus? host;

  /// Rate being edited (Diamonds per minute).
  final int rate;
  final RateError? error;
  final Failure? failure;

  /// Upper bound for this host now: the level cap, and 3,000 unless an
  /// active Verified Host (server-provided `max_rate_per_minute`).
  int get limit => (host?.maxRatePerMinute ?? BeanRules.maxRate).clamp(
    BeanRules.minRate,
    BeanRules.maxRate,
  );
  int get floor => (host?.minRatePerMinute ?? BeanRules.minRate).clamp(
    BeanRules.minRate,
    BeanRules.maxRate,
  );

  /// The level's own ceiling (level × 1,000).
  int get levelLimit =>
      (host?.levelMaxRatePerMinute ?? limit).clamp(limit, BeanRules.maxRate);
  int get verifiedThreshold => host?.verifiedRateThreshold ?? 3000;
  bool get isVerified => host?.isVerified ?? false;

  /// Show "Become a Verified Host" (non-verified hosts only).
  bool get showVerificationCta => host != null && !isVerified;
  int get beansPerMinute => BeanRules.beansPerMinute(rate);
  bool get isDirty => host != null && rate != host!.ratePerMinute;

  @override
  List<Object?> get props => [status, host, rate, error, failure];
}

/// H10: choose an integer rate (PUT /v1/host/rate). Founder rules
/// 2026-11-23: minimum 500; maximum level × 1,000; above 3,000 only for an
/// active Verified Host. Applies from the next call.
final class HostRateCubit extends Cubit<HostRateState> {
  HostRateCubit(this._getHostStatus, this._setRate)
    : super(const HostRateState());

  final GetHostStatus _getHostStatus;
  final SetRate _setRate;

  /// Client-side check for instant feedback only; the server decides.
  static RateError? validate(
    int rate, {
    required int floor,
    required int limit,
    int? levelLimit,
    int verifiedThreshold = 3000,
  }) {
    if (rate < BeanRules.minRate || rate < floor) return RateError.belowMinimum;
    if (rate > BeanRules.maxRate) return RateError.abovePlatformMaximum;
    if (rate > limit) {
      return rate > verifiedThreshold && rate <= (levelLimit ?? limit)
          ? RateError.requiresVerification
          : RateError.aboveLevelLimit;
    }
    return null;
  }

  RateError? _check(int rate) => validate(
    rate,
    floor: state.floor,
    limit: state.limit,
    levelLimit: state.levelLimit,
    verifiedThreshold: state.verifiedThreshold,
  );

  Future<void> load() async {
    emit(const HostRateState());
    final result = await _getHostStatus(const NoInput());
    if (isClosed) return;
    emit(switch (result) {
      Success(:final value) => HostRateState(
        status: HostRateStatus.ready,
        host: value,
        rate: value.ratePerMinute,
      ),
      Err(:final failure) => HostRateState(
        status: HostRateStatus.loadFailed,
        failure: failure,
      ),
    });
  }

  void setRate(int rate) {
    if (state.host == null) return;
    emit(
      HostRateState(
        status: HostRateStatus.ready,
        host: state.host,
        rate: rate,
        error: _check(rate),
      ),
    );
  }

  void increment() => setRate(
    (state.rate + BeanRules.rateStep).clamp(
      BeanRules.minRate,
      BeanRules.maxRate,
    ),
  );

  void decrement() => setRate(
    (state.rate - BeanRules.rateStep).clamp(
      BeanRules.minRate,
      BeanRules.maxRate,
    ),
  );

  Future<void> save() async {
    final host = state.host;
    if (host == null || state.status == HostRateStatus.saving) return;
    final error = _check(state.rate);
    if (error != null) {
      emit(
        HostRateState(
          status: HostRateStatus.ready,
          host: host,
          rate: state.rate,
          error: error,
        ),
      );
      return;
    }
    emit(
      HostRateState(
        status: HostRateStatus.saving,
        host: host,
        rate: state.rate,
      ),
    );
    final result = await _setRate(state.rate);
    if (isClosed) return;
    emit(switch (result) {
      Success(:final value) => HostRateState(
        status: HostRateStatus.saved,
        host: value,
        rate: value.ratePerMinute,
      ),
      Err(failure: BusinessRuleFailure(code: 'rate_outside_level_limits')) =>
        HostRateState(
          status: HostRateStatus.ready,
          host: host,
          rate: state.rate,
          error: RateError.aboveLevelLimit,
          failure: const BusinessRuleFailure(code: 'rate_outside_level_limits'),
        ),
      Err(
        failure: BusinessRuleFailure(code: 'verification_required_for_rate'),
      ) =>
        HostRateState(
          status: HostRateStatus.ready,
          host: host,
          rate: state.rate,
          error: RateError.requiresVerification,
          failure: const BusinessRuleFailure(
            code: 'verification_required_for_rate',
          ),
        ),
      Err(failure: BusinessRuleFailure(code: 'rate_below_minimum')) =>
        HostRateState(
          status: HostRateStatus.ready,
          host: host,
          rate: state.rate,
          error: RateError.belowMinimum,
        ),
      Err(failure: ValidationFailure()) => HostRateState(
        status: HostRateStatus.ready,
        host: host,
        rate: state.rate,
        error: state.rate < BeanRules.minRate
            ? RateError.belowMinimum
            : RateError.abovePlatformMaximum,
      ),
      Err(:final failure) => HostRateState(
        status: HostRateStatus.ready,
        host: host,
        rate: state.rate,
        failure: failure,
      ),
    });
  }
}
