import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/host_earnings.dart';
import '../domain/entities/host_status.dart';
import '../domain/usecases/get_host_status.dart';
import '../domain/usecases/set_rate.dart';

enum HostRateStatus { loading, loadFailed, ready, saving, saved }

enum RateError { belowMinimum, abovePlatformMaximum, aboveLevelLimit }

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

  /// Upper bound for this host: the level cap within the platform range.
  int get limit => (host?.maxRatePerMinute ?? BeanRules.maxRate).clamp(
    BeanRules.minRate,
    BeanRules.maxRate,
  );
  int get floor => (host?.minRatePerMinute ?? BeanRules.minRate).clamp(
    BeanRules.minRate,
    BeanRules.maxRate,
  );
  int get beansPerMinute => BeanRules.beansPerMinute(rate);
  bool get isDirty => host != null && rate != host!.ratePerMinute;

  @override
  List<Object?> get props => [status, host, rate, error, failure];
}

/// H10: choose a rate within 500–10,000 Diamonds/min and the level cap
/// (PUT /v1/host/rate). Applies from the next call.
final class HostRateCubit extends Cubit<HostRateState> {
  HostRateCubit(this._getHostStatus, this._setRate)
    : super(const HostRateState());

  final GetHostStatus _getHostStatus;
  final SetRate _setRate;

  static RateError? validate(int rate, {required int floor, required int limit}) {
    if (rate < BeanRules.minRate || rate < floor) return RateError.belowMinimum;
    if (rate > BeanRules.maxRate) return RateError.abovePlatformMaximum;
    if (rate > limit) return RateError.aboveLevelLimit;
    return null;
  }

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
        error: validate(rate, floor: state.floor, limit: state.limit),
      ),
    );
  }

  void increment() => setRate(
    (state.rate + BeanRules.rateStep).clamp(BeanRules.minRate, BeanRules.maxRate),
  );

  void decrement() => setRate(
    (state.rate - BeanRules.rateStep).clamp(BeanRules.minRate, BeanRules.maxRate),
  );

  Future<void> save() async {
    final host = state.host;
    if (host == null || state.status == HostRateStatus.saving) return;
    final error = validate(state.rate, floor: state.floor, limit: state.limit);
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
      HostRateState(status: HostRateStatus.saving, host: host, rate: state.rate),
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
