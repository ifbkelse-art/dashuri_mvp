import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_host/feature_host.dart';
import 'package:feature_host/src/data/models/host_status_json.dart';
import 'package:feature_host/src/data/models/host_verification_json.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

class MockVerificationRepo extends Mock implements HostVerificationRepository {}

/// Level 5 host, not verified: may charge 3,000 now, 5,000 once verified.
const level5NotVerified = HostStatus(
  state: HostStates.approved,
  kycState: KycStates.approved,
  isAvailable: false,
  ratePerMinute: 2500,
  minRatePerMinute: 500,
  maxRatePerMinute: 3000,
  freeCallOptIn: false,
  level: 5,
  levelMaxRatePerMinute: 5000,
  nextLevelMaxRatePerMinute: 6000,
);

const level5Verified = HostStatus(
  state: HostStates.approved,
  kycState: KycStates.approved,
  isAvailable: false,
  ratePerMinute: 4500,
  minRatePerMinute: 500,
  maxRatePerMinute: 5000,
  freeCallOptIn: false,
  level: 5,
  verificationStatus: VerificationStatuses.verified,
  levelMaxRatePerMinute: 5000,
  nextLevelMaxRatePerMinute: 6000,
);

void main() {
  setUpAll(() {
    registerHostFallbacks();
    registerFallbackValue(EvidenceKind.faceVideo);
    registerFallbackValue(samplePhoto);
    registerFallbackValue(IdempotencyKey.generate());
  });

  group('client-side price check (server stays authoritative)', () {
    test('every level 1–10, verified and not', () {
      for (var level = 1; level <= 10; level++) {
        final levelMax = level * 1000;
        for (final verified in [false, true]) {
          final limit = verified
              ? levelMax
              : (levelMax < 3000 ? levelMax : 3000);
          RateError? check(int r) => HostRateCubit.validate(
            r,
            floor: 500,
            limit: limit,
            levelLimit: levelMax,
          );
          expect(check(499), RateError.belowMinimum);
          expect(check(500), isNull);
          expect(check(limit), isNull);
          expect(
            check(limit + 1),
            limit + 1 > 10000
                ? RateError.abovePlatformMaximum
                : !verified && levelMax > 3000
                ? RateError.requiresVerification
                : RateError.aboveLevelLimit,
            reason: 'L$level verified=$verified',
          );
          expect(
            check(levelMax + 1),
            levelMax == 10000
                ? RateError.abovePlatformMaximum
                : RateError.aboveLevelLimit,
          );
        }
      }
    });

    test('3,000 / 3,001 boundary', () {
      RateError? nonVerified(int r) =>
          HostRateCubit.validate(r, floor: 500, limit: 3000, levelLimit: 8000);
      expect(nonVerified(3000), isNull);
      expect(nonVerified(3001), RateError.requiresVerification);
      expect(
        HostRateCubit.validate(3001, floor: 500, limit: 8000, levelLimit: 8000),
        isNull,
      );
    });
  });

  group('HostStatus pricing fields', () {
    test('parses the 2026-11-23 fields', () {
      final s = hostStatusFromJson({
        'state': 'approved',
        'kyc_state': 'approved',
        'is_available': false,
        'rate_per_minute': 2500,
        'min_rate_per_minute': 500,
        'max_rate_per_minute': 3000,
        'free_call_opt_in': false,
        'level': 5,
        'verification_status': 'under_review',
        'level_max_rate_per_minute': 5000,
        'next_level_max_rate_per_minute': 6000,
        'verified_rate_threshold': 3000,
      });
      expect(s.level, 5);
      expect(s.isVerified, isFalse);
      expect(s.verificationStatus, VerificationStatuses.underReview);
      expect(s.levelMaxRatePerMinute, 5000);
      expect(s.verificationWouldRaiseLimit, isTrue);
    });

    test('older servers default to not verified', () {
      expect(approvedOffline.isVerified, isFalse);
      expect(approvedOffline.verifiedRateThreshold, 3000);
    });
  });

  group('rate cubit maps server pricing errors', () {
    late MockGetHostStatus getStatus;
    late MockSetRate setRate;
    setUp(() {
      getStatus = MockGetHostStatus();
      setRate = MockSetRate();
    });

    blocTest<HostRateCubit, HostRateState>(
      'verification_required_for_rate → requiresVerification',
      setUp: () => when(() => setRate(any())).thenAnswer(
        (_) async => const Err(
          BusinessRuleFailure(code: 'verification_required_for_rate'),
        ),
      ),
      build: () => HostRateCubit(getStatus, setRate),
      // The local check passes (an older server said 4,000 is allowed); the
      // server refuses: the server wins.
      seed: () => const HostRateState(
        status: HostRateStatus.ready,
        host: approvedOffline,
        rate: 3500,
      ),
      act: (c) => c.save(),
      skip: 1,
      expect: () => [
        isA<HostRateState>().having(
          (s) => s.error,
          'error',
          RateError.requiresVerification,
        ),
      ],
    );

    blocTest<HostRateCubit, HostRateState>(
      'a non-verified level-5 host stepping past 3,000 is told to verify',
      build: () => HostRateCubit(getStatus, setRate),
      seed: () => const HostRateState(
        status: HostRateStatus.ready,
        host: level5NotVerified,
        rate: 3000,
      ),
      act: (c) => c.increment(),
      expect: () => [
        isA<HostRateState>()
            .having((s) => s.rate, 'rate', 3100)
            .having((s) => s.error, 'error', RateError.requiresVerification)
            .having((s) => s.showVerificationCta, 'cta', isTrue),
      ],
    );
  });

  group('rate page', () {
    late MockGetHostStatus getStatus;
    late MockSetRate setRate;
    setUp(() {
      getStatus = MockGetHostStatus();
      setRate = MockSetRate();
    });
    Widget page() => BlocProvider(
      create: (_) => HostRateCubit(getStatus, setRate)..load(),
      child: const HostRatePage(),
    );

    testWidgets('non-verified host sees the Verified Host CTA', (tester) async {
      when(
        () => getStatus(any()),
      ).thenAnswer((_) async => const Success(level5NotVerified));
      await pumpHostPage(tester, page());
      await tester.scrollUntilVisible(
        find.text(HostRatePage.verificationCta),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text(
          'Want to charge more than 3,000 Diamonds/minute? Become a Verified Host.',
        ),
        findsOneWidget,
      );
      expect(find.text('Your limit 3,000'), findsOneWidget);
      final start = find.widgetWithText(TextButton, 'Start');
      await tester.dragUntilVisible(
        start,
        find.byType(Scrollable).first,
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(find.text('stub:/host/verified-host'), findsOneWidget);
    });

    testWidgets('verified host has the full level range and no CTA', (
      tester,
    ) async {
      when(
        () => getStatus(any()),
      ).thenAnswer((_) async => const Success(level5Verified));
      await pumpHostPage(tester, page());
      expect(find.text('Your limit 5,000'), findsOneWidget);
      expect(find.text(HostRatePage.verificationCta), findsNothing);
    });
  });

  group('Verified Host application', () {
    late MockVerificationRepo repo;
    setUp(() => repo = MockVerificationRepo());

    const empty = HostVerification(
      status: VerificationStatuses.notApplied,
      canSubmit: true,
    );
    const uploaded = HostVerification(
      status: VerificationStatuses.notApplied,
      canSubmit: true,
      evidence: [
        VerificationEvidence(
          id: 'e1',
          kind: EvidenceKind.faceVideo,
          submitted: false,
        ),
        VerificationEvidence(
          id: 'e2',
          kind: EvidenceKind.idDocumentFront,
          submitted: false,
        ),
      ],
    );

    test('ready to submit only with the required evidence', () {
      expect(empty.readyToSubmit, isFalse);
      expect(uploaded.readyToSubmit, isTrue);
      const info = HostVerification(
        status: VerificationStatuses.infoRequired,
        canSubmit: true,
        note: 'ID photo is blurred',
      );
      expect(info.readyToSubmit, isFalse, reason: 'needs one new upload');
      const reviewing = HostVerification(
        status: VerificationStatuses.underReview,
        canSubmit: false,
      );
      expect(reviewing.readyToSubmit, isFalse);
    });

    test('JSON never needs URLs and ignores unknown kinds', () {
      final v = hostVerificationFromJson({
        'status': 'info_required',
        'can_submit': true,
        'note': 'Please re-take the video',
        'evidence': [
          {'id': 'a', 'kind': 'face_video', 'submitted': true},
          {'id': 'b', 'kind': 'selfie', 'submitted': false},
        ],
        'required_evidence': ['face_video', 'id_document_front'],
      });
      expect(v.evidence, hasLength(1));
      expect(v.note, 'Please re-take the video');
      expect(v.replyingToInfoRequest, isTrue);
    });

    blocTest<VerifiedHostCubit, VerifiedHostState>(
      'upload then submit sends exactly the pending evidence ids',
      setUp: () {
        when(
          () => repo.uploadEvidence(
            kind: any(named: 'kind'),
            media: any(named: 'media'),
          ),
        ).thenAnswer((_) async => const Success(null));
        when(
          () => repo.getVerification(),
        ).thenAnswer((_) async => const Success(uploaded));
        when(
          () => repo.submit(
            evidenceIds: any(named: 'evidenceIds'),
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        ).thenAnswer(
          (_) async => const Success(
            HostVerification(
              status: VerificationStatuses.submitted,
              canSubmit: false,
            ),
          ),
        );
      },
      build: () => VerifiedHostCubit(repo),
      seed: () => const VerifiedHostState(
        status: VerifiedHostStatus.ready,
        verification: empty,
      ),
      act: (c) async {
        await c.upload(EvidenceKind.faceVideo, samplePhoto);
        await c.submit();
      },
      expect: () => [
        isA<VerifiedHostState>().having(
          (s) => s.uploadingKind,
          'uploading',
          EvidenceKind.faceVideo,
        ),
        const VerifiedHostState(
          status: VerifiedHostStatus.ready,
          verification: uploaded,
        ),
        const VerifiedHostState(
          status: VerifiedHostStatus.submitting,
          verification: uploaded,
        ),
        isA<VerifiedHostState>()
            .having((s) => s.submitted, 'submitted', isTrue)
            .having(
              (s) => s.verification?.status,
              'status',
              VerificationStatuses.submitted,
            ),
      ],
      verify: (_) => verify(
        () => repo.submit(
          evidenceIds: ['e1', 'e2'],
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).called(1),
    );

    testWidgets('page explains privacy and shows the reviewer note', (
      tester,
    ) async {
      when(() => repo.getVerification()).thenAnswer(
        (_) async => const Success(
          HostVerification(
            status: VerificationStatuses.rejected,
            canSubmit: true,
            note: 'The ID was not readable.',
          ),
        ),
      );
      await pumpHostPage(
        tester,
        BlocProvider(
          create: (_) => VerifiedHostCubit(repo)..load(),
          child: const VerifiedHostPage(),
        ),
      );
      expect(find.text('Not approved'), findsOneWidget);
      expect(find.text('The ID was not readable.'), findsOneWidget);
      expect(
        find.text("This build can't capture verification evidence."),
        findsOneWidget,
      );
      expect(
        find.textContaining('We do not create face templates'),
        findsOneWidget,
      );
    });
  });
}
