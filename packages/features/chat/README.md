# feature_chat

Conversations, messages and the user's messaging-privacy setting.

## Layers

| Layer | Folder | Contents |
|---|---|---|
| Domain | `lib/src/domain/` | Entities: `Conversation`, `ChatMessage`, `MessagingPrivacy`; contract `ChatRepository`; one use case per action |
| Data | `lib/src/data/` | `ChatRemoteDataSource` (Go API), JSON mappers, `ChatRepositoryImpl` |
| Application | `lib/src/application/` | `ConversationsCubit` (add more cubits/blocs per page) |
| Presentation | `lib/src/presentation/` | **Founder-owned pages and widgets** |
| Wiring | `lib/src/di/`, `lib/src/routes/` | `registerChatFeature(sl)`, `ChatRoutes` |

## API endpoints used

| Use case | Method | Path | Idempotency-Key |
|---|---|---|---|
| `ListConversations` | GET | `/v1/conversations` | — |
| `StartConversation` | POST | `/v1/conversations` | required |
| `ListMessages` | GET | `/v1/conversations/{conversationId}/messages` | — |
| `SendMessage` | POST | `/v1/conversations/{conversationId}/messages` | required |
| `GetMessagingPrivacy` | GET | `/v1/me/messaging-privacy` | — |
| `UpdateMessagingPrivacy` | PUT | `/v1/me/messaging-privacy` | — |

## Business rules and notes

- Founder decision C11: each user chooses who can message them (`everyone` or `past_call_partners`). The server enforces it, plus blocks.
- Messages are sent through the API (privacy, blocks, rate limits and contact-detail filtering are server-side). New messages arrive as realtime hints on `user:<id>`; re-fetch on hint.
- Paid text messaging is NOT a confirmed feature.

## Pages to build

- ConversationsPage (RoutePaths.conversations)
- ConversationPage (RoutePaths.conversation)
- Messaging privacy section in settings
