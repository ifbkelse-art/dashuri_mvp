import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/inbox_item.dart';
import '../domain/usecases/list_inbox.dart';

part 'inbox_state.dart';

/// Loads `Page<InboxItem>` for the page. Add one method per user action; each calls
/// a use case and emits states. No API or Supabase access here.
final class InboxCubit extends Cubit<InboxState> {
  InboxCubit(this._listInbox) : super(const InboxStateInitial());

  final ListInbox _listInbox;

  Future<void> load() async {
    emit(const InboxStateLoading());
    final result = await _listInbox(const PageRequest());
    emit(switch (result) {
      Success(:final value) => InboxStateLoaded(value),
      Err(:final failure) => InboxStateFailed(failure),
    });
  }
}
