import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_reels/feature_reels.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fixtures.dart';

void main() {
  late MockReelsRepository repo;

  setUpAll(() {
    registerFallbackValue(FeedTab.forYou);
    registerFallbackValue(ReelReportCategory.other);
    registerFallbackValue(IdempotencyKey.generate());
    registerFallbackValue(<ReelEvent>[]);
  });

  setUp(() {
    repo = MockReelsRepository();
    when(() => repo.config()).thenAnswer((_) async => const Success(config));
    when(() => repo.track(any())).thenAnswer((_) async => const Success(null));
  });

  ReelsFeedCubit feedCubit() => ReelsFeedCubit(
    GetReelsFeed(repo),
    SetReelLike(repo),
    SetCreatorFollow(repo),
    ShareReel(repo),
    ReportReel(repo),
    TrackReelEvents(repo),
    GetReelsConfig(repo),
    GetReel(repo),
    sessionId: 'sess',
  );

  group('ReelsFeedCubit', () {
    blocTest<ReelsFeedCubit, ReelsFeedState>(
      'loads the For you feed',
      setUp: () => when(
        () => repo.feed(FeedTab.forYou, cursor: null, limit: 10),
      ).thenAnswer((_) async => Success(page([reel('a'), reel('b')], 'n1'))),
      build: feedCubit,
      act: (c) => c.load(),
      expect: () => [
        const ReelsFeedLoading(FeedTab.forYou),
        isA<ReelsFeedLoaded>()
            .having((s) => s.items.length, 'items', 2)
            .having((s) => s.hasMore, 'hasMore', true)
            .having((s) => s.uploadsAvailable, 'uploads', true),
      ],
    );

    blocTest<ReelsFeedCubit, ReelsFeedState>(
      'server with Reels switched off → disabled failure, feed not requested',
      setUp: () => when(() => repo.config()).thenAnswer(
        (_) async => const Success(
          ReelsConfig(
            enabled: false,
            uploadsAvailable: false,
            minDurationMs: 15000,
            maxDurationMs: 60000,
            maxCaptionLength: 300,
            maxUploadBytes: 1,
          ),
        ),
      ),
      build: feedCubit,
      act: (c) => c.load(),
      expect: () => [
        const ReelsFeedLoading(FeedTab.forYou),
        isA<ReelsFeedFailed>().having(
          (s) => s.failure.code,
          'code',
          'reels_disabled',
        ),
      ],
      verify: (_) => verifyNever(
        () => repo.feed(
          any(),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ),
    );

    test(
      'pagination appends without duplicates and stops at the end',
      () async {
        when(
          () => repo.feed(FeedTab.forYou, cursor: null, limit: 10),
        ).thenAnswer((_) async => Success(page([reel('a'), reel('b')], 'n1')));
        when(
          () => repo.feed(FeedTab.forYou, cursor: 'n1', limit: 10),
        ).thenAnswer((_) async => Success(page([reel('b'), reel('c')])));
        final c = feedCubit();
        await c.load();
        c.onPageChanged(1); // near the end → loads more
        await Future<void>.delayed(Duration.zero);
        final s = c.state as ReelsFeedLoaded;
        expect(s.items.map((r) => r.id), ['a', 'b', 'c']);
        expect(s.hasMore, isFalse);
        await c.loadMore(); // no cursor → no request
        verify(
          () => repo.feed(FeedTab.forYou, cursor: 'n1', limit: 10),
        ).called(1);
        await c.close();
      },
    );

    test('like is optimistic and reverts on failure', () async {
      when(
        () => repo.feed(
          any(),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => Success(page([reel('a', likes: 3)])));
      final gate = Completer<Result<({bool liked, int likeCount})>>();
      when(() => repo.setLike('a', true)).thenAnswer((_) => gate.future);
      final c = feedCubit();
      await c.load();
      final pending = c.toggleLike('a');
      final mid = (c.state as ReelsFeedLoaded).items.single;
      expect((mid.likedByMe, mid.likeCount), (true, 4));
      gate.complete(const Err(BusinessRuleFailure(code: 'account_restricted')));
      await pending;
      final after = c.state as ReelsFeedLoaded;
      expect(
        (after.items.single.likedByMe, after.items.single.likeCount),
        (false, 3),
      );
      expect(after.notice, contains("can't post or interact"));
      await c.close();
    });

    test(
      'follow updates every reel by that creator; report removes the reel',
      () async {
        final by = creator('u1');
        when(
          () => repo.feed(
            any(),
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async =>
              Success(page([reel('a', by: by), reel('b', by: by), reel('c')])),
        );
        when(
          () => repo.setFollow('u1', true),
        ).thenAnswer((_) async => const Success(true));
        when(
          () => repo.report(
            'c',
            ReelReportCategory.spamOrScam,
            details: null,
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        ).thenAnswer((_) async => const Success(null));
        final c = feedCubit();
        await c.load();
        await c.toggleFollow('u1');
        final s = c.state as ReelsFeedLoaded;
        expect(
          s.items
              .where((r) => r.creator.userId == 'u1')
              .every((r) => r.creator.followedByMe),
          isTrue,
        );
        expect(await c.report('c', ReelReportCategory.spamOrScam), isTrue);
        expect((c.state as ReelsFeedLoaded).items.map((r) => r.id), ['a', 'b']);
        await c.close();
      },
    );

    test(
      'analytics: one impression per reel, CTA flushes immediately, close flushes the rest',
      () async {
        final h = creator('h1', host: host);
        when(
          () => repo.feed(
            any(),
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => Success(page([reel('a', by: h), reel('b')])));
        final c = feedCubit();
        await c.load();
        c
          ..onPageChanged(1)
          ..onPageChanged(0)
          ..onPageChanged(1);
        c.callCtaClicked((c.state as ReelsFeedLoaded).items.first);
        await Future<void>.delayed(Duration.zero);
        final first =
            verify(() => repo.track(captureAny())).captured.single
                as List<ReelEvent>;
        expect(
          first
              .where((e) => e.name == ReelEventName.impression)
              .map((e) => e.reelId),
          ['a', 'b'],
        );
        expect(first.last.name, ReelEventName.hostCallCtaClicked);
        expect(first.last.creatorId, 'h1');
        expect(first.every((e) => e.sessionId == 'sess'), isTrue);
        c.playStarted('b');
        await c.close();
        final second =
            verify(() => repo.track(captureAny())).captured.single
                as List<ReelEvent>;
        expect(second.single.name, ReelEventName.playStarted);
      },
    );

    blocTest<ReelsFeedCubit, ReelsFeedState>(
      'single-reel mode loads one reel',
      setUp: () => when(
        () => repo.reel('x'),
      ).thenAnswer((_) async => Success(reel('x'))),
      build: feedCubit,
      act: (c) => c.openSingle('x'),
      expect: () => [
        const ReelsFeedLoading(FeedTab.forYou),
        isA<ReelsFeedLoaded>()
            .having((s) => s.items.single.id, 'id', 'x')
            .having((s) => s.hasMore, 'more', false),
      ],
    );
  });

  group('CreatorProfileCubit', () {
    CreatorProfileCubit cubit() => CreatorProfileCubit(
      GetCreatorProfile(repo),
      GetCreatorReels(repo),
      SetCreatorFollow(repo),
      DeleteReel(repo),
      AppealReel(repo),
    );
    CreatorProfile prof({bool self = false, bool followed = false}) =>
        CreatorProfile(
          creator: creator('u1', host: host, followed: followed),
          followerCount: 5,
          followingCount: 2,
          reelCount: 1,
          isSelf: self,
        );

    test('follow is optimistic on the count and reverts on failure', () async {
      when(() => repo.creator('u1')).thenAnswer((_) async => Success(prof()));
      when(
        () => repo.creatorReels('u1', cursor: null, limit: 18),
      ).thenAnswer((_) async => Success(page([reel('a')])));
      when(
        () => repo.setFollow('u1', true),
      ).thenAnswer((_) async => const Err(NetworkFailure()));
      final c = cubit();
      await c.load('u1');
      final f = c.toggleFollow();
      expect((c.state as CreatorProfileLoaded).profile.followerCount, 6);
      await f;
      final s = c.state as CreatorProfileLoaded;
      expect(
        (s.profile.followerCount, s.profile.creator.followedByMe),
        (5, false),
      );
      expect(s.notice, isNotNull);
      await c.close();
    });

    test(
      'own profile: delete removes the reel; appeal reports success',
      () async {
        when(
          () => repo.creator('me'),
        ).thenAnswer((_) async => Success(prof(self: true)));
        when(() => repo.creatorReels('me', cursor: null, limit: 18)).thenAnswer(
          (_) async => Success(
            page([
              reel('a', mine: true),
              reel('b', mine: true, status: ReelStatus.rejected),
            ]),
          ),
        );
        when(
          () => repo.delete('a'),
        ).thenAnswer((_) async => const Success(null));
        when(
          () => repo.appeal(
            'b',
            'it is fine',
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        ).thenAnswer((_) async => const Success(null));
        final c = cubit();
        await c.load('me');
        expect(await c.deleteReel('a'), isTrue);
        expect((c.state as CreatorProfileLoaded).reels.map((r) => r.id), ['b']);
        expect(await c.appeal('b', '  it is fine '), isTrue);
        expect(await c.appeal('b', '   '), isFalse);
        await c.close();
      },
    );

    blocTest<CreatorProfileCubit, CreatorProfileState>(
      'blocked or missing creator → failure',
      setUp: () => when(
        () => repo.creator('u9'),
      ).thenAnswer((_) async => const Err(NotFoundFailure())),
      build: cubit,
      act: (c) => c.load('u9'),
      expect: () => [
        const CreatorProfileLoading(),
        const CreatorProfileFailed(NotFoundFailure()),
      ],
    );
  });

  group('ReelUploadCubit', () {
    late MockPicker picker;
    setUp(() {
      picker = MockPicker();
      registerFallbackValue(ReelVideoSource.gallery);
    });

    ReelUploadCubit cubit({bool withPicker = true}) => ReelUploadCubit(
      GetReelsConfig(repo),
      UploadReel(repo),
      GetReel(repo),
      picker: withPicker ? picker : null,
      pollInterval: const Duration(milliseconds: 1),
      maxPolls: 5,
    );

    blocTest<ReelUploadCubit, ReelUploadState>(
      'no picker in this build → unavailable (no dead buttons)',
      build: () => cubit(withPicker: false),
      act: (c) => c.load(),
      expect: () => [const UploadLoading(), isA<UploadUnavailable>()],
    );

    blocTest<ReelUploadCubit, ReelUploadState>(
      'server without a video provider → unavailable',
      setUp: () => when(() => repo.config()).thenAnswer(
        (_) async => const Success(
          ReelsConfig(
            enabled: true,
            uploadsAvailable: false,
            minDurationMs: 15000,
            maxDurationMs: 60000,
            maxCaptionLength: 300,
            maxUploadBytes: 1,
          ),
        ),
      ),
      build: cubit,
      act: (c) => c.load(),
      expect: () => [
        const UploadLoading(),
        isA<UploadUnavailable>().having(
          (s) => s.message,
          'msg',
          contains("aren't set up"),
        ),
      ],
    );

    blocTest<ReelUploadCubit, ReelUploadState>(
      'a too-short video is explained on the pick screen',
      setUp: () => when(() => picker.pick(any())).thenAnswer(
        (_) async => PickedVideo(bytes: mp4(8000), contentType: 'video/mp4'),
      ),
      build: cubit,
      act: (c) async {
        await c.load();
        await c.pick(ReelVideoSource.gallery);
      },
      skip: 2,
      expect: () => [
        isA<UploadPick>().having(
          (s) => s.error,
          'error',
          contains('at least 15 seconds'),
        ),
      ],
    );

    test(
      'happy path: pick → preview → progress → tracking until published',
      () async {
        final video = PickedVideo(bytes: mp4(22000), contentType: 'video/mp4');
        when(
          () => picker.pick(ReelVideoSource.camera),
        ).thenAnswer((_) async => video);
        when(
          () => repo.createUpload(
            caption: 'Hello',
            durationMs: 22000,
            sizeBytes: video.bytes.length,
            contentType: 'video/mp4',
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        ).thenAnswer(
          (_) async => Success(
            ReelUploadTicket(
              reel: reel('n', mine: true, status: ReelStatus.awaitingUpload),
              uploadUrl: 'https://up',
              uploadHeaders: const {'Content-Type': 'video/mp4'},
            ),
          ),
        );
        when(
          () => repo.uploadBytes(
            uploadUrl: 'https://up',
            bytes: video.bytes,
            contentType: 'video/mp4',
            headers: const {'Content-Type': 'video/mp4'},
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((inv) async {
          (inv.namedArguments[#onProgress] as void Function(double))(0.5);
          return const Success(null);
        });
        // The server says the file arrived (R2 upload-complete).
        when(() => repo.completeUpload('n')).thenAnswer(
          (_) async =>
              Success(reel('n', mine: true, status: ReelStatus.processing)),
        );
        final statuses = [
          ReelStatus.processing,
          ReelStatus.inReview,
          ReelStatus.published,
        ];
        when(() => repo.reel('n')).thenAnswer(
          (_) async =>
              Success(reel('n', mine: true, status: statuses.removeAt(0))),
        );
        final c = cubit();
        final seen = <ReelUploadState>[];
        final sub = c.stream.listen(seen.add);
        await c.load();
        await c.pick(ReelVideoSource.camera);
        expect(
          c.state,
          isA<UploadPreview>().having((s) => s.durationMs, 'ms', 22000),
        );
        await c.submit('  Hello ');
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await sub.cancel();
        expect(
          seen.whereType<UploadSending>().map((s) => s.progress),
          containsAllInOrder([0.0, 0.5]),
        );
        final last = c.state as UploadTracking;
        expect((last.reel.status, last.polling), (ReelStatus.published, false));
        await c.close();
      },
    );

    test(
      'a failed upload returns to preview and retries with the same key',
      () async {
        final video = PickedVideo(bytes: mp4(22000), contentType: 'video/mp4');
        when(() => picker.pick(any())).thenAnswer((_) async => video);
        final keys = <IdempotencyKey>[];
        when(
          () => repo.createUpload(
            caption: '',
            durationMs: 22000,
            sizeBytes: video.bytes.length,
            contentType: 'video/mp4',
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        ).thenAnswer((inv) async {
          keys.add(inv.namedArguments[#idempotencyKey] as IdempotencyKey);
          return const Err(BusinessRuleFailure(code: 'reel_upload_limit'));
        });
        final c = cubit();
        await c.load();
        await c.pick(ReelVideoSource.gallery);
        await c.submit('');
        expect(
          c.state,
          isA<UploadPreview>().having(
            (s) => s.error,
            'error',
            contains('10 reels a day'),
          ),
        );
        await c.submit('');
        expect(keys.toSet().length, 1);
        await c.close();
      },
    );
  });
}
