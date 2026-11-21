import 'dart:async';

import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';
import 'package:feature_video_call/feature_video_call.dart';
import 'package:feature_video_call/src/data/datasources/call_remote_data_source.dart';
import 'package:feature_video_call/src/data/repositories/call_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Remote extends Mock implements CallRemoteDataSource {}

final class _Realtime implements RealtimeGateway {
  final controllers = <String, StreamController<RealtimeEvent>>{};

  @override
  Stream<RealtimeEvent> subscribe(String channel) =>
      (controllers[channel] ??= StreamController.broadcast()).stream;
}

final class _Session implements SessionGateway {
  // Closed by the test that creates the session.
  // ignore: close_sinks
  final sessions = StreamController<AuthSession?>.broadcast();

  @override
  AuthSession? currentSession = AuthSession(
    userId: 'host1',
    expiresAt: DateTime.utc(2030),
  );

  @override
  Stream<AuthSession?> watchSession() => sessions.stream;

  @override
  Future<String?> accessToken() async => null;

  @override
  Future<Result<void>> requestPhoneOtp(String e164Phone) async =>
      const Success(null);

  @override
  Future<Result<AuthSession>> verifyPhoneOtp({
    required String e164Phone,
    required String code,
  }) async => throw UnimplementedError();

  @override
  Future<Result<void>> signOut() async => const Success(null);
}

Map<String, Object?> _call(String role, String phase) => {
  'call_id': 'c-$role-$phase',
  'role': role,
  'peer_user_id': 'u',
  'phase': phase,
  'rate_per_minute': 1,
  'billed_seconds': 0,
  'diamonds_charged': 0,
  'is_free_call': false,
};

void main() {
  late _Remote remote;
  late _Realtime realtime;
  late CallRepositoryImpl repo;

  setUp(() {
    remote = _Remote();
    realtime = _Realtime();
    repo = CallRepositoryImpl(remote, realtime);
  });

  test('incoming calls: receiver + ringing on user:<id> only', () async {
    final session = _Session();
    final seen = <String>[];
    final sub = WatchIncomingCalls(repo, session)(
      const NoInput(),
    ).listen((c) => seen.add(c.callId));
    final ch = realtime.controllers['user:host1']!;
    for (final p in [
      _call('receiver', 'ringing'),
      _call('caller', 'ringing'),
      _call('receiver', 'active'),
    ]) {
      ch.add(
        RealtimeEvent(channel: 'user:host1', type: 'call.updated', payload: p),
      );
    }
    ch.add(
      const RealtimeEvent(
        channel: 'user:host1',
        type: 'chat.message',
        payload: {},
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(seen, ['c-receiver-ringing']);
    await sub.cancel();
    await ch.close();
    await session.sessions.close();
  });

  test('pre-call info fails when the wallet fails', () async {
    when(() => remote.host('h1')).thenAnswer(
      (_) async => const Success(<String, Object?>{
        'user_id': 'h1',
        'display_name': 'A',
        'rate_per_minute': 10,
        'availability': 'available',
      }),
    );
    when(
      () => remote.wallet(),
    ).thenAnswer((_) async => const Err(NetworkFailure()));
    when(
      () => remote.packages(),
    ).thenAnswer((_) async => const Err(NetworkFailure()));
    expect(await repo.preCallInfo('h1'), isA<Err<PreCallInfo>>());
  });

  test('pre-call info tolerates a missing package catalogue', () async {
    when(() => remote.host('h1')).thenAnswer(
      (_) async => const Success(<String, Object?>{
        'user_id': 'h1',
        'display_name': 'A',
        'rate_per_minute': 10,
        'availability': 'available',
      }),
    );
    when(() => remote.wallet()).thenAnswer(
      (_) async => const Success(<String, Object?>{'available_diamonds': 50}),
    );
    when(
      () => remote.packages(),
    ).thenAnswer((_) async => const Err(NetworkFailure()));
    final r = await repo.preCallInfo('h1');
    expect((r as Success<PreCallInfo>).value.approxPaisePerMinute, isNull);
  });
}
