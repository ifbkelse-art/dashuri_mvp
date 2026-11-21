import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/host_profile.dart';
import '../domain/entities/host_status.dart';
import '../domain/usecases/get_host_status.dart';
import '../domain/usecases/get_my_host_profile.dart';
import '../domain/usecases/set_availability.dart';
import '../domain/usecases/set_free_call_opt_in.dart';
import 'host_presence_controller.dart';

part 'host_dashboard_state.dart';

/// Host home (H11/H12) and availability (H13): status, the online toggle,
/// the Free Call opt-in, and heartbeats through [HostPresenceController].
final class HostDashboardCubit extends Cubit<HostDashboardState> {
  HostDashboardCubit(
    this._getHostStatus, {
    required SetAvailability setAvailability,
    required SetFreeCallOptIn setFreeCallOptIn,
    required GetMyHostProfile getMyProfile,
    required HostPresenceController presence,
  }) : _setAvailability = setAvailability,
       _setFreeCallOptIn = setFreeCallOptIn,
       _getMyProfile = getMyProfile,
       _presence = presence,
       super(const HostDashboardStateInitial()) {
    _rejections = _presence.heartbeatRejected.listen((_) => refresh());
  }

  final GetHostStatus _getHostStatus;
  final SetAvailability _setAvailability;
  final SetFreeCallOptIn _setFreeCallOptIn;
  final GetMyHostProfile _getMyProfile;
  final HostPresenceController _presence;
  late final StreamSubscription<Failure> _rejections;

  Future<void> load() async {
    emit(const HostDashboardStateLoading());
    await _fetch();
  }

  /// Re-reads status without a full-screen spinner (pull to refresh, resume).
  Future<void> refresh() async {
    if (state is! HostDashboardStateLoaded) return load();
    await _fetch();
  }

  Future<void> _fetch() async {
    final profileFuture = _getMyProfile(const NoInput());
    final result = await _getHostStatus(const NoInput());
    final profile = switch (await profileFuture) {
      Success(:final value) => value,
      Err() => null,
    };
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        _presence.setOnline(online: value.isApproved && value.isAvailable);
        emit(HostDashboardStateLoaded(value, profile: profile));
      case Err(:final failure):
        emit(HostDashboardStateFailed(failure));
    }
  }

  /// PUT /v1/host/availability.
  Future<void> setAvailable({required bool available}) async {
    final current = state;
    if (current is! HostDashboardStateLoaded || current.updating) return;
    emit(current.copyWith(updating: true));
    final result = await _setAvailability(available);
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        _presence.setOnline(online: value.isAvailable);
        emit(current.copyWith(data: value, updating: false));
      case Err(:final failure):
        emit(current.copyWith(updating: false, actionFailure: failure));
    }
  }

  /// PUT /v1/host/free-call-opt-in.
  Future<void> setFreeCallOptIn({required bool optIn}) async {
    final current = state;
    if (current is! HostDashboardStateLoaded || current.updating) return;
    emit(current.copyWith(updating: true));
    final result = await _setFreeCallOptIn(optIn);
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        emit(current.copyWith(data: value, updating: false));
      case Err(:final failure):
        emit(current.copyWith(updating: false, actionFailure: failure));
    }
  }

  /// Installs the app-lifecycle hook that pauses heartbeats in background.
  void attachLifecycle() => _presence.attachLifecycle();

  void appPaused() => _presence.appPaused();

  Future<void> appResumed() async {
    _presence.appResumed();
    await refresh();
  }

  @override
  Future<void> close() async {
    await _rejections.cancel();
    return super.close();
  }
}
