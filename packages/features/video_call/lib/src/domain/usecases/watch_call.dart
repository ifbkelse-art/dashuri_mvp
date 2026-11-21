import 'package:dashuri_core/dashuri_core.dart';

import '../entities/call_event.dart';
import '../repositories/call_repository.dart';

// Not final: application tests mock use cases.
class WatchCall implements StreamUseCase<CallEvent, String> {
  const WatchCall(this._repository);

  final CallRepository _repository;

  @override
  Stream<CallEvent> call(String callId) => _repository.watchCall(callId);
}
