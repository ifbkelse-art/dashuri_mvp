import 'package:dashuri_network/dashuri_network.dart';
import 'package:get_it/get_it.dart';

import '../application/conversations_cubit.dart';
import '../data/datasources/chat_remote_data_source.dart';
import '../data/repositories/chat_repository_impl.dart';
import '../domain/repositories/chat_repository.dart';
import '../domain/usecases/get_messaging_privacy.dart';
import '../domain/usecases/list_conversations.dart';
import '../domain/usecases/list_messages.dart';
import '../domain/usecases/send_message.dart';
import '../domain/usecases/start_conversation.dart';
import '../domain/usecases/update_messaging_privacy.dart';

/// Registers the chat feature. Called once from the app's composition root.
/// Data sources and repositories are lazy singletons; use cases and
/// cubits are factories (a fresh cubit per page).
void registerChatFeature(GetIt sl) {
  sl
    ..registerLazySingleton<ChatRemoteDataSource>(
      () => ChatRemoteDataSource(sl<ApiClient>()),
    )
    ..registerLazySingleton<ChatRepository>(
      () => ChatRepositoryImpl(sl<ChatRemoteDataSource>()),
    )
    ..registerFactory<ListConversations>(
      () => ListConversations(sl<ChatRepository>()),
    )
    ..registerFactory<StartConversation>(
      () => StartConversation(sl<ChatRepository>()),
    )
    ..registerFactory<ListMessages>(() => ListMessages(sl<ChatRepository>()))
    ..registerFactory<SendMessage>(() => SendMessage(sl<ChatRepository>()))
    ..registerFactory<GetMessagingPrivacy>(
      () => GetMessagingPrivacy(sl<ChatRepository>()),
    )
    ..registerFactory<UpdateMessagingPrivacy>(
      () => UpdateMessagingPrivacy(sl<ChatRepository>()),
    )
    ..registerFactory<ConversationsCubit>(
      () => ConversationsCubit(sl<ListConversations>()),
    );
}
