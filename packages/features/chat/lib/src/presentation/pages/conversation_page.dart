import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/conversation_cubit.dart';
import '../widgets/chat_format.dart';
import 'conversations_page.dart';

/// CH02 conversation, CH04 messaging restricted, CH05 filtered message.
class ConversationPage extends StatefulWidget {
  const ConversationPage({
    super.key,
    this.embedded = false,
    this.replaceRouteWhenStarted = false,
  });

  /// Shown as the right pane of the inbox (no back button).
  final bool embedded;

  /// The route was `/messages/new?peerUserId=…`: once the server created the
  /// conversation, replace the route with the real id.
  final bool replaceRouteWhenStarted;

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send(ConversationCubit cubit) {
    final text = _text.text;
    if (text.trim().isEmpty) return;
    _text.clear();
    cubit.send(text);
  }

  String _withQuery(String path, Map<String, String> q) =>
      Uri(path: path, queryParameters: q).toString();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConversationCubit, ConversationState>(
      listenWhen: (a, b) =>
          a.conversationId != b.conversationId ||
          (b.restoredDraft != null && a.restoredDraft != b.restoredDraft),
      listener: (context, state) {
        final draft = state.restoredDraft;
        if (draft != null) {
          _text
            ..text = draft
            ..selection = TextSelection.collapsed(offset: draft.length);
          _focus.requestFocus();
        }
        final id = state.conversationId;
        if (widget.replaceRouteWhenStarted && id != null) {
          context.replace(conversationPath(id));
        }
      },
      builder: (context, state) {
        final cubit = context.read<ConversationCubit>();
        final name = state.peerName ?? 'Conversation';
        final peer = state.peerUserId;
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: !widget.embedded,
            titleSpacing: widget.embedded ? DashuriTokens.space4 : 0,
            title: Row(
              children: [
                UserAvatar(name: name, url: state.peerPhotoUrl, radius: 20),
                const SizedBox(width: DashuriTokens.space3),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              if (peer != null) ...[
                IconButton(
                  tooltip: 'Video call',
                  icon: const Icon(Icons.videocam_outlined),
                  onPressed: () => context.push(
                    RoutePaths.withParams(RoutePaths.preCall, {'userId': peer}),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  onSelected: (v) => context.push(
                    _withQuery(RoutePaths.report, {
                      'userId': peer,
                      'name': name,
                      if (v == 'block') 'mode': 'block',
                    }),
                  ),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'report', child: Text('Report')),
                    PopupMenuItem(value: 'block', child: Text('Block')),
                  ],
                ),
              ],
            ],
          ),
          body: SafeArea(
            top: false,
            child: ResponsiveCenter(
              maxWidth: 760,
              padding: EdgeInsets.zero,
              child: switch (state.status) {
                ConversationStatus.starting ||
                ConversationStatus.loading => const LoadingView(),
                ConversationStatus.failed => ErrorStateView(
                  message: ChatFormat.failure(state.failure!),
                  onRetry: cubit.retry,
                ),
                ConversationStatus.restricted => _Restricted(
                  name: name,
                  photoUrl: state.peerPhotoUrl,
                  onCall: peer == null
                      ? null
                      : () => context.push(
                          RoutePaths.withParams(RoutePaths.preCall, {
                            'userId': peer,
                          }),
                        ),
                ),
                ConversationStatus.ready => Column(
                  children: [
                    Expanded(
                      child: _Messages(state: state, cubit: cubit),
                    ),
                    if (state.filterNotice) const _FilterNotice(),
                    if (state.sendFailure != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          ChatFormat.failure(state.sendFailure!),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: DashuriTokens.error),
                        ),
                      ),
                    _Composer(
                      controller: _text,
                      focusNode: _focus,
                      hint: 'Message $name…',
                      onChanged: (_) => cubit.dismissFilterNotice(),
                      onSend: () => _send(cubit),
                    ),
                  ],
                ),
              },
            ),
          ),
        );
      },
    );
  }
}

class _Messages extends StatelessWidget {
  const _Messages({required this.state, required this.cubit});

  final ConversationState state;
  final ConversationCubit cubit;

  @override
  Widget build(BuildContext context) {
    final bubbles = state.bubbles;
    if (bubbles.isEmpty) {
      return const EmptyStateView(
        icon: Icons.waving_hand_outlined,
        title: 'Say hello',
        message: 'Messages are text only. Keep conversations on Dashuri.',
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        // reverse: true, so "after" is towards older messages.
        if (n.metrics.extentAfter < 300) cubit.loadOlder();
        return false;
      },
      child: ListView.builder(
        reverse: true,
        padding: const EdgeInsets.symmetric(
          horizontal: DashuriTokens.space4,
          vertical: DashuriTokens.space3,
        ),
        itemCount: bubbles.length + 1,
        itemBuilder: (context, i) {
          if (i == bubbles.length) {
            return state.loadingOlder
                ? const Padding(
                    padding: EdgeInsets.all(DashuriTokens.space3),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : const SizedBox.shrink();
          }
          final b = bubbles[bubbles.length - 1 - i];
          return _Bubble(
            bubble: b,
            onRetry: b.status == BubbleStatus.failed
                ? () => cubit.retrySend(b.localId)
                : null,
          );
        },
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.bubble, this.onRetry});

  final ChatBubble bubble;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mine = bubble.mine;
    final notSent =
        bubble.status == BubbleStatus.failed ||
        bubble.status == BubbleStatus.rejected;
    final meta = switch (bubble.status) {
      BubbleStatus.sending => 'Sending…',
      BubbleStatus.failed => 'Not sent · Tap to retry',
      BubbleStatus.rejected => 'Not sent',
      BubbleStatus.sent => ChatFormat.time(bubble.sentAt),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * .75,
            ),
            child: GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: mine ? scheme.primary : scheme.surface,
                  borderRadius: BorderRadius.circular(
                    DashuriTokens.radiusLarge,
                  ),
                  border: notSent
                      ? Border.all(color: DashuriTokens.error, width: 1.5)
                      : mine
                      ? null
                      : Border.all(color: scheme.outlineVariant),
                ),
                child: Text(
                  bubble.body,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: mine ? scheme.onPrimary : null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (notSent) ...[
                const Icon(
                  Icons.error_outline,
                  size: 14,
                  color: DashuriTokens.error,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                meta,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: notSent
                      ? DashuriTokens.error
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterNotice extends StatelessWidget {
  const _FilterNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(DashuriTokens.space3),
      decoration: BoxDecoration(
        color: DashuriTokens.error100,
        borderRadius: BorderRadius.circular(DashuriTokens.radiusMedium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: DashuriTokens.error),
          const SizedBox(width: DashuriTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keep conversations on Dashuri',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  "Phone numbers, UPI IDs, emails and links aren't allowed in "
                  'messages. This protects you from scams. Edit your message '
                  'and send it again.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 5,
                maxLength: ConversationCubit.maxLength,
                buildCounter:
                    (
                      _, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => currentLength > 900
                    ? Text('$currentLength / $maxLength')
                    : null,
                textInputAction: TextInputAction.newline,
                onChanged: onChanged,
                decoration: InputDecoration(hintText: hint),
              ),
            ),
            const SizedBox(width: DashuriTokens.space2),
            IconButton.filled(
              tooltip: 'Send',
              onPressed: onSend,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _Restricted extends StatelessWidget {
  const _Restricted({required this.name, required this.onCall, this.photoUrl});

  final String name;
  final String? photoUrl;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(DashuriTokens.space6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UserAvatar(name: name, url: photoUrl, radius: 44),
                  const SizedBox(height: DashuriTokens.space4),
                  Text(name, style: theme.textTheme.titleLarge),
                ],
              ),
            ),
          ),
        ),
        Material(
          color: theme.colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(DashuriTokens.space5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_outline),
                    const SizedBox(width: DashuriTokens.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$name accepts messages after a call',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$name only accepts messages from people they have '
                            'had a video call with. Start a video call first; after '
                            "that, you'll be able to message each other.",
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DashuriTokens.space4),
                PrimaryButton(
                  label: 'Call instead',
                  icon: Icons.videocam_outlined,
                  onPressed: onCall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
