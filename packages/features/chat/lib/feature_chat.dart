/// Conversations, messages and the user's messaging-privacy setting.
///
/// Public API: entities, repository contract, use cases, cubits, DI
/// registration and routes. `src/data` stays private to this package.
library;

export 'src/application/conversations_cubit.dart';
export 'src/di/chat_module.dart';
export 'src/domain/entities/chat_message.dart';
export 'src/domain/entities/conversation.dart';
export 'src/domain/entities/messaging_privacy.dart';
export 'src/domain/repositories/chat_repository.dart';
export 'src/domain/usecases/get_messaging_privacy.dart';
export 'src/domain/usecases/list_conversations.dart';
export 'src/domain/usecases/list_messages.dart';
export 'src/domain/usecases/send_message.dart';
export 'src/domain/usecases/start_conversation.dart';
export 'src/domain/usecases/update_messaging_privacy.dart';
export 'src/routes/chat_routes.dart';
