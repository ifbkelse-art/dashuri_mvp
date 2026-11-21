import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/host_earnings.dart';
import '../domain/usecases/get_earnings.dart';

enum HostEarningsStatus { loading, loaded, failed }

final class HostEarningsState extends Equatable {
  const HostEarningsState({
    this.status = HostEarningsStatus.loading,
    this.earnings,
    this.failure,
  });

  final HostEarningsStatus status;
  final HostEarnings? earnings;
  final Failure? failure;

  @override
  List<Object?> get props => [status, earnings, failure];
}

/// H14 earnings and H15 conversion explainer (GET /v1/host/earnings).
final class HostEarningsCubit extends Cubit<HostEarningsState> {
  HostEarningsCubit(this._getEarnings) : super(const HostEarningsState());

  final GetEarnings _getEarnings;

  Future<void> load() async {
    if (state.earnings == null) emit(const HostEarningsState());
    final result = await _getEarnings(const NoInput());
    if (isClosed) return;
    emit(switch (result) {
      Success(:final value) => HostEarningsState(
        status: HostEarningsStatus.loaded,
        earnings: value,
      ),
      Err(:final failure) => HostEarningsState(
        status: HostEarningsStatus.failed,
        failure: failure,
      ),
    });
  }
}
