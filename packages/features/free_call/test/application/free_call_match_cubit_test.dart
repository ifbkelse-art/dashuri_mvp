import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_free_call/feature_free_call.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Integrity extends Mock implements GetIntegrityToken {}

class _Request extends Mock implements RequestFreeCall {}

class _Get extends Mock implements GetFreeCallRequest {}

FreeCallRequest _req(String status, {String? callId}) =>
    FreeCallRequest(requestId: 'r1', status: status, callId: callId);

void main() {
  late _Integrity integrity;
  late _Request request;
  late _Get get;

  FreeCallMatchCubit build({Duration timeout = const Duration(seconds: 5)}) =>
      FreeCallMatchCubit(
        integrity: integrity,
        request: request,
        getRequest: get,
        pollInterval: const Duration(milliseconds: 1),
        timeout: timeout,
      );

  setUpAll(() {
    registerFallbackValue(const NoInput());
    registerFallbackValue((
      idempotencyKey: IdempotencyKey.generate(),
      integrityToken: null as String?,
    ));
  });

  setUp(() {
    integrity = _Integrity();
    request = _Request();
    get = _Get();
    when(() => integrity(any())).thenAnswer((_) async => const Success('tok'));
  });

  blocTest<FreeCallMatchCubit, FreeCallMatchState>(
    'polls until matched, sending the integrity token',
    setUp: () {
      when(
        () => request(any()),
      ).thenAnswer((_) async => Success(_req('searching')));
      var n = 0;
      when(() => get('r1')).thenAnswer(
        (_) async => Success(
          ++n < 3 ? _req('searching') : _req('matched', callId: 'c9'),
        ),
      );
    },
    build: build,
    act: (c) => c.start(),
    expect: () => const [FreeCallMatchSearching(), FreeCallMatchFound('c9')],
    verify: (_) {
      verify(() => get('r1')).called(3);
      final input =
          verify(() => request(captureAny())).captured.single
              as FreeCallRequestInput;
      expect(input.integrityToken, 'tok');
    },
  );

  blocTest<FreeCallMatchCubit, FreeCallMatchState>(
    'an immediate match needs no polling',
    setUp: () => when(
      () => request(any()),
    ).thenAnswer((_) async => Success(_req('matched', callId: 'c1'))),
    build: build,
    act: (c) => c.start(),
    expect: () => const [FreeCallMatchSearching(), FreeCallMatchFound('c1')],
    verify: (_) => verifyNever(() => get(any())),
  );

  blocTest<FreeCallMatchCubit, FreeCallMatchState>(
    'no host available',
    setUp: () => when(
      () => request(any()),
    ).thenAnswer((_) async => Success(_req('no_host_available'))),
    build: build,
    act: (c) => c.start(),
    expect: () => const [FreeCallMatchSearching(), FreeCallMatchNoHost()],
  );

  blocTest<FreeCallMatchCubit, FreeCallMatchState>(
    'integrity unavailable fails before any request',
    setUp: () => when(() => integrity(any())).thenAnswer(
      (_) async => const Err(PlatformFailure(code: 'integrity_unavailable')),
    ),
    build: build,
    act: (c) => c.start(),
    expect: () => const [
      FreeCallMatchSearching(),
      FreeCallMatchFailed(PlatformFailure(code: 'integrity_unavailable')),
    ],
    verify: (_) => verifyNever(() => request(any())),
  );

  blocTest<FreeCallMatchCubit, FreeCallMatchState>(
    'retry after a network error reuses the idempotency key',
    setUp: () => when(
      () => request(any()),
    ).thenAnswer((_) async => const Err(NetworkFailure())),
    build: build,
    act: (c) async {
      await c.start();
      await c.start();
    },
    verify: (_) {
      final keys = verify(() => request(captureAny())).captured
          .cast<FreeCallRequestInput>()
          .map((i) => i.idempotencyKey.value)
          .toSet();
      expect(keys, hasLength(1));
    },
  );

  blocTest<FreeCallMatchCubit, FreeCallMatchState>(
    'searching past the timeout ends as no host',
    setUp: () {
      when(
        () => request(any()),
      ).thenAnswer((_) async => Success(_req('searching')));
      when(() => get('r1')).thenAnswer((_) async => Success(_req('searching')));
    },
    build: () => build(timeout: const Duration(milliseconds: 20)),
    act: (c) => c.start(),
    wait: const Duration(milliseconds: 100),
    verify: (c) => expect(c.state, const FreeCallMatchNoHost()),
  );

  blocTest<FreeCallMatchCubit, FreeCallMatchState>(
    'cancel stops polling',
    setUp: () {
      when(
        () => request(any()),
      ).thenAnswer((_) async => Success(_req('searching')));
      when(() => get('r1')).thenAnswer((_) async => Success(_req('searching')));
    },
    build: () => build(timeout: const Duration(minutes: 1)),
    act: (c) async {
      final run = c.start();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      c.cancel();
      await run;
    },
    verify: (c) => expect(c.state, const FreeCallMatchCancelled()),
  );
}
