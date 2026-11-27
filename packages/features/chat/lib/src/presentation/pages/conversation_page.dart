import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/conversation_cubit.dart';
import '../widgets/chat_format.dart';
import '../widgets/message_widgets.dart';
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
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (state.peerIsVerified) ...[
                  const SizedBox(width: DashuriTokens.space1),
                  const VerifiedHostBadge(compact: true),
                ],
                const Spacer(),
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
                  title: "Couldn't load this conversation",
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
                      child: MessageList(
                        state: state,
                        onLoadOlder: cubit.loadOlder,
                        onRetry: cubit.retrySend,
                      ),
                    ),
                    // Notices share the space with the messages (and scroll)
                    // instead of pushing the composer off screen.
                    if (state.filterNotice || state.sendFailure != null)
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (state.filterNotice) const FilterNotice(),
                              if (state.sendFailure != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    ChatFormat.failure(state.sendFailure!),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                        ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    MessageComposer(
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

class _Restricted extends StatelessWidget {
  const _Restricted({required this.name, required this.onCall, this.photoUrl});

  final String name;
  final String? photoUrl;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // One scroll view: at large text the explanation and "Call instead"
    // stay reachable instead of overflowing a fixed bottom panel.
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.all(DashuriTokens.space6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UserAvatar(name: name, url: photoUrl, radius: 44),
                    const SizedBox(height: DashuriTokens.space4),
                    Text(
                      name,
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
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
          ),
        ),
      ),
    );
  }
}
