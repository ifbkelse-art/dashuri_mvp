import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_host/feature_host.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

void main() {
  late MockGetHostStatus useCase;
  late MockSetAvailability setAvailability;
  late MockSetFreeCallOptIn setOptIn;
  late MockGetMyHostProfile getProfile;
  late MockSendHeartbeat heartbeat;
  late FakeTimers timers;
  late HostPresenceController presence;

  HostDashboardCubit build() => HostDashboardCubit(
    useCase,
    setAvailability: setAvailability,
    setFreeCallOptIn: setOptIn,
    getMyProfile: getProfile,
    presence: presence,
  );

  setUpAll(registerHostFallbacks);
  setUp(() {
    useCase = MockGetHostStatus();
    setAvailability = MockSetAvailability();
    setOptIn = MockSetFreeCallOptIn();
    getProfile = MockGetMyHostProfile();
    heartbeat = MockSendHeartbeat();
    timers = FakeTimers();
    presence = HostPresenceController(heartbeat, timerFactory: timers.call);
    when(
      () => getProfile(any()),
    ).thenAnswer((_) async => const Success(sampleProfile));
    when(() => heartbeat(any())).thenAnswer((_) async => const Success(null));
  });
  tearDown(() => presence.dispose());

  blocTest<HostDashboardCubit, HostDashboardState>(
    'emits Loading then Failed when the use case fails',
    setUp: () => when(
      () => useCase(any()),
    ).thenAnswer((_) async => const Err<HostStatus>(NetworkFailure())),
    build: build,
    act: (cubit) => cubit.load(),
    expect: () => const <HostDashboardState>[
      HostDashboardStateLoading(),
      HostDashboardStateFailed(NetworkFailure()),
    ],
  );

  blocTest<HostDashboardCubit, HostDashboardState>(
    'loads status with profile; an online host starts heartbeats',
    setUp: () => when(
      () => useCase(any()),
    ).thenAnswer((_) async => Success(approvedOnline)),
    build: build,
    act: (cubit) => cubit.load(),
    expect: () => [
      const HostDashboardStateLoading(),
      HostDashboardStateLoaded(approvedOnline, profile: sampleProfile),
    ],
    verify: (_) => expect(presence.isBeating, isTrue),
  );

  blocTest<HostDashboardCubit, HostDashboardState>(
    'a failed profile load still shows the dashboard',
    setUp: () {
      when(
        () => useCase(any()),
      ).thenAnswer((_) async => const Success(approvedOffline));
      when(
        () => getProfile(any()),
      ).thenAnswer((_) async => const Err(NetworkFailure()));
    },
    build: build,
    act: (cubit) => cubit.load(),
    expect: () => const [
      HostDashboardStateLoading(),
      HostDashboardStateLoaded(approvedOffline),
    ],
  );

  blocTest<HostDashboardCubit, HostDashboardState>(
    'going online starts the 30 s heartbeat; going offline stops it',
    setUp: () {
      when(
        () => setAvailability(true),
      ).thenAnswer((_) async => Success(approvedOnline));
      when(
        () => setAvailability(false),
      ).thenAnswer((_) async => const Success(approvedOffline));
    },
    build: build,
    seed: () => const HostDashboardStateLoaded(approvedOffline),
    act: (cubit) async {
      await cubit.setAvailable(available: true);
      expect(presence.isBeating, isTrue);
      timers.active!
        ..fire()
        ..fire();
      await cubit.setAvailable(available: false);
    },
    expect: () => [
      const HostDashboardStateLoaded(approvedOffline, updating: true),
      HostDashboardStateLoaded(approvedOnline),
      HostDashboardStateLoaded(approvedOnline, updating: true),
      const HostDashboardStateLoaded(approvedOffline),
    ],
    verify: (_) {
      expect(presence.isBeating, isFalse);
      verify(() => heartbeat(any())).called(2);
    },
  );

  blocTest<HostDashboardCubit, HostDashboardState>(
    'a refused availability change keeps the old state with the failure',
    setUp: () => when(
      () => setAvailability(true),
    ).thenAnswer((_) async => const Err(BusinessRuleFailure(code: 'in_call'))),
    build: build,
    seed: () => const HostDashboardStateLoaded(approvedOffline),
    act: (cubit) => cubit.setAvailable(available: true),
    expect: () => const [
      HostDashboardStateLoaded(approvedOffline, updating: true),
      HostDashboardStateLoaded(
        approvedOffline,
        actionFailure: BusinessRuleFailure(code: 'in_call'),
      ),
    ],
    verify: (_) => expect(presence.isBeating, isFalse),
  );

  blocTest<HostDashboardCubit, HostDashboardState>(
    'free-call opt-in success and failure',
    setUp: () {
      when(() => setOptIn(false)).thenAnswer(
        (_) async => Success(approvedOffline.copyWith(freeCallOptIn: false)),
      );
      when(
        () => setOptIn(true),
      ).thenAnswer((_) async => const Err(NetworkFailure()));
    },
    build: build,
    seed: () => const HostDashboardStateLoaded(approvedOffline),
    act: (cubit) async {
      await cubit.setFreeCallOptIn(optIn: false);
      await cubit.setFreeCallOptIn(optIn: true);
    },
    expect: () {
      final off = approvedOffline.copyWith(freeCallOptIn: false);
      return [
        const HostDashboardStateLoaded(approvedOffline, updating: true),
        HostDashboardStateLoaded(off),
        HostDashboardStateLoaded(off, updating: true),
        HostDashboardStateLoaded(off, actionFailure: const NetworkFailure()),
      ];
    },
  );

  blocTest<HostDashboardCubit, HostDashboardState>(
    'backgrounding pauses heartbeats; resuming refreshes and beats once',
    setUp: () => when(
      () => useCase(any()),
    ).thenAnswer((_) async => Success(approvedOnline)),
    build: build,
    act: (cubit) async {
      await cubit.load();
      cubit.appPaused();
      expect(presence.isBeating, isFalse);
      await cubit.appResumed();
    },
    verify: (_) {
      expect(presence.isBeating, isTrue);
      verify(() => heartbeat(any())).called(1);
      verify(() => useCase(any())).called(2);
    },
  );

  blocTest<HostDashboardCubit, HostDashboardState>(
    'a rejected heartbeat triggers a status refresh',
    setUp: () {
      when(
        () => useCase(any()),
      ).thenAnswer((_) async => Success(approvedOnline));
      when(
        () => heartbeat(any()),
      ).thenAnswer((_) async => const Err(ForbiddenFailure(code: 'forbidden')));
    },
    build: build,
    act: (cubit) async {
      await cubit.load();
      timers.active!.fire();
      await pumpEventQueue();
    },
    verify: (_) => verify(() => useCase(any())).called(2),
  );
}
