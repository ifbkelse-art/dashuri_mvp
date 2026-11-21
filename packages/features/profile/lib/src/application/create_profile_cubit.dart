import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/profile.dart';
import '../domain/usecases/update_my_profile.dart';
import 'profile_failure.dart';

/// A08 display name + A11 gender (onboarding). On success the account
/// status is refreshed, so the route guard moves on to the next step.
class CreateProfileCubit extends Cubit<CreateProfileState> {
  CreateProfileCubit(this._update, this._refresher)
    : super(const CreateProfileState());

  final UpdateMyProfile _update;
  final AccountStatusRefresher _refresher;

  void nameChanged(String name) =>
      emit(state.copyWith(name: name, clearFailure: true));

  void genderSelected(Gender gender) => emit(state.copyWith(gender: gender));

  Future<void> submit() async {
    if (!state.canSubmit) return;
    emit(state.copyWith(submitting: true, clearFailure: true));
    final result = await _update(
      ProfileUpdate(displayName: state.name.trim(), gender: state.gender),
    );
    switch (result) {
      case Success():
        await _refresher.refreshAccountStatus();
        if (!isClosed) emit(state.copyWith(submitting: false, done: true));
      case Err(:final failure):
        emit(
          state.copyWith(
            submitting: false,
            failure: failure,
            nameRejected: rejectedProfileField(failure) != null,
          ),
        );
    }
  }
}

final class CreateProfileState extends Equatable {
  const CreateProfileState({
    this.name = '',
    this.gender,
    this.submitting = false,
    this.done = false,
    this.failure,
    this.nameRejected = false,
  });

  final String name;
  final Gender? gender;
  final bool submitting;
  final bool done;
  final Failure? failure;

  /// The server rejected the name for contact details.
  final bool nameRejected;

  int get nameLength => name.trim().length;

  bool get nameValid =>
      nameLength >= displayNameMinLength && nameLength <= displayNameMaxLength;

  bool get canSubmit => nameValid && gender != null && !submitting;

  CreateProfileState copyWith({
    String? name,
    Gender? gender,
    bool? submitting,
    bool? done,
    Failure? failure,
    bool? nameRejected,
    bool clearFailure = false,
  }) => CreateProfileState(
    name: name ?? this.name,
    gender: gender ?? this.gender,
    submitting: submitting ?? this.submitting,
    done: done ?? this.done,
    failure: clearFailure ? null : (failure ?? this.failure),
    nameRejected: clearFailure ? false : (nameRejected ?? this.nameRejected),
  );

  @override
  List<Object?> get props => [
    name,
    gender,
    submitting,
    done,
    failure,
    nameRejected,
  ];
}
