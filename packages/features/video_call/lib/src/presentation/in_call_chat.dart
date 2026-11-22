import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// EXPERIMENT — in-call chat, supplied by the app (it adapts feature_chat;
/// see apps/mobile/lib/app/di/in_call_chat_adapter.dart). video_call only
/// knows this port, so the call feature does not depend on chat.
///
/// Messages are the pair's normal conversation: whatever is sent here is in
/// the inbox afterwards, and inbox messages appear here. Opening, closing
/// or sending never touches the call, its media or its billing.
abstract interface class InCallChat {
  /// Starts a chat session for a live call. Called once per call screen.
  InCallChatSession open({
    required String callId,
    required String peerUserId,
    required String peerName,
  });
}

/// One call's chat. Lives as long as the call screen and keeps receiving
/// while the panel is closed.
abstract interface class InCallChatSession {
  /// Messages from the peer not seen yet (panel closed).
  ValueListenable<int> get unseen;

  /// Text of the newest unseen message, for a short preview; null when none.
  ValueListenable<String?> get preview;

  /// The panel. Fills the box it is given.
  Widget buildPanel(BuildContext context, {required VoidCallback onClose});

  /// The panel was opened (true) or closed. Opening marks messages read.
  void setVisible(bool visible);

  /// Hides the preview without opening the panel.
  void dismissPreview();

  Future<void> close();
}
