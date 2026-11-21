import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(const NoInput());
    registerFallbackValue(IdempotencyKey.generate());
    registerFallbackValue(WhoCanMessage.everyone);
    registerFallbackValue(ExperienceMode.customer);
    registerFallbackValue((analytics: false, marketing: false));
    registerFallbackValue((
      details: '',
      idempotencyKey: IdempotencyKey.generate(),
    ));
  });

  group('SettingsCubit', () {
    late MockGetMessagingPrivacy getPrivacy;
    late MockRequestDataExport export;
    late MockSignOutUser signOut;
    late MockExperienceController experience;
    setUp(() {
      getPrivacy = MockGetMessagingPrivacy();
      export = MockRequestDataExport();
      signOut = MockSignOutUser();
      experience = MockExperienceController();
      when(() => experience.hostModeAvailable).thenReturn(false);
      when(() => experience.effectiveMode).thenReturn(ExperienceMode.customer);
    });

    SettingsCubit build() =>
        SettingsCubit(getPrivacy, export, signOut, experience);

    blocTest<SettingsCubit, SettingsState>(
      'load shows the messaging rule',
      setUp: () => when(
        () => getPrivacy(any()),
      ).thenAnswer((_) async => const Success(WhoCanMessage.pastCallPartners)),
      build: build,
      act: (c) => c.load(),
      expect: () => const [
        SettingsState(whoCanMessage: WhoCanMessage.pastCallPartners),
      ],
    );

    test('data export retries reuse the key; success clears it', () async {
      final keys = <String>[];
      var n = 0;
      when(() => export(any())).thenAnswer((inv) async {
        keys.add((inv.positionalArguments.first as IdempotencyKey).value);
        return n++ == 0
            ? const Err(NetworkFailure())
            : const Success(
                DataExportRequest(requestId: 'x', status: 'queued'),
              );
      });
      final c = build();
      await c.requestDataExport();
      expect(c.state.failure, const NetworkFailure());
      await c.requestDataExport();
      expect(c.state.export, isNotNull);
      expect(keys.toSet(), hasLength(1));
      await c.requestDataExport();
      expect(keys.toSet(), hasLength(2));
      await c.close();
    });

    blocTest<SettingsCubit, SettingsState>(
      'sign out',
      setUp: () => when(
        () => signOut(any()),
      ).thenAnswer((_) async => const Success<void>(null)),
      build: build,
      act: (c) => c.signOut(),
      expect: () => const [
        SettingsState(signingOut: true),
        SettingsState(signedOut: true),
      ],
    );
  });

  group('PrivacyCubit', () {
    late MockGetMessagingPrivacy get;
    late MockSetMessagingPrivacy set;
    setUp(() {
      get = MockGetMessagingPrivacy();
      set = MockSetMessagingPrivacy();
      when(
        () => get(any()),
      ).thenAnswer((_) async => const Success(WhoCanMessage.everyone));
    });

    blocTest<PrivacyCubit, PrivacyState>(
      'select reverts on failure',
      setUp: () => when(
        () => set(any()),
      ).thenAnswer((_) async => const Err(NetworkFailure())),
      build: () => PrivacyCubit(get, set),
      act: (c) async {
        await c.load();
        await c.select(WhoCanMessage.pastCallPartners);
      },
      expect: () => const [
        PrivacyState(),
        PrivacyState(
          status: PrivacyStatus.ready,
          value: WhoCanMessage.everyone,
        ),
        PrivacyState(
          status: PrivacyStatus.ready,
          value: WhoCanMessage.pastCallPartners,
          saving: true,
        ),
        PrivacyState(
          status: PrivacyStatus.ready,
          value: WhoCanMessage.everyone,
          saveFailure: NetworkFailure(),
        ),
      ],
    );

    blocTest<PrivacyCubit, PrivacyState>(
      'load failure',
      setUp: () => when(
        () => get(any()),
      ).thenAnswer((_) async => const Err(NetworkFailure())),
      build: () => PrivacyCubit(get, set),
      act: (c) => c.load(),
      expect: () => const [
        PrivacyState(),
        PrivacyState(status: PrivacyStatus.failed, failure: NetworkFailure()),
      ],
    );
  });

  group('ConsentsCubit', () {
    late MockGetConsents get;
    late MockUpdateConsents update;
    setUp(() {
      get = MockGetConsents();
      update = MockUpdateConsents();
    });

    blocTest<ConsentsCubit, ConsentsState>(
      'emits loading then failed',
      setUp: () => when(
        () => get(any()),
      ).thenAnswer((_) async => const Err(NetworkFailure())),
      build: () => ConsentsCubit(get, update),
      act: (c) => c.load(),
      expect: () => const [
        ConsentsState(),
        ConsentsState(failure: NetworkFailure()),
      ],
    );

    test('toggling analytics sends both values', () async {
      when(() => get(any())).thenAnswer((_) async => Success(consents));
      when(() => update(any())).thenAnswer(
        (_) async => Success(
          ConsentState(
            analytics: true,
            marketing: true,
            updatedAt: DateTime.utc(2026),
          ),
        ),
      );
      final c = ConsentsCubit(get, update);
      await c.load();
      await c.setAnalytics(true);
      verify(() => update((analytics: true, marketing: true))).called(1);
      expect(c.state.data!.analytics, isTrue);
      await c.close();
    });

    test('a failed save reverts', () async {
      when(() => get(any())).thenAnswer((_) async => Success(consents));
      when(
        () => update(any()),
      ).thenAnswer((_) async => const Err(NetworkFailure()));
      final c = ConsentsCubit(get, update);
      await c.load();
      await c.setMarketing(false);
      expect(c.state.data, consents);
      expect(c.state.saveFailure, const NetworkFailure());
      await c.close();
    });
  });

  group('GrievanceCubit', () {
    late MockSubmitGrievance submit;
    setUp(() => submit = MockSubmitGrievance());

    blocTest<GrievanceCubit, GrievanceState>(
      'submits trimmed text',
      setUp: () => when(
        () => submit(any()),
      ).thenAnswer((_) async => const Success('r1')),
      build: () => GrievanceCubit(submit),
      act: (c) async {
        c.changed('  My refund never arrived  ');
        await c.submit();
      },
      expect: () => const [
        GrievanceState(text: '  My refund never arrived  '),
        GrievanceState(text: '  My refund never arrived  ', submitting: true),
        GrievanceState(submitted: true, referenceId: 'r1'),
      ],
    );

    test('needs at least 10 characters', () {
      expect(const GrievanceState(text: 'short').canSubmit, isFalse);
    });
  });

  group('DeleteAccountCubit', () {
    late MockGetDiamondBalance balance;
    late MockRequestAccountDeletion delete;
    late MockSignOutUser signOut;
    setUp(() {
      balance = MockGetDiamondBalance();
      delete = MockRequestAccountDeletion();
      signOut = MockSignOutUser();
      when(() => balance(any())).thenAnswer((_) async => const Success(12480));
    });

    blocTest<DeleteAccountCubit, DeleteAccountState>(
      'loads the balance; delete needs the acknowledgement',
      build: () => DeleteAccountCubit(balance, delete, signOut),
      act: (c) async {
        await c.load();
        await c.delete();
      },
      expect: () => const [
        DeleteAccountState(balanceLoaded: true, diamonds: 12480),
      ],
      verify: (_) => verifyNever(() => delete(any())),
    );

    blocTest<DeleteAccountCubit, DeleteAccountState>(
      '409 pending_balance_or_payout is recognised',
      setUp: () => when(() => delete(any())).thenAnswer(
        (_) async =>
            const Err(BusinessRuleFailure(code: 'pending_balance_or_payout')),
      ),
      build: () => DeleteAccountCubit(balance, delete, signOut),
      seed: () => const DeleteAccountState(acknowledged: true),
      act: (c) => c.delete(),
      verify: (c) => expect(c.state.blockedByBalance, isTrue),
      expect: () => const [
        DeleteAccountState(acknowledged: true, deleting: true),
        DeleteAccountState(
          acknowledged: true,
          failure: BusinessRuleFailure(code: 'pending_balance_or_payout'),
        ),
      ],
    );

    blocTest<DeleteAccountCubit, DeleteAccountState>(
      'success holds the scheduled request',
      setUp: () => when(() => delete(any())).thenAnswer(
        (_) async => const Success(
          DeletionRequest(
            requestId: 'd',
            status: 'scheduled',
            scheduledFor: null,
          ),
        ),
      ),
      build: () => DeleteAccountCubit(balance, delete, signOut),
      seed: () => const DeleteAccountState(acknowledged: true),
      act: (c) => c.delete(),
      skip: 1,
      expect: () => const [
        DeleteAccountState(
          acknowledged: true,
          request: DeletionRequest(
            requestId: 'd',
            status: 'scheduled',
            scheduledFor: null,
          ),
        ),
      ],
    );
  });
}
