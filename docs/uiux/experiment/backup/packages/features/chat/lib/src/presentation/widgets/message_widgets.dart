import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';

import '../../application/conversation_cubit.dart';
import '../../domain/entities/chat_message.dart';
import 'chat_format.dart';

/// Message widgets shared by the inbox conversation (CH02) and the in-call
/// chat panel, so both show the same messages the same way. Sizes come from
/// the parent's constraints, never the screen, so they fit a narrow panel.

/// Over live video (in-call chat) nothing behind the text can be trusted to
/// contrast with it, so every piece of overlay text sits on its own dark
/// backing or carries a shadow. The video stays visible between messages:
/// no full-panel background, no blur.
abstract final class ChatOverlayStyle {
  /// Their messages: white on near-black. 60% black keeps white text above
  /// 4.5:1 even over a pure-white frame.
  static final Color theirBubble = Colors.black.withValues(alpha: .6);

  /// My messages: white on the brand burgundy, nearly opaque.
  static final Color myBubble = DashuriTokens.burgundy700.withValues(alpha: .9);

  /// Composer field backing.
  static final Color field = Colors.black.withValues(alpha: .55);

  /// Shadow for small text drawn straight on video (meta, header).
  static const List<Shadow> textShadow = [
    Shadow(blurRadius: 3, color: Color(0xE6000000)),
    Shadow(blurRadius: 8, color: Color(0x99000000)),
  ];
}

/// Newest-at-bottom message list. `reverse: true` keeps the latest message
/// in view as messages arrive and when the keyboard opens; scrolling up
/// loads older pages.
class MessageList extends StatelessWidget {
  const MessageList({
    required this.state,
    required this.onLoadOlder,
    required this.onRetry,
    super.key,
    this.showContext = true,
    this.dense = false,
    this.overlay = false,
    this.emptyTitle = 'Say hello',
  });

  final ConversationState state;
  final VoidCallback onLoadOlder;
  final ValueChanged<String> onRetry;

  /// Label messages sent during a video call ("During video call").
  final bool showContext;

  /// Tighter spacing for the in-call panel.
  final bool dense;

  /// See-through styling for drawing over live video ([ChatOverlayStyle]).
  final bool overlay;
  final String emptyTitle;

  @override
  Widget build(BuildContext context) {
    final bubbles = state.bubbles;
    if (bubbles.isEmpty) {
      return LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(DashuriTokens.space4),
                child: dense
                    ? Text(
                        'No messages yet. Messages are text only and stay '
                        'in your chat after the call.',
                        textAlign: TextAlign.center,
                        style: overlay
                            ? Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white,
                                shadows: ChatOverlayStyle.textShadow,
                              )
                            : Theme.of(context).textTheme.bodySmall,
                      )
                    : EmptyStateView(
                        icon: Icons.waving_hand_outlined,
                        title: emptyTitle,
                        message:
                            'Messages are text only. Keep conversations on Dashuri.',
                      ),
              ),
            ),
          ),
        ),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        // reverse: true, so "after" is towards older messages.
        if (n.metrics.extentAfter < 300) onLoadOlder();
        return false;
      },
      child: ListView.builder(
        reverse: true,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.symmetric(
          horizontal: dense ? DashuriTokens.space3 : DashuriTokens.space4,
          vertical: dense ? DashuriTokens.space2 : DashuriTokens.space3,
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
          return MessageBubble(
            key: ValueKey(b.localId),
            bubble: b,
            delivery: state.deliveryOf(b),
            showContext: showContext,
            overlay: overlay,
            onRetry: b.status == BubbleStatus.failed
                ? () => onRetry(b.localId)
                : null,
          );
        },
      ),
    );
  }
}

/// One message. Text wraps (long words break) inside a bubble capped at
/// 80% of the list width; meta text wraps below it.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.bubble,
    required this.delivery,
    super.key,
    this.onRetry,
    this.showContext = true,
    this.overlay = false,
  });

  final ChatBubble bubble;
  final DeliveryState? delivery;
  final VoidCallback? onRetry;
  final bool showContext;

  /// See-through styling for drawing over live video.
  final bool overlay;

  static String deliveryLabel(DeliveryState d) => switch (d) {
    DeliveryState.sending => 'Sending…',
    DeliveryState.sent => 'Sent',
    DeliveryState.read => 'Read',
    DeliveryState.failed => 'Not sent · Tap to retry',
    DeliveryState.notSent => 'Not sent',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mine = bubble.mine;
    final notSent =
        delivery == DeliveryState.failed || delivery == DeliveryState.notSent;
    final parts = <String>[
      if (delivery == null ||
          delivery == DeliveryState.sent ||
          delivery == DeliveryState.read)
        ChatFormat.time(bubble.sentAt),
      if (delivery != null) deliveryLabel(delivery!),
      if (showContext && bubble.context == MessageContext.call)
        'During video call',
    ];
    final metaColor = notSent
        ? (overlay ? const Color(0xFFFF8A80) : DashuriTokens.error)
        : (overlay ? Colors.white : scheme.onSurfaceVariant);
    final bubbleColor = overlay
        ? (mine ? ChatOverlayStyle.myBubble : ChatOverlayStyle.theirBubble)
        : (mine ? scheme.primary : scheme.surface);
    final textColor = overlay
        ? Colors.white
        : (mine ? scheme.onPrimary : scheme.onSurface);
    return LayoutBuilder(
      builder: (context, c) {
        final maxWidth = c.maxWidth * .8;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Semantics(
                  button: onRetry != null,
                  label: onRetry != null ? 'Retry sending' : null,
                  child: GestureDetector(
                    onTap: onRetry,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: BorderRadius.circular(
                          DashuriTokens.radiusLarge,
                        ),
                        border: notSent
                            ? Border.all(color: DashuriTokens.error, width: 1.5)
                            : mine || overlay
                            ? null
                            : Border.all(color: scheme.outlineVariant),
                      ),
                      child: Text(
                        bubble.body,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Row(
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
                    Flexible(
                      child: Text(
                        parts.join(' · '),
                        textAlign: mine ? TextAlign.end : TextAlign.start,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: metaColor,
                          shadows: overlay ? ChatOverlayStyle.textShadow : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// CH05 notice: the contact-details filter refused the last message.
class FilterNotice extends StatelessWidget {
  const FilterNotice({super.key, this.dense = false});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: dense
          ? const EdgeInsets.fromLTRB(8, 4, 8, 4)
          : const EdgeInsets.fromLTRB(16, 4, 16, 8),
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
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: DashuriTokens.neutral900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Phone numbers, UPI IDs, emails and links aren't allowed in "
                  'messages. This protects you from scams. Edit your message '
                  'and send it again.',
                  maxLines: dense ? 3 : null,
                  overflow: dense ? TextOverflow.ellipsis : null,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: DashuriTokens.neutral900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Text composer. Grows to [maxLines] lines, then scrolls inside itself.
/// The line limit also shrinks with the visible height (keyboard open,
/// landscape, large text) so the composer never pushes the page past the
/// screen: its text may take at most a fifth of the visible height.
class MessageComposer extends StatelessWidget {
  const MessageComposer({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onChanged,
    required this.onSend,
    super.key,
    this.maxLines = 5,
    this.color,
    this.overlay = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final int maxLines;
  final Color? color;

  /// See-through styling for drawing over live video.
  final bool overlay;

  /// Line limit for the visible height [height] at text scale [lineHeight].
  static int linesFor({
    required double height,
    required double lineHeight,
    required int maxLines,
  }) => ((height * .2) / lineHeight).floor().clamp(1, maxLines);

  @override
  Widget build(BuildContext context) {
    final visible =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom;
    final lines = linesFor(
      height: visible,
      lineHeight: MediaQuery.textScalerOf(context).scale(24),
      maxLines: maxLines,
    );
    final theme = Theme.of(context);
    return Material(
      color: overlay ? Colors.transparent : color ?? theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: lines,
                maxLength: ConversationCubit.maxLength,
                buildCounter:
                    (
                      _, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => currentLength > 900
                    ? Text(
                        '$currentLength / $maxLength',
                        style: overlay
                            ? const TextStyle(
                                color: Colors.white,
                                shadows: ChatOverlayStyle.textShadow,
                              )
                            : null,
                      )
                    : null,
                textInputAction: TextInputAction.newline,
                textCapitalization: TextCapitalization.sentences,
                onChanged: onChanged,
                style: overlay ? const TextStyle(color: Colors.white) : null,
                cursorColor: overlay ? Colors.white : null,
                decoration: overlay
                    ? InputDecoration(
                        hintText: hint,
                        hintStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: ChatOverlayStyle.field,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            DashuriTokens.radiusXLarge,
                          ),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            DashuriTokens.radiusXLarge,
                          ),
                          borderSide: const BorderSide(color: Colors.white54),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            DashuriTokens.radiusXLarge,
                          ),
                          borderSide: BorderSide.none,
                        ),
                      )
                    : InputDecoration(hintText: hint),
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
