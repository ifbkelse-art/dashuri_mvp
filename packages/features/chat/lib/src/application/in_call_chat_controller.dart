import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../presentation/widgets/in_call_chat_panel.dart';
import 'conversation_cubit.dart';

/// EXPERIMENT — the chat of one video call: the pair's normal conversation
/// ([ConversationCubit] with `callId`), opened when the call goes live and
/// kept running while the panel is closed so unseen messages are counted.
///
/// The app adapts this to video_call's `InCallChatSession` port.
final class InCallChatController {
  InCallChatController(this.cubit, {required this.peerName}) {
    _sub = cubit.stream.listen(_onState);
    unawaited(cubit.start());
  }

  final ConversationCubit cubit;
  final String peerName;
  late final StreamSubscription<ConversationState> _sub;

  /// Fallback re-fetch interval during calls, in case a realtime hint is
  /// missed (a 10-minute call makes about 30 small requests).
  static const pollInterval = Duration(seconds: 20);

  final ValueNotifier<int> unseen = ValueNotifier(0);
  final ValueNotifier<String?> preview = ValueNotifier(null);

  void _onState(ConversationState s) {
    unseen.value = s.unseenCount;
    preview.value = s.latestUnseen?.body;
  }

  Widget buildPanel(BuildContext context, {required VoidCallback onClose}) =>
      BlocProvider.value(
        value: cubit,
        child: InCallChatPanel(onClose: onClose, peerName: peerName),
      );

  void setVisible(bool visible) => cubit.setVisible(visible);

  void dismissPreview() => cubit.dismissPreview();

  Future<void> close() async {
    // cubit.close() stops the poll timer and hint subscriptions
    // synchronously, before the first await.
    final closing = cubit.close();
    await _sub.cancel();
    await closing;
    unseen.dispose();
    preview.dispose();
  }
}
