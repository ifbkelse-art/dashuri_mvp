import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_video_call/feature_video_call.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

class _Request extends Mock implements RequestCall {}

class _Accept extends Mock implements AcceptCall {}

class _Decline extends Mock implements DeclineCall {}

class _End extends Mock implements EndCall {}

class _Creds extends Mock implements GetCallCredentials {}

class _Watch extends Mock implements WatchCall {}

class _Get extends Mock implements GetCall {}

class _Engine extends Mock implements VideoEngine {}

class _Capture extends Mock implements CaptureModerationFrame {}

class _Submit extends Mock implements SubmitModerationFrame {}

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

final _creds = CallCredentials(
  provider: 'stream',
  providerCallId: 'default:c1',
  userToken: 't',
  expiresAt: DateTime.utc(2030),
);

void main() {
  late _Request request;
  late _Accept accept;
  late _Decline decline;
  late _End end;
  late _Creds creds;
  late _Watch watch;
  late _Get get;
  late _Engine engine;
  late StreamController<CallEvent> server;
  late ModerationFrameScheduler moderation;

  CallBloc build() => CallBloc(
    requestCall: request,
    acceptCall: accept,
    declineCall: decline,
    endCall: end,
    getCredentials: creds,
    watchCall: watch,
    engine: engine,
    getCall: get,
    moderation: moderation,
    refreshInterval: const Duration(hours: 1),
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
    registerFallbackValue(_creds);
    registerFallbackValue(const NoInput());
  });
  setUp(() {
    request = _Request();
    accept = _Accept();
    decline = _Decline();
    end = _End();
    creds = _Creds();
    watch = _Watch();
    get = _Get();
    engine = _Engine();
    server = StreamController<CallEvent>.broadcast();
    final capture = _Capture();
    when(() => capture(any())).thenAnswer(
      (_) async => const Err(PlatformFailure(code: 'camera_not_publishing')),
    );
    moderation = ModerationFrameScheduler(capture: capture, submit: _Submit());
    when(() => watch(any())).thenAnswer((_) => server.stream);
    when(() => engine.leave()).thenAnswer((_) async {});
    when(() => engine.events()).thenAnswer((_) => const Stream.empty());
    when(() => engine.join(any())).thenAnswer((_) async => const Success(null));
    when(
      () => engine.setMicrophoneEnabled(enabled: any(named: 'enabled')),
    ).thenAnswer((_) async {});
    when(() => creds(any())).thenAnswer((_) async => Success(_creds));
  });
  tearDown(() => server.close());

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
      CallServerEventReceived(
        CallUpdated(
          session(phase: CallPhase.active, billed: 65, charged: 4333),
        ),
      ),
    ),
    verify: (b) {
      expect(b.state.session!.diamondsCharged, 4333);
      expect(b.state.session!.billedSeconds, 65);
      expect(b.state.status, CallUiStatus.active);
    },
  );

  blocTest<CallBloc, CallState>(
    'host attaches to an incoming ring, accepts and joins media',
    setUp: () {
      when(() => get('c1')).thenAnswer(
        (_) async =>
            Success(session(role: CallRole.receiver, phase: CallPhase.ringing)),
      );
      when(() => accept('c1')).thenAnswer(
        (_) async => Success(
          session(role: CallRole.receiver, phase: CallPhase.accepted),
        ),
      );
    },
    build: build,
    act: (b) async {
      b.add(const CallAttachRequested('c1', incoming: true));
      await Future<void>.delayed(Duration.zero);
      b.add(const CallIncomingAccepted('c1'));
    },
    verify: (b) {
      expect(b.state.status, CallUiStatus.connecting);
      expect(b.state.mediaJoined, isTrue);
      verify(() => engine.join(_creds)).called(1);
    },
  );

  blocTest<CallBloc, CallState>(
    'incoming attach shows the incoming status',
    setUp: () => when(() => get('c1')).thenAnswer(
      (_) async =>
          Success(session(role: CallRole.receiver, phase: CallPhase.ringing)),
    ),
    build: build,
    act: (b) => b.add(const CallAttachRequested('c1', incoming: true)),
    verify: (b) => expect(b.state.status, CallUiStatus.incoming),
  );

  blocTest<CallBloc, CallState>(
    'declining ends the call without media',
    setUp: () => when(() => decline('c1')).thenAnswer(
      (_) async =>
          Success(session(role: CallRole.receiver, phase: CallPhase.declined)),
    ),
    build: build,
    act: (b) => b.add(const CallIncomingDeclined('c1')),
    verify: (b) {
      expect(b.state.status, CallUiStatus.ended);
      expect(b.state.requestedEndReason, 'declined');
      verifyNever(() => engine.join(any()));
    },
  );

  blocTest<CallBloc, CallState>(
    'caller joins media when the server reports accepted',
    setUp: () => when(
      () => get('c1'),
    ).thenAnswer((_) async => Success(session(phase: CallPhase.ringing))),
    build: build,
    act: (b) async {
      b.add(const CallAttachRequested('c1'));
      await Future<void>.delayed(Duration.zero);
      server.add(CallUpdated(session(phase: CallPhase.accepted)));
    },
    wait: const Duration(milliseconds: 10),
    verify: (b) {
      expect(b.state.mediaJoined, isTrue);
      expect(b.state.status, CallUiStatus.connecting);
    },
  );

  blocTest<CallBloc, CallState>(
    'low balance warning comes from call.low_balance',
    build: build,
    seed: () => CallState(status: CallUiStatus.active, session: session()),
    act: (b) => b.add(const CallServerEventReceived(CallLowBalance(30))),
    expect: () => [
      CallState(
        status: CallUiStatus.active,
        session: session(),
        lowBalanceSecondsRemaining: 30,
      ),
    ],
  );

  blocTest<CallBloc, CallState>(
    'media connection loss toggles reconnecting',
    build: build,
    seed: () => CallState(status: CallUiStatus.active, session: session()),
    act: (b) => b
      ..add(const CallMediaEventReceived(MediaEvent.connectionLost))
      ..add(const CallMediaEventReceived(MediaEvent.connectionRestored)),
    expect: () => [
      CallState(
        status: CallUiStatus.active,
        session: session(),
        reconnecting: true,
      ),
      CallState(status: CallUiStatus.active, session: session()),
    ],
  );

  blocTest<CallBloc, CallState>(
    'active call inside the moderation window starts frame capture',
    build: build,
    seed: () => CallState(status: CallUiStatus.connecting, session: session()),
    act: (b) async {
      b.add(
        CallServerEventReceived(
          CallUpdated(
            session(
              moderationEnds: DateTime.now().toUtc().add(
                const Duration(minutes: 3),
              ),
            ),
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(moderation.isRunning, isTrue);
    },
    // Closing the bloc stops the scheduler.
    verify: (_) => expect(moderation.isRunning, isFalse),
  );

  blocTest<CallBloc, CallState>(
    'reporting ends the call with reason report and stops moderation',
    setUp: () => when(
      () => end(any()),
    ).thenAnswer((_) async => Success(session(phase: CallPhase.ended))),
    build: build,
    seed: () => CallState(status: CallUiStatus.active, session: session()),
    act: (b) {
      moderation.start(
        callId: 'c1',
        windowEndsAt: DateTime.now().toUtc().add(const Duration(minutes: 3)),
      );
      b.add(const CallEndRequested(reason: 'report'));
    },
    verify: (b) {
      expect(b.state.status, CallUiStatus.ended);
      expect(b.state.requestedEndReason, 'report');
      expect(moderation.isRunning, isFalse);
      final captured =
          verify(() => end(captureAny())).captured.single
              as ({
                String callId,
                String reason,
                IdempotencyKey idempotencyKey,
              });
      expect(captured.reason, 'report');
      verify(() => engine.leave()).called(greaterThanOrEqualTo(1));
    },
  );

  blocTest<CallBloc, CallState>(
    'server ending the call leaves media and stops moderation',
    build: build,
    seed: () => CallState(status: CallUiStatus.active, session: session()),
    act: (b) => b.add(
      CallServerEventReceived(CallUpdated(session(phase: CallPhase.ended))),
    ),
    verify: (b) {
      expect(b.state.status, CallUiStatus.ended);
      // Once on the server end, once more (idempotent) on close.
      verify(() => engine.leave()).called(2);
    },
  );

  blocTest<CallBloc, CallState>(
    'microphone toggle goes through the engine',
    build: build,
    seed: () => CallState(
      status: CallUiStatus.active,
      session: session(),
      mediaJoined: true,
    ),
    act: (b) => b.add(const CallMicrophoneToggled()),
    verify: (b) {
      expect(b.state.microphoneOn, isFalse);
      verify(() => engine.setMicrophoneEnabled(enabled: false)).called(1);
    },
  );

  blocTest<CallBloc, CallState>(
    'a failed media join shows a failure',
    setUp: () {
      when(
        () => get('c1'),
      ).thenAnswer((_) async => Success(session(phase: CallPhase.accepted)));
      when(() => engine.join(any())).thenAnswer(
        (_) async => const Err(PlatformFailure(code: 'video_not_configured')),
      );
    },
    build: build,
    act: (b) => b.add(const CallAttachRequested('c1')),
    verify: (b) {
      expect(b.state.status, CallUiStatus.failed);
      expect(b.state.failure?.code, 'video_not_configured');
    },
  );
}
