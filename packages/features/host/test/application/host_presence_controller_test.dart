import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_host/feature_host.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

void main() {
  late MockSendHeartbeat heartbeat;
  late FakeTimers timers;
  late HostPresenceController presence;

  setUpAll(registerHostFallbacks);
  setUp(() {
    heartbeat = MockSendHeartbeat();
    timers = FakeTimers();
    when(() => heartbeat(any())).thenAnswer((_) async => const Success(null));
    presence = HostPresenceController(heartbeat, timerFactory: timers.call);
  });
  tearDown(() => presence.dispose());

  test('sends a heartbeat every 30 s only while online', () async {
    expect(presence.isBeating, isFalse);
    presence.setOnline(online: true);
    expect(timers.active!.interval, const Duration(seconds: 30));
    timers.active!
      ..fire()
      ..fire()
      ..fire();
    await pumpEventQueue();
    verify(() => heartbeat(any())).called(3);

    presence.setOnline(online: false);
    expect(presence.isBeating, isFalse);
    expect(timers.created.single.isActive, isFalse);
  });

  test('stops when backgrounded and resumes with an immediate beat', () async {
    presence.setOnline(online: true);
    presence.appPaused();
    expect(presence.isBeating, isFalse);
    verifyNever(() => heartbeat(any()));

    presence.appResumed();
    await pumpEventQueue();
    expect(presence.isBeating, isTrue);
    verify(() => heartbeat(any())).called(1);
    expect(timers.created, hasLength(2));
  });

  test('does not beat on resume while offline', () async {
    presence
      ..appPaused()
      ..appResumed();
    await pumpEventQueue();
    expect(presence.isBeating, isFalse);
    verifyNever(() => heartbeat(any()));
  });

  test('a refused heartbeat stops the timer and is published', () async {
    when(() => heartbeat(any())).thenAnswer(
      (_) async => const Err(BusinessRuleFailure(code: 'host_not_approved')),
    );
    final rejected = presence.heartbeatRejected.first;
    presence.setOnline(online: true);
    timers.active!.fire();
    expect(
      await rejected,
      const BusinessRuleFailure(code: 'host_not_approved'),
    );
    expect(presence.isBeating, isFalse);
    expect(presence.isOnline, isFalse);
  });

  test('a network failure keeps beating', () async {
    when(
      () => heartbeat(any()),
    ).thenAnswer((_) async => const Err(NetworkFailure()));
    presence.setOnline(online: true);
    timers.active!.fire();
    await pumpEventQueue();
    expect(presence.isBeating, isTrue);
  });
}
