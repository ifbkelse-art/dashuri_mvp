import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/profile.dart';
import '../domain/usecases/get_my_profile.dart';

part 'my_profile_state.dart';

/// Loads Profile for the page. Add one method per user action; each calls
/// a use case and emits states. No API or Supabase access here.
final class MyProfileCubit extends Cubit<MyProfileState> {
  MyProfileCubit(this._getMyProfile) : super(const MyProfileStateInitial());

  final GetMyProfile _getMyProfile;

  Future<void> load() async {
    emit(const MyProfileStateLoading());
    final result = await _getMyProfile(const NoInput());
    emit(switch (result) {
      Success(:final value) => MyProfileStateLoaded(value),
      Err(:final failure) => MyProfileStateFailed(failure),
    });
  }
}
