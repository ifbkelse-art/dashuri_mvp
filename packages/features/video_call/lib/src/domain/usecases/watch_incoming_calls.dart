import 'dart:async';

import 'package:dashuri_core/dashuri_core.dart';

import '../entities/call_session.dart';
import '../repositories/call_repository.dart';

/// Ringing calls where the signed-in user is the receiver, from
/// `user:<id>` `call.updated`. Follows sign-in/sign-out.
// Not final: application tests mock use cases.
class WatchIncomingCalls implements StreamUseCase<CallSession, NoInput> {
  const WatchIncomingCalls(this._repository, this._session);

  final CallRepository _repository;
  final SessionGateway _session;

  @override
  Stream<CallSession> call(NoInput input) {
    final sessions = _session.watchSession();
    final initial = _session.currentSession;
    return Stream<CallSession>.multi((controller) {
      String? userId;
      StreamSubscription<CallSession>? calls;
      void follow(AuthSession? s) {
        if (s?.userId == userId) return;
        userId = s?.userId;
        unawaited(calls?.cancel());
        calls = null;
        final id = userId;
        if (id == null) return;
        calls = _repository
            .watchUserCalls(id)
            .where(
              (c) =>
                  c.role == CallRole.receiver && c.phase == CallPhase.ringing,
            )
            .listen(controller.add, onError: controller.addError);
      }

      follow(initial);
      final sub = sessions.listen(follow, onError: controller.addError);
      controller.onCancel = () async {
        await sub.cancel();
        await calls?.cancel();
      };
    });
  }
}
