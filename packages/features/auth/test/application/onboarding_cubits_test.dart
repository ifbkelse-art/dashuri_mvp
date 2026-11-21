import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(const NoInput());
    registerFallbackValue(<DevicePermission>[]);
    registerFallbackValue(ExperienceMode.customer);
  });

  group('CommunityRulesCubit', () {
    late MockAcceptCommunityRules accept;
    setUp(() => accept = MockAcceptCommunityRules());

    blocTest<CommunityRulesCubit, CommunityRulesState>(
      'accept emits submitting then the returned account',
      setUp: () => when(
        () => accept(any()),
      ).thenAnswer((_) async => const Success(account)),
      build: () => CommunityRulesCubit(accept),
      act: (c) => c.accept(),
      expect: () => const [
        CommunityRulesState(submitting: true),
        CommunityRulesState(accepted: account),
      ],
    );

    blocTest<CommunityRulesCubit, CommunityRulesState>(
      'accept surfaces a failure',
      setUp: () => when(
        () => accept(any()),
      ).thenAnswer((_) async => const Err(NetworkFailure())),
      build: () => CommunityRulesCubit(accept),
      act: (c) => c.accept(),
      expect: () => const [
        CommunityRulesState(submitting: true),
        CommunityRulesState(failure: NetworkFailure()),
      ],
    );

    test('uses the current rules version', () {
      expect(AcceptCommunityRules.currentVersion, '2026-11');
    });
  });

  group('PermissionsCubit', () {
    late MockGetDevicePermissions get;
    late MockRequestDevicePermissions request;
    late MockOpenAppSettings open;
    late MockExperienceController experience;
    const granted = DevicePermissionStates({
      DevicePermission.camera: DevicePermissionState.granted,
      DevicePermission.microphone: DevicePermissionState.granted,
      DevicePermission.notifications: DevicePermissionState.denied,
    });
    const denied = DevicePermissionStates({
      DevicePermission.camera: DevicePermissionState.permanentlyDenied,
      DevicePermission.microphone: DevicePermissionState.granted,
    });

    setUp(() {
      get = MockGetDevicePermissions();
      request = MockRequestDevicePermissions();
      open = MockOpenAppSettings();
      experience = MockExperienceController();
      when(experience.completePermissionsPrimer).thenAnswer((_) async {});
      when(() => open(any())).thenAnswer((_) async => const Success(true));
    });

    PermissionsCubit build() =>
        PermissionsCubit(get, request, open, experience);

    blocTest<PermissionsCubit, PermissionsState>(
      'load reads the current states',
      setUp: () =>
          when(() => get(any())).thenAnswer((_) async => const Success(denied)),
      build: build,
      act: (c) => c.load(),
      expect: () => const [PermissionsState(states: denied)],
    );

    blocTest<PermissionsCubit, PermissionsState>(
      'allow completes the primer when camera and mic are granted',
      setUp: () => when(
        () => request(any()),
      ).thenAnswer((_) async => const Success(granted)),
      build: build,
      act: (c) => c.allow(),
      expect: () => const [
        PermissionsState(busy: true),
        PermissionsState(states: granted),
        PermissionsState(states: granted, done: true),
      ],
      verify: (_) => verify(experience.completePermissionsPrimer).called(1),
    );

    blocTest<PermissionsCubit, PermissionsState>(
      'allow with a permanent denial stays on the page (A15)',
      setUp: () => when(
        () => request(any()),
      ).thenAnswer((_) async => const Success(denied)),
      build: build,
      act: (c) => c.allow(),
      expect: () => const [
        PermissionsState(busy: true),
        PermissionsState(states: denied),
      ],
      verify: (_) => verifyNever(experience.completePermissionsPrimer),
    );

    blocTest<PermissionsCubit, PermissionsState>(
      'skip ("Not now") completes the primer; openSettings opens settings',
      build: build,
      act: (c) async {
        await c.openSettings();
        await c.skip();
      },
      expect: () => const [PermissionsState(done: true)],
      verify: (_) => verify(() => open(any())).called(1),
    );
  });

  group('ExperienceCubit', () {
    late MockExperienceController controller;
    setUp(() {
      controller = MockExperienceController();
      when(() => controller.mode).thenReturn(null);
      when(() => controller.hostModeAvailable).thenReturn(false);
      when(() => controller.setMode(any())).thenAnswer((_) async {});
    });

    blocTest<ExperienceCubit, ExperienceState>(
      'select and confirm store the choice',
      build: () => ExperienceCubit(controller),
      act: (c) async {
        c.select(ExperienceMode.host);
        await c.confirm();
      },
      expect: () => const [
        ExperienceState(
          selected: ExperienceMode.host,
          hostModeAvailable: false,
        ),
        ExperienceState(
          selected: ExperienceMode.host,
          hostModeAvailable: false,
          saving: true,
        ),
        ExperienceState(
          selected: ExperienceMode.host,
          hostModeAvailable: false,
          saved: true,
        ),
      ],
      verify: (_) => verify(() => controller.setMode(ExperienceMode.host)),
    );
  });
}
