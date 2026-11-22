import 'package:feature_chat/feature_chat.dart';
import 'package:feature_video_call/feature_video_call.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

/// EXPERIMENT — connects video_call's in-call chat port to feature_chat
/// (DASHURI_IN_CALL_CHAT_ENABLED). The two features stay independent; only
/// the composition root knows both.
final class FeatureChatInCallChat implements InCallChat {
  const FeatureChatInCallChat(this._sl);

  final GetIt _sl;

  @override
  InCallChatSession open({
    required String callId,
    required String peerUserId,
    required String peerName,
  }) => _Session(
    openInCallChat(
      _sl,
      callId: callId,
      peerUserId: peerUserId,
      peerName: peerName,
    ),
  );
}

final class _Session implements InCallChatSession {
  const _Session(this._c);

  final InCallChatController _c;

  @override
  ValueListenable<int> get unseen => _c.unseen;

  @override
  ValueListenable<String?> get preview => _c.preview;

  @override
  Widget buildPanel(BuildContext context, {required VoidCallback onClose}) =>
      _c.buildPanel(context, onClose: onClose);

  @override
  void setVisible(bool visible) => _c.setVisible(visible);

  @override
  void dismissPreview() => _c.dismissPreview();

  @override
  Future<void> close() => _c.close();
}
