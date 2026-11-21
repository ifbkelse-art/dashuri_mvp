import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/host_status.dart';
import '../domain/usecases/get_host_status.dart';

part 'host_dashboard_state.dart';

/// Loads HostStatus for the page. Add one method per user action; each calls
/// a use case and emits states. No API or Supabase access here.
final class HostDashboardCubit extends Cubit<HostDashboardState> {
  HostDashboardCubit(this._getHostStatus)
    : super(const HostDashboardStateInitial());

  final GetHostStatus _getHostStatus;

  Future<void> load() async {
    emit(const HostDashboardStateLoading());
    final result = await _getHostStatus(const NoInput());
    emit(switch (result) {
      Success(:final value) => HostDashboardStateLoaded(value),
      Err(:final failure) => HostDashboardStateFailed(failure),
    });
  }
}
