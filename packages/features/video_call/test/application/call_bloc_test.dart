import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_video_call/feature_video_call.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Request extends Mock implements RequestCall {}

class _Accept extends Mock implements AcceptCall {}

class _Decline extends Mock implements DeclineCall {}

class _End extends Mock implements EndCall {}

class _Creds extends Mock implements GetCallCredentials {}

class _Watch extends Mock implements WatchCall {}

class _Engine extends Mock implements VideoEngine {}

const _ringing = CallSession(
  callId: 'c1',
  role: CallRole.caller,
  peerUserId: 'h1',
  phase: CallPhase.ringing,
  ratePerMinute: 4000,
  billedSeconds: 0,
  diamondsCharged: 0,
  isFreeCall: false,
  endReason: null,
);

void main() {
  late _Request request;
  late _End end;
  late _Watch watch;
  late _Engine engine;

  CallBloc build() => CallBloc(
    requestCall: request,
    acceptCall: _Accept(),
    declineCall: _Decline(),
    endCall: end,
    getCredentials: _Creds(),
    watchCall: watch,
    engine: engine,
  );

  setUpAll(() {
    registerFallbackValue((
      hostUserId: '',
      idempotencyKey: IdempotencyKey.generate(),
    ));
    registerFallbackValue((
      callId: '',
      reason: '',
      idempotencyKey: IdempotencyKey.generate(),
    ));
  });
  setUp(() {
    request = _Request();
    end = _End();
    watch = _Watch();
    engine = _Engine();
    when(() => watch(any())).thenAnswer((_) => const Stream.empty());
    when(() => engine.leave()).thenAnswer((_) async {});
  });

  blocTest<CallBloc, CallState>(
    'outgoing request shows ringing with the server session',
    setUp: () => when(
      () => request(any()),
    ).thenAnswer((_) async => const Success(_ringing)),
    build: build,
    act: (b) => b.add(const CallOutgoingRequested('h1')),
    expect: () => const [
      CallState(status: CallUiStatus.requesting),
      CallState(status: CallUiStatus.ringing, session: _ringing),
    ],
  );

  blocTest<CallBloc, CallState>(
    'insufficient balance is surfaced as a business-rule failure',
    setUp: () => when(() => request(any())).thenAnswer(
      (_) async =>
          const Err(BusinessRuleFailure(code: 'insufficient_diamonds')),
    ),
    build: build,
    act: (b) => b.add(const CallOutgoingRequested('h1')),
    expect: () => const [
      CallState(status: CallUiStatus.requesting),
      CallState(
        status: CallUiStatus.failed,
        failure: BusinessRuleFailure(code: 'insufficient_diamonds'),
      ),
    ],
  );

  blocTest<CallBloc, CallState>(
    'billing figures come only from server updates',
    build: build,
    seed: () => const CallState(status: CallUiStatus.active, session: _ringing),
    act: (b) => b.add(
      const CallServerEventReceived(
        CallUpdated(
          CallSession(
            callId: 'c1',
            role: CallRole.caller,
            peerUserId: 'h1',
            phase: CallPhase.active,
            ratePerMinute: 4000,
            billedSeconds: 65,
            diamondsCharged: 4333,
            isFreeCall: false,
            endReason: null,
          ),
        ),
      ),
    ),
    verify: (b) {
      expect(b.state.session!.diamondsCharged, 4333);
      expect(b.state.status, CallUiStatus.active);
    },
  );
}
