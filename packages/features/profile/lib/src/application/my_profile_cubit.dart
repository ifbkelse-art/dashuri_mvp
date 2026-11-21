import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/level_progress.dart';
import '../domain/entities/profile.dart';
import '../domain/usecases/get_available_diamonds.dart';
import '../domain/usecases/get_my_level.dart';
import '../domain/usecases/get_my_profile.dart';

part 'my_profile_state.dart';

/// S01 my profile: profile, level (GET /v1/me/level) and Diamond balance,
/// plus the customer/host mode switch for approved hosts.
class MyProfileCubit extends Cubit<MyProfileState> {
  MyProfileCubit(
    this._getMyProfile,
    this._getMyLevel,
    this._getDiamonds,
    this._experience,
  ) : super(const MyProfileStateInitial());

  final GetMyProfile _getMyProfile;
  final GetMyLevel _getMyLevel;
  final GetAvailableDiamonds _getDiamonds;
  final ExperienceController _experience;

  Future<void> load() async {
    emit(const MyProfileStateLoading());
    final results = await (
      _getMyProfile(const NoInput()),
      _getMyLevel(const NoInput()),
      _getDiamonds(const NoInput()),
    ).wait;
    if (isClosed) return;
    final (profile, level, diamonds) = results;
    emit(switch (profile) {
      Success(:final value) => MyProfileStateLoaded(
        value,
        level: level is Success<LevelProgress> ? level.value : null,
        availableDiamonds: diamonds is Success<int> ? diamonds.value : null,
        hostModeAvailable: _experience.hostModeAvailable,
        mode: _experience.effectiveMode,
      ),
      Err(:final failure) => MyProfileStateFailed(failure),
    });
  }

  /// Switches the shell. The router moves to the matching home tab.
  Future<void> setMode(ExperienceMode mode) async {
    await _experience.setMode(mode);
    final s = state;
    if (s is MyProfileStateLoaded && !isClosed) emit(s.copyWith(mode: mode));
  }
}
