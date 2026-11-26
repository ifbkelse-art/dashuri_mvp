import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/conversation.dart';
import '../widgets/inbox_view.dart';

/// Path of one conversation.
String conversationPath(String id) =>
    RoutePaths.withParams(RoutePaths.conversation, {'conversationId': id});

/// CH01/CH03 inbox tab. On expanded windows the selected conversation opens
/// in the right pane ([conversationBuilder] supplies it with its cubit).
class ConversationsPage extends StatefulWidget {
  const ConversationsPage({required this.conversationBuilder, super.key});

  final Widget Function(BuildContext context, Conversation conversation)
  conversationBuilder;

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  Conversation? _selected;

  @override
  Widget build(BuildContext context) {
    final expanded = context.windowSize.isExpanded;
    final selected = _selected;
    return Scaffold(
      body: SafeArea(
        child: TwoPane(
          primary: ChatInboxView(
            selectedId: expanded ? selected?.id : null,
            onOpen: (c) {
              if (context.windowSize.isExpanded) {
                setState(() => _selected = c);
              } else {
                context.push(conversationPath(c.id), extra: c);
              }
            },
          ),
          secondary: !expanded
              ? null
              : selected == null
              ? const EmptyStateView(
                  icon: Icons.chat_bubble_outline,
                  title: 'Select a conversation',
                  message: 'Your messages will appear here.',
                )
              : KeyedSubtree(
                  key: ValueKey(selected.id),
                  child: widget.conversationBuilder(context, selected),
                ),
        ),
      ),
    );
  }
}

/// The conversation route: inbox + conversation side by side on expanded
/// windows, the conversation alone otherwise.
class ConversationScreen extends StatelessWidget {
  const ConversationScreen({
    required this.conversationId,
    required this.conversation,
    super.key,
  });

  final String conversationId;
  final Widget conversation;

  @override
  Widget build(BuildContext context) {
    if (!context.windowSize.isExpanded) return conversation;
    return Scaffold(
      body: SafeArea(
        child: TwoPane(
          primary: ChatInboxView(
            selectedId: conversationId,
            onOpen: (c) {
              if (c.id != conversationId) {
                context.replace(conversationPath(c.id), extra: c);
              }
            },
          ),
          secondary: conversation,
        ),
      ),
    );
  }
}
