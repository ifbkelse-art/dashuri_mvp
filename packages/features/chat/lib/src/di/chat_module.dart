import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';
import 'package:get_it/get_it.dart';

import '../application/conversations_cubit.dart';
import '../data/datasources/chat_remote_data_source.dart';
import '../data/repositories/chat_repository_impl.dart';
import '../domain/repositories/chat_repository.dart';
import '../domain/usecases/chat_extras.dart';
import '../domain/usecases/get_messaging_privacy.dart';
import '../domain/usecases/list_conversations.dart';
import '../domain/usecases/list_messages.dart';
import '../domain/usecases/send_message.dart';
import '../domain/usecases/start_conversation.dart';
import '../domain/usecases/update_messaging_privacy.dart';

/// Registers the chat feature. Needs `ApiClient`, `RealtimeGateway` and
/// `SessionGateway`. `ConversationCubit` is built in the route (it takes
/// route parameters) from the use cases registered here.
void registerChatFeature(GetIt sl) {
  sl
    ..registerLazySingleton<ChatRemoteDataSource>(
      () => ChatRemoteDataSource(sl<ApiClient>()),
    )
    ..registerLazySingleton<ChatRepository>(
      () => ChatRepositoryImpl(
        sl<ChatRemoteDataSource>(),
        realtime: sl<RealtimeGateway>(),
        session: sl<SessionGateway>(),
      ),
    )
    ..registerFactory<ListConversations>(
      () => ListConversations(sl<ChatRepository>()),
    )
    ..registerFactory<StartConversation>(
      () => StartConversation(sl<ChatRepository>()),
    )
    ..registerFactory<ListMessages>(() => ListMessages(sl<ChatRepository>()))
    ..registerFactory<SendMessage>(() => SendMessage(sl<ChatRepository>()))
    ..registerFactory<MarkConversationRead>(
      () => MarkConversationRead(sl<ChatRepository>()),
    )
    ..registerFactory<WatchChatHints>(
      () => WatchChatHints(sl<ChatRepository>()),
    )
    ..registerFactory<WatchChatHintMessages>(
      () => WatchChatHintMessages(sl<ChatRepository>()),
    )
    ..registerFactory<WatchReadHints>(
      () => WatchReadHints(sl<ChatRepository>()),
    )
    ..registerFactory<GetCurrentUserId>(
      () => GetCurrentUserId(sl<ChatRepository>()),
    )
    ..registerFactory<GetMessagingPrivacy>(
      () => GetMessagingPrivacy(sl<ChatRepository>()),
    )
    ..registerFactory<UpdateMessagingPrivacy>(
      () => UpdateMessagingPrivacy(sl<ChatRepository>()),
    )
    ..registerFactory<ConversationsCubit>(
      () => ConversationsCubit(
        sl<ListConversations>(),
        sl<WatchChatHints>(),
        sl<GetCurrentUserId>(),
      ),
    );
}
