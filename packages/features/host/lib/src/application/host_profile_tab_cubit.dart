import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/host_profile.dart';
import '../domain/entities/host_status.dart';
import '../domain/usecases/get_host_status.dart';
import '../domain/usecases/get_my_host_profile.dart';
import '../domain/usecases/set_availability.dart';
import 'host_presence_controller.dart';

enum HostProfileTabStatus { loading, loaded, failed, switching }

final class HostProfileTabState extends Equatable {
  const HostProfileTabState({
    this.status = HostProfileTabStatus.loading,
    this.profile,
    this.host,
    this.failure,
  });

  final HostProfileTabStatus status;
  final HostProfile? profile;
  final HostStatus? host;
  final Failure? failure;

  @override
  List<Object?> get props => [status, profile, host, failure];
}

/// H23 host profile tab: profile summary and the switch to customer mode.
final class HostProfileTabCubit extends Cubit<HostProfileTabState> {
  HostProfileTabCubit(
    this._getProfile,
    this._getHostStatus,
    this._setAvailability,
    this._presence,
  ) : super(const HostProfileTabState());

  final GetMyHostProfile _getProfile;
  final GetHostStatus _getHostStatus;
  final SetAvailability _setAvailability;
  final HostPresenceController _presence;

  Future<void> load() async {
    emit(const HostProfileTabState());
    final profileFuture = _getProfile(const NoInput());
    final status = await _getHostStatus(const NoInput());
    final profile = await profileFuture;
    if (isClosed) return;
    switch ((profile, status)) {
      case (Success(value: final p), Success(value: final h)):
        emit(
          HostProfileTabState(
            status: HostProfileTabStatus.loaded,
            profile: p,
            host: h,
          ),
        );
      case (Err(:final failure), _) || (_, Err(:final failure)):
        emit(
          HostProfileTabState(
            status: HostProfileTabStatus.failed,
            failure: failure,
          ),
        );
    }
  }

  /// Goes offline first (so customers can't call a host who left host
  /// mode), stops heartbeats, then runs the app's [switchToCustomer].
  /// Returns false when going offline failed; the mode is not switched.
  Future<bool> switchToCustomer(
    Future<void> Function() switchToCustomer,
  ) async {
    final current = state;
    if (current.status != HostProfileTabStatus.loaded) return false;
    emit(
      HostProfileTabState(
        status: HostProfileTabStatus.switching,
        profile: current.profile,
        host: current.host,
      ),
    );
    if (current.host?.isAvailable ?? false) {
      final result = await _setAvailability(false);
      if (result case Err(:final failure)) {
        if (!isClosed) {
          emit(
            HostProfileTabState(
              status: HostProfileTabStatus.loaded,
              profile: current.profile,
              host: current.host,
              failure: failure,
            ),
          );
        }
        return false;
      }
    }
    _presence.setOnline(online: false);
    await switchToCustomer();
    if (!isClosed) {
      emit(
        HostProfileTabState(
          status: HostProfileTabStatus.loaded,
          profile: current.profile,
          host: current.host?.copyWith(isAvailable: false),
        ),
      );
    }
    return true;
  }
}
