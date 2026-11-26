import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_safety/feature_safety.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';

typedef _ReportInput = ({
  String targetUserId,
  String category,
  String? callId,
  String? details,
  IdempotencyKey idempotencyKey,
  String? arrivalPhotoId,
});

void main() {
  setUpAll(() {
    registerFallbackValue(const PageRequest());
    registerFallbackValue((
      dateOfBirth: '',
      idempotencyKey: IdempotencyKey.generate(),
    ));
    registerFallbackValue((
      userId: '',
      idempotencyKey: IdempotencyKey.generate(),
    ));
    registerFallbackValue((
      enforcementId: '',
      statement: '',
      idempotencyKey: IdempotencyKey.generate(),
    ));
    registerFallbackValue(
      (
            targetUserId: '',
            category: '',
            callId: null,
            details: null,
            idempotencyKey: IdempotencyKey.generate(),
            arrivalPhotoId: null,
          )
          as _ReportInput,
    );
  });

  group('AgeGateCubit', () {
    late MockSubmitAgeDeclaration submit;
    late MockRefresher refresher;
    final clock = FixedClock(DateTime(2026, 11, 21));
    setUp(() {
      submit = MockSubmitAgeDeclaration();
      refresher = MockRefresher();
      when(refresher.refreshAccountStatus).thenAnswer((_) async {});
    });

    test('computes the age and requires the confirmation', () {
      final c = AgeGateCubit(submit, refresher, clock)
        ..setDateOfBirth(DateTime(1998, 4, 14));
      expect(c.state.age, 28);
      expect(c.canSubmit, isFalse);
      c.setConfirmed(true);
      expect(c.canSubmit, isTrue);
    });

    blocTest<AgeGateCubit, AgeGateState>(
      'eligible: refreshes the account',
      setUp: () => when(() => submit(any())).thenAnswer(
        (_) async => const Success(AgeStatus(eligible: true, method: 'self')),
      ),
      build: () => AgeGateCubit(submit, refresher, clock),
      seed: () => AgeGateState(
        dateOfBirth: DateTime(1998, 4, 14),
        age: 28,
        confirmed: true,
      ),
      act: (c) => c.submit(),
      skip: 1,
      expect: () => [
        AgeGateState(
          dateOfBirth: DateTime(1998, 4, 14),
          age: 28,
          confirmed: true,
          outcome: AgeGateOutcome.eligible,
        ),
      ],
      verify: (_) {
        verify(refresher.refreshAccountStatus).called(1);
        final input =
            verify(() => submit(captureAny())).captured.single
                as ({String dateOfBirth, IdempotencyKey idempotencyKey});
        expect(input.dateOfBirth, '1998-04-14');
      },
    );

    blocTest<AgeGateCubit, AgeGateState>(
      'under 18 (or a refused re-declaration) shows the blocked state',
      setUp: () => when(() => submit(any())).thenAnswer(
        (_) async => const Err(BusinessRuleFailure(code: 'age_ineligible')),
      ),
      build: () => AgeGateCubit(submit, refresher, clock),
      seed: () => AgeGateState(
        dateOfBirth: DateTime(2010, 1, 1),
        age: 16,
        confirmed: true,
      ),
      act: (c) => c.submit(),
      skip: 1,
      expect: () => [
        AgeGateState(
          dateOfBirth: DateTime(2010, 1, 1),
          age: 16,
          confirmed: true,
          outcome: AgeGateOutcome.blocked,
        ),
      ],
      verify: (_) => verifyNever(refresher.refreshAccountStatus),
    );

    test(
      'a network failure keeps the same idempotency key for the retry',
      () async {
        final keys = <String>[];
        when(() => submit(any())).thenAnswer((inv) async {
          keys.add(
            (inv.positionalArguments.first
                    as ({String dateOfBirth, IdempotencyKey idempotencyKey}))
                .idempotencyKey
                .value,
          );
          return const Err(NetworkFailure());
        });
        final c = AgeGateCubit(submit, refresher, clock)
          ..setDateOfBirth(DateTime(1998, 4, 14))
          ..setConfirmed(true);
        await c.submit();
        expect(c.state.failure, const NetworkFailure());
        await c.submit();
        expect(keys.toSet(), hasLength(1));
      },
    );
  });

  group('ReportCubit', () {
    late MockReportUser report;
    late MockBlockUser block;
    setUp(() {
      report = MockReportUser();
      block = MockBlockUser();
    });

    test('submit reports and blocks; retries reuse keys', () async {
      final reportKeys = <String>[];
      var reportCalls = 0;
      when(() => report(any())).thenAnswer((inv) async {
        final input = inv.positionalArguments.first as _ReportInput;
        reportKeys.add(input.idempotencyKey.value);
        expect(input.category, 'harassment');
        expect(input.callId, 'c1');
        expect(input.details, 'rude');
        return reportCalls++ == 0
            ? const Err(NetworkFailure())
            : const Success(ReportReceipt(reportId: 'r1', status: 'open'));
      });
      when(() => block(any())).thenAnswer((_) async => Success(blocked));
      final c = ReportCubit(report, block, targetUserId: 'u2', callId: 'c1')
        ..selectCategory(ReportCategory.harassment)
        ..setDetails(' rude ');
      expect(c.state.alsoBlock, isTrue);
      await c.submit();
      expect(c.state.submitted, isFalse);
      expect(c.state.failure, const NetworkFailure());
      await c.submit();
      expect(c.state.submitted, isTrue);
      expect(c.state.blocked, isTrue);
      expect(reportKeys.toSet(), hasLength(1));
    });

    test('cannot submit without a category or with long details', () {
      final c = ReportCubit(report, block, targetUserId: 'u2');
      expect(c.state.canSubmit, isFalse);
      c
        ..selectCategory(ReportCategory.other)
        ..setDetails('x' * 1001);
      expect(c.state.canSubmit, isFalse);
    });

    blocTest<ReportCubit, ReportState>(
      'without "also block" only reports',
      setUp: () => when(() => report(any())).thenAnswer(
        (_) async =>
            const Success(ReportReceipt(reportId: 'r', status: 'open')),
      ),
      build: () => ReportCubit(report, block, targetUserId: 'u2'),
      act: (c) async {
        c
          ..selectCategory(ReportCategory.nudity)
          ..setAlsoBlock(false);
        await c.submit();
      },
      skip: 3,
      expect: () => const [
        ReportState(
          category: ReportCategory.nudity,
          alsoBlock: false,
          submitted: true,
        ),
      ],
      verify: (_) => verifyNever(() => block(any())),
    );
  });

  group('BlockCubit', () {
    late MockBlockUser block;
    setUp(() => block = MockBlockUser());

    blocTest<BlockCubit, BlockState>(
      'confirm blocks (already blocked counts as done)',
      setUp: () => when(() => block(any())).thenAnswer(
        (_) async => const Err(ConflictFailure(code: 'already_blocked')),
      ),
      build: () => BlockCubit(block, userId: 'u2'),
      act: (c) => c.confirm(),
      expect: () => const [BlockState(busy: true), BlockState(done: true)],
    );

    blocTest<BlockCubit, BlockState>(
      'network failure is shown',
      setUp: () => when(
        () => block(any()),
      ).thenAnswer((_) async => const Err(NetworkFailure())),
      build: () => BlockCubit(block, userId: 'u2'),
      act: (c) => c.confirm(),
      expect: () => const [
        BlockState(busy: true),
        BlockState(failure: NetworkFailure()),
      ],
    );
  });

  group('BlockedUsersCubit', () {
    late MockListBlockedUsers list;
    late MockUnblockUser unblock;
    setUp(() {
      list = MockListBlockedUsers();
      unblock = MockUnblockUser();
    });

    blocTest<BlockedUsersCubit, BlockedUsersState>(
      'emits Loading then Failed when the use case fails',
      setUp: () => when(
        () => list(any()),
      ).thenAnswer((_) async => const Err(NetworkFailure())),
      build: () => BlockedUsersCubit(list, unblock),
      act: (c) => c.load(),
      expect: () => const [
        BlockedUsersStateLoading(),
        BlockedUsersStateFailed(NetworkFailure()),
      ],
    );

    blocTest<BlockedUsersCubit, BlockedUsersState>(
      'unblock removes the user',
      setUp: () => when(
        () => unblock(any()),
      ).thenAnswer((_) async => const Success<void>(null)),
      build: () => BlockedUsersCubit(list, unblock),
      seed: () => BlockedUsersStateLoaded(Page(items: [blocked])),
      act: (c) => c.unblock('b1'),
      expect: () => [
        BlockedUsersStateLoaded(
          Page(items: [blocked]),
          unblocking: const {'b1'},
        ),
        const BlockedUsersStateLoaded(Page<BlockedUser>(items: [])),
      ],
    );

    blocTest<BlockedUsersCubit, BlockedUsersState>(
      'loadMore appends the next page',
      setUp: () => when(
        () => list(any()),
      ).thenAnswer((_) async => Success(Page(items: [blocked]))),
      build: () => BlockedUsersCubit(list, unblock),
      seed: () =>
          BlockedUsersStateLoaded(Page(items: [blocked], nextCursor: 'n')),
      act: (c) => c.loadMore(),
      expect: () => [
        BlockedUsersStateLoaded(
          Page(items: [blocked], nextCursor: 'n'),
          loadingMore: true,
        ),
        BlockedUsersStateLoaded(Page(items: [blocked, blocked])),
      ],
      verify: (_) =>
          verify(() => list(const PageRequest(cursor: 'n'))).called(1),
    );
  });

  group('EnforcementCubit', () {
    late MockListEnforcementNotices list;
    late MockSubmitAppeal appeal;
    setUp(() {
      list = MockListEnforcementNotices();
      appeal = MockSubmitAppeal();
    });

    blocTest<EnforcementCubit, EnforcementState>(
      'loads notices and appeals one',
      setUp: () {
        when(
          () => list(any()),
        ).thenAnswer((_) async => Success(Page(items: [notice])));
        when(() => appeal(any())).thenAnswer(
          (_) async =>
              const Success(AppealReceipt(appealId: 'a', status: 'pending')),
        );
      },
      build: () => EnforcementCubit(list, appeal),
      act: (c) async {
        await c.load();
        await c.appeal('e1', '  please review  ');
      },
      expect: () => [
        const EnforcementState(),
        EnforcementState(status: EnforcementStatus.loaded, notices: [notice]),
        EnforcementState(
          status: EnforcementStatus.loaded,
          notices: [notice],
          appealing: 'e1',
        ),
        EnforcementState(
          status: EnforcementStatus.loaded,
          notices: [notice],
          appealed: const {'e1'},
        ),
      ],
    );

    blocTest<EnforcementCubit, EnforcementState>(
      'load failure',
      setUp: () => when(
        () => list(any()),
      ).thenAnswer((_) async => const Err(NetworkFailure())),
      build: () => EnforcementCubit(list, appeal),
      act: (c) => c.load(),
      expect: () => const [
        EnforcementState(),
        EnforcementState(
          status: EnforcementStatus.failed,
          failure: NetworkFailure(),
        ),
      ],
    );
  });

  test('a report about an arrival photo carries its id', () async {
    final report = MockReportUser();
    when(() => report(any())).thenAnswer(
      (_) async => const Success(ReportReceipt(reportId: 'r1', status: 'open')),
    );
    final c =
        ReportCubit(
            report,
            MockBlockUser(),
            targetUserId: 'h1',
            arrivalPhotoId: 'p1',
          )
          ..selectCategory(ReportCategory.values.first)
          ..setAlsoBlock(false);
    await c.submit();
    final input =
        verify(() => report(captureAny())).captured.single as _ReportInput;
    expect(input.arrivalPhotoId, 'p1');
    await c.close();
  });
}
