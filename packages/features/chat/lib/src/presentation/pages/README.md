# chat pages (founder-owned)

Put this feature's pages here, one file per page, then register each in `lib/src/routes/chat_routes.dart`.

Planned pages:
- ConversationsPage (RoutePaths.conversations)
- ConversationPage (RoutePaths.conversation)
- Messaging privacy section in settings

Rules: pages read state with `BlocBuilder`/`BlocListener` from the cubits in `lib/src/application/`, use `dashuri_design_system` for styling, and never import `data/` or `dashuri_network`.
