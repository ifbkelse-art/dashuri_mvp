import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/device_permission.dart';
import '../domain/usecases/device_permissions.dart';

/// A14 permissions primer and A15 denied state.
class PermissionsCubit extends Cubit<PermissionsState> {
  PermissionsCubit(
    this._get,
    this._request,
    this._openSettings,
    this._experience,
  ) : super(const PermissionsState());

  final GetDevicePermissions _get;
  final RequestDevicePermissions _request;
  final OpenAppSettings _openSettings;
  final ExperienceController _experience;

  Future<void> load() async {
    final result = await _get(const NoInput());
    emit(switch (result) {
      Success(:final value) => state.copyWith(states: value),
      Err(:final failure) => state.copyWith(failure: failure),
    });
  }

  /// "Allow access": camera, microphone, then notifications. Completes the
  /// primer when camera and microphone are granted.
  Future<void> allow() async {
    emit(state.copyWith(busy: true));
    final result = await _request(DevicePermission.values);
    switch (result) {
      case Success(:final value):
        emit(state.copyWith(states: value, busy: false));
        if (value.callReady) await _finish();
      case Err(:final failure):
        emit(state.copyWith(busy: false, failure: failure));
    }
  }

  /// "Not now": browsing is never blocked; calling re-prompts later.
  Future<void> skip() => _finish();

  Future<void> openSettings() async {
    await _openSettings(const NoInput());
  }

  Future<void> _finish() async {
    await _experience.completePermissionsPrimer();
    emit(state.copyWith(done: true));
  }
}

final class PermissionsState extends Equatable {
  const PermissionsState({
    this.states,
    this.busy = false,
    this.done = false,
    this.failure,
  });

  final DevicePermissionStates? states;
  final bool busy;
  final bool done;
  final Failure? failure;

  PermissionsState copyWith({
    DevicePermissionStates? states,
    bool? busy,
    bool? done,
    Failure? failure,
  }) => PermissionsState(
    states: states ?? this.states,
    busy: busy ?? this.busy,
    done: done ?? this.done,
    failure: failure,
  );

  @override
  List<Object?> get props => [states, busy, done, failure];
}
