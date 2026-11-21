import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/free_call_card.dart';
import '../domain/usecases/get_free_call_card.dart';

part 'free_call_card_state.dart';

/// Loads FreeCallCard for the page. Add one method per user action; each calls
/// a use case and emits states. No API or Supabase access here.
// Not final: page tests mock it.
class FreeCallCardCubit extends Cubit<FreeCallCardState> {
  FreeCallCardCubit(this._getFreeCallCard)
    : super(const FreeCallCardStateInitial());

  final GetFreeCallCard _getFreeCallCard;

  Future<void> load() async {
    emit(const FreeCallCardStateLoading());
    final result = await _getFreeCallCard(const NoInput());
    emit(switch (result) {
      Success(:final value) => FreeCallCardStateLoaded(value),
      Err(:final failure) => FreeCallCardStateFailed(failure),
    });
  }
}
