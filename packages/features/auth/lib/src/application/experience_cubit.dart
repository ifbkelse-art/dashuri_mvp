import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

/// A12 choose your experience. The choice is stored on the device per user;
/// the host shell is used only for approved hosts.
final class ExperienceCubit extends Cubit<ExperienceState> {
  ExperienceCubit(this._controller)
    : super(
        ExperienceState(
          selected: _controller.mode ?? ExperienceMode.customer,
          hostModeAvailable: _controller.hostModeAvailable,
        ),
      );

  final ExperienceController _controller;

  void select(ExperienceMode mode) => emit(state.copyWith(selected: mode));

  Future<void> confirm() async {
    emit(state.copyWith(saving: true));
    await _controller.setMode(state.selected);
    emit(state.copyWith(saving: false, saved: true));
  }
}

final class ExperienceState extends Equatable {
  const ExperienceState({
    required this.selected,
    required this.hostModeAvailable,
    this.saving = false,
    this.saved = false,
  });

  final ExperienceMode selected;

  /// The account is an approved host (host mode opens the host shell);
  /// otherwise picking host starts the host application.
  final bool hostModeAvailable;
  final bool saving;
  final bool saved;

  ExperienceState copyWith({
    ExperienceMode? selected,
    bool? saving,
    bool? saved,
  }) => ExperienceState(
    selected: selected ?? this.selected,
    hostModeAvailable: hostModeAvailable,
    saving: saving ?? this.saving,
    saved: saved ?? this.saved,
  );

  @override
  List<Object?> get props => [selected, hostModeAvailable, saving, saved];
}
