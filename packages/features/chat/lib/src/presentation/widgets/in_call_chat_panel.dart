import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/conversation_cubit.dart';
import 'chat_format.dart';
import 'message_widgets.dart';

/// EXPERIMENT — the chat panel shown over a video call. It is the pair's
/// normal conversation (same [ConversationCubit], same API, same messages),
/// rendered compactly and SEE-THROUGH: no panel background and no blur, so
/// the video (and the other person's face) stays visible between messages.
/// Each message, the header and the composer carry their own dark backing
/// ([ChatOverlayStyle]) so text stays readable whatever the video shows. Fills the box its parent gives it; the call screen
/// decides where that box is so call controls stay reachable.
class InCallChatPanel extends StatefulWidget {
  const InCallChatPanel({required this.onClose, super.key, this.peerName});

  final VoidCallback onClose;
  final String? peerName;

  /// Below this height only the composer is shown (tiny landscape windows).
  /// It grows with the text size: header and composer grow with it.
  static double minFullHeight(TextScaler scaler) =>
      70 + 80 * scaler.scale(14) / 14;

  @override
  State<InCallChatPanel> createState() => _InCallChatPanelState();
}

class _InCallChatPanelState extends State<InCallChatPanel> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  /// The composer moves between the full layout and the composer-only one
  /// when the keyboard changes the panel's height. A GlobalKey moves it
  /// instead of rebuilding it, so the field keeps focus and the keyboard
  /// stays open.
  final _composerKey = GlobalKey(debugLabel: 'in-call-composer');

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<ConversationCubit, ConversationState>(
      listenWhen: (a, b) =>
          b.restoredDraft != null && a.restoredDraft != b.restoredDraft,
      listener: (context, state) {
        final draft = state.restoredDraft!;
        _text
          ..text = draft
          ..selection = TextSelection.collapsed(offset: draft.length);
        _focus.requestFocus();
      },
      builder: (context, state) {
        final cubit = context.read<ConversationCubit>();
        final name = widget.peerName?.isNotEmpty ?? false
            ? widget.peerName!
            : (state.peerName ?? 'them');
        final field = state.status == ConversationStatus.ready
            ? MessageComposer(
                controller: _text,
                focusNode: _focus,
                hint: 'Message…',
                maxLines: 3,
                overlay: true,
                onChanged: (_) => cubit.dismissFilterNotice(),
                onSend: () => _send(cubit),
              )
            : null;
        // No header bar floating over the video: the close control sits at
        // the start of the composer row (the call's chat button and Back
        // close the panel too).
        final close = _CloseButton(onClose: widget.onClose);
        final composer = Row(
          key: _composerKey,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 8),
              child: close,
            ),
            if (field != null) Expanded(child: field) else const Spacer(),
          ],
        );
        return Semantics(
          container: true,
          label: 'Chat with $name',
          child: Material(
            type: MaterialType.transparency,
            child: LayoutBuilder(
              builder: (context, c) {
                if (c.maxHeight <
                    InCallChatPanel.minFullHeight(
                      MediaQuery.textScalerOf(context),
                    )) {
                  // Not enough room for history: keep typing possible.
                  // reverse: the send row stays in view if even the
                  // composer is taller than the panel (very large text).
                  // Not ready yet: show the state (spinner / reason + retry),
                  // which scrolls on its own.
                  if (field == null) {
                    return _body(context, state, cubit, name);
                  }
                  return SingleChildScrollView(reverse: true, child: composer);
                }
                return Column(
                  children: [
                    Expanded(
                      // Older messages fade out at the top instead of
                      // ending in a hard edge across the video.
                      child: ShaderMask(
                        blendMode: BlendMode.dstIn,
                        // A thin fixed-height edge, so a short list is
                        // never faded.
                        shaderCallback: (r) => LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: const [Colors.transparent, Colors.black],
                          stops: [
                            0,
                            r.height <= 0 ? 0 : (20 / r.height).clamp(0, 1),
                          ],
                        ).createShader(r),
                        child: _body(context, state, cubit, name),
                      ),
                    ),
                    if (state.filterNotice) const FilterNotice(dense: true),
                    if (state.sendFailure != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                        child: Text(
                          ChatFormat.failure(state.sendFailure!),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFFFF8A80),
                            shadows: ChatOverlayStyle.textShadow,
                          ),
                        ),
                      ),
                    composer,
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    ConversationState state,
    ConversationCubit cubit,
    String name,
  ) {
    final theme = Theme.of(context);
    Widget notice(String text, {VoidCallback? onRetry}) => LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        padding: const EdgeInsets.all(DashuriTokens.space4),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (c.maxHeight - 2 * DashuriTokens.space4).clamp(
              0,
              double.infinity,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: ChatOverlayStyle.theirBubble,
                  borderRadius: BorderRadius.circular(
                    DashuriTokens.radiusLarge,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(DashuriTokens.space3),
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: DashuriTokens.space2),
                FilledButton.tonal(
                  onPressed: onRetry,
                  child: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return switch (state.status) {
      ConversationStatus.starting || ConversationStatus.loading => const Center(
        child: SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
      ConversationStatus.restricted => notice(
        '$name accepts messages only from people they have had a call '
        'with. You can message once billing for this call has started.',
        onRetry: cubit.retry,
      ),
      ConversationStatus.failed => notice(
        ChatFormat.failure(state.failure!),
        onRetry: cubit.retry,
      ),
      ConversationStatus.ready => MessageList(
        state: state,
        dense: true,
        overlay: true,
        showContext: false,
        onLoadOlder: cubit.loadOlder,
        onRetry: cubit.retrySend,
      ),
    };
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Close chat',
    onPressed: onClose,
    style: IconButton.styleFrom(
      backgroundColor: ChatOverlayStyle.field,
      foregroundColor: Colors.white,
    ),
    icon: const Icon(Icons.keyboard_arrow_down_rounded),
  );
}
