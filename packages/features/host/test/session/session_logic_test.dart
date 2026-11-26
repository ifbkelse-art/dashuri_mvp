import 'dart:typed_data';

import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_host/feature_host.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

class _Repo extends Mock implements HostSessionRepository {}

class _Camera extends Mock implements ArrivalCamera {}

class _Submit extends Mock implements SubmitArrivalPhoto {}

class _Current extends Mock implements GetArrivalPhoto {}

class _Remove extends Mock implements RemoveArrivalPhoto {}

final _jpeg = PickedPhoto(
  bytes: Uint8List.fromList(List.filled(1000, 1)),
  contentType: 'image/jpeg',
);

final _since = DateTime.utc(2026, 11, 26, 10);

HostStatus _online() => HostStatus(
  state: approvedOffline.state,
  kycState: approvedOffline.kycState,
  isAvailable: true,
  ratePerMinute: 500,
  minRatePerMinute: 500,
  maxRatePerMinute: 1000,
  freeCallOptIn: false,
  level: 2,
  onlineSessionId: 's1',
  onlineSince: _since,
);

const _photo = ArrivalPhoto(
  photoId: 'p1',
  sessionId: 's1',
  status: ArrivalPhotoStatus.pendingReview,
);

void main() {
  setUpAll(() {
    registerFallbackValue(const NoInput());
    registerFallbackValue(_jpeg);
    registerFallbackValue(
      ArrivalUploadTicket(
        photoId: 'x',
        sessionId: 's',
        uploadUrl: Uri.parse('https://u'),
        expiresAt: DateTime(2030),
        maxBytes: 10,
      ),
    );
  });

  group('HostSessionBloc', () {
    late MockGetHostStatus status;
    late MockSetAvailability setAvailability;
    late MockSendHeartbeat heartbeat;
    late HostPresenceController presence;
    late FakeTimers timers;
    var now = DateTime.utc(2026, 11, 26, 10, 30);

    HostSessionBloc build() => HostSessionBloc(
      getStatus: status,
      setAvailability: setAvailability,
      presence: presence,
      now: () => now,
    );

    setUp(() {
      status = MockGetHostStatus();
      setAvailability = MockSetAvailability();
      heartbeat = MockSendHeartbeat();
      timers = FakeTimers();
      presence = HostPresenceController(heartbeat, timerFactory: timers.call);
      now = DateTime.utc(2026, 11, 26, 10, 30);
      when(() => heartbeat(any())).thenAnswer((_) async => const Success(null));
    });
    tearDown(() => presence.dispose());

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test(
      'opens online with the server session start; heartbeats run',
      () async {
        when(() => status(any())).thenAnswer((_) async => Success(_online()));
        final b = build()..add(const HostSessionStarted());
        await settle();
        expect(b.state, isA<HostSessionOnline>());
        expect((b.state as HostSessionOnline).since, _since);
        expect(presence.isBeating, isTrue);
        await b.close();
      },
    );

    test('offline → activation → online (arrival step is separate)', () async {
      when(
        () => status(any()),
      ).thenAnswer((_) async => const Success(approvedOffline));
      when(
        () => setAvailability(true),
      ).thenAnswer((_) async => Success(_online()));
      final b = build()..add(const HostSessionStarted(activate: true));
      await settle();
      expect(b.state, isA<HostSessionGoingOnline>());
      b.add(const HostSessionActivationProceed());
      await settle();
      expect(b.state, isA<HostSessionOnline>());
      verify(() => setAvailability(true)).called(1);
      await b.close();
    });

    test(
      'cancelling the activation stays offline; never goes online',
      () async {
        when(
          () => status(any()),
        ).thenAnswer((_) async => const Success(approvedOffline));
        final b = build()..add(const HostSessionStarted(activate: true));
        await settle();
        b.add(const HostSessionActivationCancelled());
        await settle();
        expect(b.state, isA<HostSessionOffline>());
        verifyNever(() => setAvailability(any()));
        await b.close();
      },
    );

    test('incoming call interrupts at once', () async {
      when(() => status(any())).thenAnswer((_) async => Success(_online()));
      final b = build()..add(const HostSessionStarted());
      await settle();
      presence.notifyIncomingCall('call-9');
      await settle();
      expect(b.state, isA<HostSessionRinging>());
      expect((b.state as HostSessionRinging).callId, 'call-9');
      await b.close();
    });

    test('network: reconnecting, then unavailable, then back online', () async {
      when(() => status(any())).thenAnswer((_) async => Success(_online()));
      when(
        () => heartbeat(any()),
      ).thenAnswer((_) async => const Err(NetworkFailure()));
      final b = build()..add(const HostSessionStarted());
      await settle();
      timers.active!.fire();
      await settle();
      await settle();
      expect(b.state, isA<HostSessionReconnecting>());
      timers.active!
        ..fire()
        ..fire();
      await settle();
      await settle();
      expect(b.state, isA<HostSessionNetworkUnavailable>());
      when(() => heartbeat(any())).thenAnswer((_) async => const Success(null));
      b.add(const HostSessionRetryPressed());
      await settle();
      await settle();
      expect(b.state, isA<HostSessionOnline>());
      await b.close();
    });

    test('go offline ends the session with its duration', () async {
      when(() => status(any())).thenAnswer((_) async => Success(_online()));
      when(
        () => setAvailability(false),
      ).thenAnswer((_) async => const Success(approvedOffline));
      final b = build()..add(const HostSessionStarted());
      await settle();
      b.add(const HostSessionGoOfflinePressed());
      await settle();
      final s = b.state as HostSessionSessionEnded;
      expect(s.duration, const Duration(minutes: 30));
      expect(s.reason, SessionEndReason.wentOffline);
      expect(presence.isBeating, isFalse);
      await b.close();
    });

    test(
      'go offline refused during a call: still online with a message',
      () async {
        when(() => status(any())).thenAnswer((_) async => Success(_online()));
        when(() => setAvailability(false)).thenAnswer(
          (_) async => const Err(BusinessRuleFailure(code: 'in_call')),
        );
        final b = build()..add(const HostSessionStarted());
        await settle();
        b.add(const HostSessionGoOfflinePressed());
        await settle();
        expect((b.state as HostSessionOnline).failure?.code, 'in_call');
        await b.close();
      },
    );

    test('server refused a heartbeat: session ended by the server', () async {
      var n = 0;
      when(() => status(any())).thenAnswer(
        (_) async =>
            n++ == 0 ? Success(_online()) : const Success(approvedOffline),
      );
      when(() => heartbeat(any())).thenAnswer(
        (_) async => const Err(ConflictFailure(code: 'not_available')),
      );
      final b = build()..add(const HostSessionStarted());
      await settle();
      timers.active!.fire();
      for (var i = 0; i < 4; i++) {
        await settle();
      }
      expect(b.state, isA<HostSessionSessionEnded>());
      expect(
        (b.state as HostSessionSessionEnded).reason,
        SessionEndReason.endedByServer,
      );
      await b.close();
    });

    test('after a declined call the room says so and stays online', () async {
      when(() => status(any())).thenAnswer((_) async => Success(_online()));
      final b = build()
        ..add(const HostSessionStarted(after: CallNotice.declined));
      await settle();
      expect((b.state as HostSessionOnline).notice, CallNotice.declined);
      await b.close();
    });

    test('not approved / suspended: unavailable', () async {
      when(
        () => status(any()),
      ).thenAnswer((_) async => const Success(kycPendingHost));
      final b = build()..add(const HostSessionStarted(activate: true));
      await settle();
      expect(
        (b.state as HostSessionUnavailable).reason,
        UnavailableReason.notApproved,
      );
      verifyNever(() => setAvailability(any()));
      await b.close();
    });
  });

  group('ArrivalPhotoCubit', () {
    late _Camera camera;
    late _Submit submit;
    late _Current current;
    late _Remove remove;

    ArrivalPhotoCubit build() => ArrivalPhotoCubit(
      camera: camera,
      submit: submit,
      current: current,
      remove: remove,
    );

    setUp(() {
      camera = _Camera();
      submit = _Submit();
      current = _Current();
      remove = _Remove();
    });

    test('capture → preview → retake → confirm → upload', () async {
      when(() => camera.capture()).thenAnswer((_) async => _jpeg);
      when(() => submit(any())).thenAnswer((_) async => const Success(_photo));
      final c = build()..prompt();
      await c.capture();
      expect(c.state, isA<ArrivalPreview>());
      await c.retake();
      expect(c.state, isA<ArrivalPreview>());
      verify(() => camera.capture()).called(2);
      c.confirm();
      expect(c.state, isA<ArrivalConfirmed>());
      verifyNever(() => submit(any())); // nothing uploads before the session
      await c.upload();
      expect((c.state as ArrivalLoaded).current, _photo);
      await c.close();
    });

    test(
      'cancelled camera returns to the prompt; skip never uploads',
      () async {
        when(() => camera.capture()).thenAnswer((_) async => null);
        final c = build()..prompt();
        await c.capture();
        expect(c.state, isA<ArrivalPrompt>());
        c.skip();
        expect(c.state, isA<ArrivalSkipped>());
        verifyNever(() => submit(any()));
        await c.close();
      },
    );

    test('network failure keeps the photo; retry uploads it again', () async {
      when(() => camera.capture()).thenAnswer((_) async => _jpeg);
      var n = 0;
      when(() => submit(any())).thenAnswer(
        (_) async =>
            n++ == 0 ? const Err(NetworkFailure()) : const Success(_photo),
      );
      final c = build();
      await c.capture();
      c.confirm();
      await c.upload();
      final failed = c.state as ArrivalFailed;
      expect(failed.retryable, isTrue);
      await c.upload();
      expect(c.state, isA<ArrivalLoaded>());
      verify(() => submit(any())).called(2);
      await c.close();
    });

    test('invalid image: not retryable as-is', () async {
      when(() => camera.capture()).thenAnswer((_) async => _jpeg);
      when(() => submit(any())).thenAnswer(
        (_) async => const Err(
          ValidationFailure(fieldErrors: {'photo': 'invalid_image'}),
        ),
      );
      final c = build();
      await c.capture();
      c.confirm();
      await c.upload();
      expect((c.state as ArrivalFailed).retryable, isFalse);
      await c.close();
    });
  });

  group('SubmitArrivalPhoto', () {
    late _Repo repo;
    final ticket = ArrivalUploadTicket(
      photoId: 'p1',
      sessionId: 's1',
      uploadUrl: Uri.parse('https://storage/upload'),
      expiresAt: DateTime.utc(2030),
      maxBytes: 2000,
    );

    setUp(() => repo = _Repo());

    test('ticket → upload → confirm', () async {
      when(
        () => repo.createArrivalUpload(),
      ).thenAnswer((_) async => Success(ticket));
      when(
        () => repo.uploadArrival(any(), any()),
      ).thenAnswer((_) async => const Success(null));
      when(
        () => repo.confirmArrival('p1'),
      ).thenAnswer((_) async => const Success(_photo));
      expect(await SubmitArrivalPhoto(repo)(_jpeg), const Success(_photo));
    });

    test('rejects non-JPEG and oversized photos before uploading', () async {
      final png = PickedPhoto(bytes: Uint8List(10), contentType: 'image/png');
      expect(await SubmitArrivalPhoto(repo)(png), isA<Err<ArrivalPhoto>>());
      verifyNever(() => repo.createArrivalUpload());
      when(
        () => repo.createArrivalUpload(),
      ).thenAnswer((_) async => Success(ticket));
      final big = PickedPhoto(
        bytes: Uint8List(2001),
        contentType: 'image/jpeg',
      );
      final r = await SubmitArrivalPhoto(repo)(big);
      expect((r as Err).failure, isA<ValidationFailure>());
      verifyNever(() => repo.uploadArrival(any(), any()));
    });

    test('upload failure stops before confirm', () async {
      when(
        () => repo.createArrivalUpload(),
      ).thenAnswer((_) async => Success(ticket));
      when(
        () => repo.uploadArrival(any(), any()),
      ).thenAnswer((_) async => const Err(NetworkFailure()));
      final r = await SubmitArrivalPhoto(repo)(_jpeg);
      expect((r as Err).failure, isA<NetworkFailure>());
      verifyNever(() => repo.confirmArrival(any()));
    });
  });
}
