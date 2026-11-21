import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/data_export_request.dart';
import '../domain/entities/messaging_privacy.dart';
import '../domain/usecases/request_data_export.dart';
import '../domain/usecases/settings_usecases.dart';

/// S03 settings hub: current messaging rule, data export, sign out and the
/// host/customer switch for approved hosts.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._getPrivacy, this._export, this._signOut, this._experience)
    : super(
        SettingsState(
          hostModeAvailable: _experience.hostModeAvailable,
          mode: _experience.effectiveMode,
        ),
      );

  final GetMessagingPrivacy _getPrivacy;
  final RequestDataExport _export;
  final SignOutUser _signOut;
  final ExperienceController _experience;
  IdempotencyKey? _exportKey;

  Future<void> load() async {
    final result = await _getPrivacy(const NoInput());
    if (result case Success(:final value) when !isClosed) {
      emit(state.copyWith(whoCanMessage: value));
    }
  }

  /// One key per export intent; a retry after a failure reuses it.
  Future<void> requestDataExport() async {
    if (state.exporting) return;
    _exportKey ??= IdempotencyKey.generate();
    emit(state.copyWith(exporting: true, clearMessages: true));
    final result = await _export(_exportKey!);
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        _exportKey = null;
        emit(state.copyWith(exporting: false, export: value));
      case Err(:final failure):
        emit(state.copyWith(exporting: false, failure: failure));
    }
  }

  Future<void> signOut() async {
    emit(state.copyWith(signingOut: true, clearMessages: true));
    final result = await _signOut(const NoInput());
    if (isClosed) return;
    emit(switch (result) {
      Success() => state.copyWith(signingOut: false, signedOut: true),
      Err(:final failure) => state.copyWith(
        signingOut: false,
        failure: failure,
      ),
    });
  }

  Future<void> setMode(ExperienceMode mode) async {
    await _experience.setMode(mode);
    if (!isClosed) emit(state.copyWith(mode: mode));
  }
}

final class SettingsState extends Equatable {
  const SettingsState({
    this.whoCanMessage,
    this.exporting = false,
    this.export,
    this.signingOut = false,
    this.signedOut = false,
    this.failure,
    this.hostModeAvailable = false,
    this.mode = ExperienceMode.customer,
  });

  final WhoCanMessage? whoCanMessage;
  final bool exporting;
  final DataExportRequest? export;
  final bool signingOut;
  final bool signedOut;
  final Failure? failure;
  final bool hostModeAvailable;
  final ExperienceMode mode;

  SettingsState copyWith({
    WhoCanMessage? whoCanMessage,
    bool? exporting,
    DataExportRequest? export,
    bool? signingOut,
    bool? signedOut,
    Failure? failure,
    ExperienceMode? mode,
    bool clearMessages = false,
  }) => SettingsState(
    whoCanMessage: whoCanMessage ?? this.whoCanMessage,
    exporting: exporting ?? this.exporting,
    export: clearMessages ? null : (export ?? this.export),
    signingOut: signingOut ?? this.signingOut,
    signedOut: signedOut ?? this.signedOut,
    failure: clearMessages ? null : (failure ?? this.failure),
    hostModeAvailable: hostModeAvailable,
    mode: mode ?? this.mode,
  );

  @override
  List<Object?> get props => [
    whoCanMessage,
    exporting,
    export,
    signingOut,
    signedOut,
    failure,
    hostModeAvailable,
    mode,
  ];
}
