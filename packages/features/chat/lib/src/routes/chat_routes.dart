import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../application/conversation_cubit.dart';
import '../application/conversations_cubit.dart';
import '../application/in_call_chat_controller.dart';
import '../domain/entities/conversation.dart';
import '../presentation/pages/conversation_page.dart';
import '../presentation/pages/conversations_page.dart';

ConversationCubit _conversationCubit({
  required String conversationId,
  String? peerUserId,
  String? peerName,
  Conversation? known,
}) {
  final sl = GetIt.instance;
  return ConversationCubit(
    listMessages: sl(),
    sendMessage: sl(),
    startConversation: sl(),
    markRead: sl(),
    listConversations: sl(),
    watchHints: sl(),
    currentUserId: sl(),
    conversationId: conversationId,
    peerUserId: peerUserId,
    peerName: peerName,
    known: known,
    watchReadHints: sl(),
  )..start();
}

/// EXPERIMENT — the in-call chat for [callId]: the pair's conversation
/// (found or created by peer), starting hidden. Call
/// [InCallChatController.close] when the call screen goes away.
InCallChatController openInCallChat(
  GetIt sl, {
  required String callId,
  required String peerUserId,
  required String peerName,
}) => InCallChatController(
  ConversationCubit(
    listMessages: sl(),
    sendMessage: sl(),
    startConversation: sl(),
    markRead: sl(),
    listConversations: sl(),
    watchHints: sl(),
    watchReadHints: sl(),
    currentUserId: sl(),
    conversationId: newConversationId,
    peerUserId: peerUserId,
    peerName: peerName.isEmpty ? null : peerName,
    callId: callId,
    pollInterval: InCallChatController.pollInterval,
    visible: false,
  ),
  peerName: peerName,
);

/// Chat routes. [tabRoutes] is the CH01 inbox tab; [routes] holds the
/// conversation (CH02/CH04/CH05). `/messages/new?peerUserId=&name=` starts a
/// conversation and then replaces the route with the real id.
final class ChatRoutes implements TabFeatureRoutes {
  const ChatRoutes();

  @override
  List<RouteBase> get tabRoutes => [
    GoRoute(
      path: RoutePaths.conversations,
      builder: (context, state) => BlocProvider(
        create: (_) => GetIt.instance<ConversationsCubit>()..load(),
        child: ConversationsPage(
          conversationBuilder: (context, c) => BlocProvider(
            create: (_) => _conversationCubit(conversationId: c.id, known: c),
            child: const ConversationPage(embedded: true),
          ),
        ),
      ),
    ),
  ];

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: RoutePaths.conversation,
      builder: (context, state) {
        final id = state.pathParameters['conversationId']!;
        final q = state.uri.queryParameters;
        final extra = state.extra;
        final known = extra is Conversation && extra.id == id ? extra : null;
        return MultiBlocProvider(
          key: ValueKey(id),
          providers: [
            // Only created on expanded windows, for the inbox pane.
            BlocProvider(
              create: (_) => GetIt.instance<ConversationsCubit>()..load(),
            ),
            BlocProvider(
              create: (_) => _conversationCubit(
                conversationId: id,
                peerUserId: q['peerUserId'],
                peerName: q['name'],
                known: known,
              ),
            ),
          ],
          child: ConversationScreen(
            conversationId: id,
            conversation: ConversationPage(
              replaceRouteWhenStarted: id == newConversationId,
            ),
          ),
        );
      },
    ),
  ];
}
