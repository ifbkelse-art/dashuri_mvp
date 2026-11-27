import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/conversations_cubit.dart';
import '../../domain/entities/conversation.dart';
import 'chat_format.dart';

/// CH01 inbox list (CH03 when empty). Used alone on phones and as the left
/// pane on expanded windows.
class ChatInboxView extends StatefulWidget {
  const ChatInboxView({required this.onOpen, super.key, this.selectedId});

  final ValueChanged<Conversation> onOpen;
  final String? selectedId;

  @override
  State<ChatInboxView> createState() => _ChatInboxViewState();
}

class _ChatInboxViewState extends State<ChatInboxView> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<ConversationsCubit, ConversationsState>(
      builder: (context, state) {
        final cubit = context.read<ConversationsCubit>();
        final header = Padding(
          padding: EdgeInsets.fromLTRB(
            context.pageGutter,
            DashuriTokens.space4,
            context.pageGutter,
            DashuriTokens.space2,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text('Chats', style: theme.textTheme.displaySmall),
              ),
              IconButton.filledTonal(
                tooltip: 'Messaging privacy',
                onPressed: () => context.push(RoutePaths.privacyMessaging),
                // Same icon as "Who can message me" in Settings.
                icon: const Icon(Icons.mark_chat_read_outlined),
              ),
            ],
          ),
        );
        final Widget body = switch (state) {
          ConversationsStateInitial() ||
          ConversationsStateLoading() => const SkeletonList(),
          ConversationsStateFailed(:final failure) => ErrorStateView(
            title: "Couldn't load your chats",
            message: ChatFormat.failure(failure),
            onRetry: cubit.load,
          ),
          ConversationsStateLoaded(:final data) when data.items.isEmpty =>
            EmptyStateView(
              icon: Icons.forum_outlined,
              title: 'No conversations yet',
              message:
                  'After a video call, you can keep the conversation going '
                  'here, if the other person allows messages.',
              actionLabel: 'Discover hosts',
              onAction: () => context.go(RoutePaths.discovery),
            ),
          final ConversationsStateLoaded s => _list(context, s),
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Expanded(child: body),
          ],
        );
      },
    );
  }

  Widget _list(BuildContext context, ConversationsStateLoaded s) {
    final cubit = context.read<ConversationsCubit>();
    final q = _query.trim().toLowerCase();
    final items = s.data.items
        .where((c) => q.isEmpty || c.peerDisplayName.toLowerCase().contains(q))
        .toList();
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 300) cubit.loadMore();
        return false;
      },
      child: RefreshIndicator(
        onRefresh: cubit.refresh,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: items.length + 2,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.pageGutter,
                  vertical: DashuriTokens.space2,
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search chats',
                  ),
                ),
              );
            }
            if (i == items.length + 1) {
              return s.loadingMore
                  ? const Padding(
                      padding: EdgeInsets.all(DashuriTokens.space4),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : const SizedBox(height: DashuriTokens.space6);
            }
            final c = items[i - 1];
            return _InboxRow(
              conversation: c,
              myUserId: s.myUserId,
              selected: c.id == widget.selectedId,
              onTap: () => widget.onOpen(c),
            );
          },
        ),
      ),
    );
  }
}

class _InboxRow extends StatelessWidget {
  const _InboxRow({
    required this.conversation,
    required this.myUserId,
    required this.selected,
    required this.onTap,
  });

  final Conversation conversation;
  final String? myUserId;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = conversation;
    final unread = c.unreadCount > 0;
    final last = c.lastMessage;
    final preview = last != null
        ? (last.isGift
              ? ChatFormat.giftLineFor(
                  last.body,
                  mine: last.senderId == myUserId,
                )
              : last.senderId == myUserId
              ? 'You: ${last.body}'
              : last.body)
        : (c.lastMessagePreview ?? 'Say hello');
    final name = c.peerDisplayName.isEmpty ? 'Dashuri user' : c.peerDisplayName;
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer.withValues(alpha: .5)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.pageGutter,
            vertical: DashuriTokens.space3,
          ),
          child: Row(
            children: [
              UserAvatar(name: name, url: c.peerPhotoUrl, radius: 28),
              const SizedBox(width: DashuriTokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Expanded (not Flexible + Spacer): two flex-1 siblings
                        // split the free width, which left the time floating
                        // mid-row at a different x for every name length.
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: theme.textTheme.titleSmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (c.peerIsVerified) ...[
                                const SizedBox(width: DashuriTokens.space1),
                                const VerifiedHostBadge(
                                  compact: true,
                                  size: 16,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: DashuriTokens.space2),
                        Text(
                          ChatFormat.listTime(c.updatedAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: unread
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: unread ? FontWeight.w700 : null,
                              color: unread
                                  ? null
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: DashuriTokens.space2),
                          Badge.count(
                            count: c.unreadCount,
                            backgroundColor: theme.colorScheme.primary,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
