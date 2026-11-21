import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/conversation.dart';
import '../domain/usecases/list_conversations.dart';

part 'conversations_state.dart';

/// Loads `Page<Conversation>` for the page. Add one method per user action; each calls
/// a use case and emits states. No API or Supabase access here.
final class ConversationsCubit extends Cubit<ConversationsState> {
  ConversationsCubit(this._listConversations)
    : super(const ConversationsStateInitial());

  final ListConversations _listConversations;

  Future<void> load() async {
    emit(const ConversationsStateLoading());
    final result = await _listConversations(const PageRequest());
    emit(switch (result) {
      Success(:final value) => ConversationsStateLoaded(value),
      Err(:final failure) => ConversationsStateFailed(failure),
    });
  }
}
