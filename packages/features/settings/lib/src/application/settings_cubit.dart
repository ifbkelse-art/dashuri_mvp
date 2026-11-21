import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/consent_state.dart';
import '../domain/usecases/get_consents.dart';

part 'settings_state.dart';

/// Loads ConsentState for the page. Add one method per user action; each calls
/// a use case and emits states. No API or Supabase access here.
final class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._getConsents) : super(const SettingsStateInitial());

  final GetConsents _getConsents;

  Future<void> load() async {
    emit(const SettingsStateLoading());
    final result = await _getConsents(const NoInput());
    emit(switch (result) {
      Success(:final value) => SettingsStateLoaded(value),
      Err(:final failure) => SettingsStateFailed(failure),
    });
  }
}
