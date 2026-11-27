import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_reels/feature_reels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fixtures.dart';
import '../helpers/pump.dart';

class MockFeedCubit extends MockCubit<ReelsFeedState>
    implements ReelsFeedCubit {}

class MockCreatorCubit extends MockCubit<CreatorProfileState>
    implements CreatorProfileCubit {}

class MockUploadCubit extends MockCubit<ReelUploadState>
    implements ReelUploadCubit {}

class _FakePlayer implements ReelPlayerFactory {
  @override
  Widget build({
    required ReelPlayback playback,
    required bool active,
    required bool muted,
    required bool paused,
    required ReelPlayerCallbacks callbacks,
    bool preload = false,
  }) => ColoredBox(color: Colors.black, child: Text('player ${playback.url}'));
}

Widget feed(
  ReelsFeedCubit c, {
  ReelPlayerFactory? player,
  bool single = false,
}) => BlocProvider<ReelsFeedCubit>.value(
  value: c,
  child: ReelsFeedPage(player: player, single: single),
);

void main() {
  setUpAll(() {
    registerFallbackValue(ReelReportCategory.other);
    registerFallbackValue(ReelVideoSource.gallery);
    registerFallbackValue(FeedTab.forYou);
  });

  group('ReelsFeedPage', () {
    late MockFeedCubit c;
    setUp(() {
      c = MockFeedCubit();
      when(() => c.load(any())).thenAnswer((_) async {});
      when(() => c.setTab(any())).thenAnswer((_) async {});
      when(() => c.loadMore()).thenAnswer((_) async {});
      when(() => c.flush()).thenAnswer((_) async {});
      when(() => c.toggleLike(any())).thenAnswer((_) async {});
      when(() => c.toggleFollow(any())).thenAnswer((_) async {});
      when(() => c.share(any())).thenAnswer((_) async => null);
      when(() => c.report(any(), any())).thenAnswer((_) async => true);
    });

    final hostReel = reel('a', by: creator('h1', host: host));
    final loaded = ReelsFeedLoaded(
      FeedTab.forYou,
      items: [hostReel, reel('b')],
      nextCursor: null,
      uploadsAvailable: true,
    );

    testResponsive('loaded: creator, caption, host CTA, honest poster', (
      t,
      size,
      scale,
    ) async {
      when(() => c.state).thenReturn(loaded);
      await pumpPage(t, feed(c), size: size, textScale: scale);
      expect(t.takeException(), isNull);
      expect(find.text('Creator h1'), findsOneWidget);
      expect(find.text('Caption a'), findsOneWidget);
      expect(
        find.textContaining('Video call · 1,500 Diamonds/min'),
        findsOneWidget,
      );
      expect(find.text('Online'), findsOneWidget);
      expect(find.textContaining("playback isn't available"), findsOneWidget);
      // Without a player there are no play/mute controls (no dead buttons).
      expect(find.byTooltip('Unmute'), findsNothing);
      // Customer mode only watches: posting lives in host mode.
      expect(find.byTooltip('Post a reel'), findsNothing);
      expect(find.byTooltip('My reels'), findsNothing);
      expect(find.text('For you'), findsOneWidget);
    });

    testWidgets('call CTA logs the click and opens the pre-call screen', (
      t,
    ) async {
      when(() => c.state).thenReturn(loaded);
      await pumpPage(t, feed(c));
      await t.tap(find.textContaining('Video call'));
      await t.pumpAndSettle();
      verify(() => c.callCtaClicked(hostReel)).called(1);
      expect(find.text('Navigated to /hosts/h1/call'), findsOneWidget);
    });

    testWidgets(
      'regular creators get no call CTA; offline hosts show status only',
      (t) async {
        final offline = reel(
          'o',
          by: creator(
            'h2',
            host: const ReelHost(
              availability: 'offline',
              ratePerMinute: 900,
              isVerified: false,
            ),
          ),
        );
        when(() => c.state).thenReturn(
          ReelsFeedLoaded(FeedTab.forYou, items: [reel('b')], nextCursor: null),
        );
        await pumpPage(t, feed(c));
        expect(find.textContaining('Video call'), findsNothing);
        expect(find.text('View host profile'), findsNothing);
        when(() => c.state).thenReturn(
          ReelsFeedLoaded(FeedTab.forYou, items: [offline], nextCursor: null),
        );
        await pumpPage(t, feed(c));
        // No separate profile button: the creator's name opens the profile.
        expect(find.text('View host profile'), findsNothing);
        expect(find.byType(FilledButton), findsNothing);
        expect(find.text('Offline'), findsOneWidget);
      },
    );

    testWidgets('with a registered player: video and mute control are shown', (
      t,
    ) async {
      when(() => c.state).thenReturn(loaded);
      await pumpPage(t, feed(c, player: _FakePlayer()));
      expect(
        find.text('player https://play.example/a/playback.mp4'),
        findsOneWidget,
      );
      await t.tap(find.byTooltip('Unmute'));
      verify(c.toggleMute).called(1);
    });

    testWidgets('like, follow and report actions reach the cubit', (t) async {
      when(() => c.state).thenReturn(
        ReelsFeedLoaded(FeedTab.forYou, items: [reel('b')], nextCursor: null),
      );
      await pumpPage(t, feed(c));
      await t.tap(find.byTooltip('Like'));
      verify(() => c.toggleLike('b')).called(1);
      await t.tap(find.text('Follow'));
      verify(() => c.toggleFollow('c-b')).called(1);
      await t.tap(find.byTooltip('Report or block'));
      await t.pumpAndSettle();
      await tapVisible(t, find.text('Spam or scam'));
      await t.pumpAndSettle();
      verify(() => c.report('b', ReelReportCategory.spamOrScam)).called(1);
    });

    testResponsive('empty Following tab explains what to do', (
      t,
      size,
      scale,
    ) async {
      when(() => c.state).thenReturn(
        const ReelsFeedLoaded(FeedTab.following, items: [], nextCursor: null),
      );
      await pumpPage(t, feed(c), size: size, textScale: scale);
      expect(t.takeException(), isNull);
      expect(find.text('No reels from people you follow'), findsOneWidget);
    });

    testResponsive('error with retry; disabled without retry', (
      t,
      size,
      scale,
    ) async {
      when(
        () => c.state,
      ).thenReturn(const ReelsFeedFailed(FeedTab.forYou, NetworkFailure()));
      await pumpPage(t, feed(c), size: size, textScale: scale);
      expect(t.takeException(), isNull);
      expect(find.text("Couldn't load reels"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      when(() => c.state).thenReturn(
        const ReelsFeedFailed(
          FeedTab.forYou,
          ServerFailure(code: 'reels_disabled'),
        ),
      );
      await pumpPage(t, feed(c), size: size, textScale: scale);
      expect(find.text('Reels is off'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('single-reel mode has no tabs', (t) async {
      when(() => c.state).thenReturn(
        ReelsFeedLoaded(FeedTab.forYou, items: [reel('x')], nextCursor: null),
      );
      await pumpPage(t, feed(c, single: true));
      expect(find.text('For you'), findsNothing);
      expect(find.text('Caption x'), findsOneWidget);
    });
  });

  group('CreatorProfilePage', () {
    late MockCreatorCubit c;
    setUp(() {
      c = MockCreatorCubit();
      when(() => c.load(any())).thenAnswer((_) async {});
      when(() => c.refresh()).thenAnswer((_) async {});
      when(() => c.loadMore()).thenAnswer((_) async {});
      when(() => c.toggleFollow()).thenAnswer((_) async {});
    });
    Widget page(String id) => BlocProvider<CreatorProfileCubit>.value(
      value: c,
      child: CreatorProfilePage(userId: id),
    );

    testResponsive('host creator: verified, availability, follow and call', (
      t,
      size,
      scale,
    ) async {
      when(() => c.state).thenReturn(
        CreatorProfileLoaded(
          profile: CreatorProfile(
            creator: creator('h1', host: host),
            bio: 'Classical singer',
            followerCount: 1200,
            followingCount: 3,
            reelCount: 2,
            isSelf: false,
          ),
          reels: [reel('a'), reel('b')],
          nextCursor: null,
        ),
      );
      await pumpPage(t, page('h1'), size: size, textScale: scale);
      expect(t.takeException(), isNull);
      expect(find.text('Verified host'), findsOneWidget);
      expect(find.text('Classical singer'), findsOneWidget);
      expect(find.text('1,200'), findsOneWidget);
      expect(find.text('Follow'), findsOneWidget);
      expect(find.textContaining('Video call'), findsOneWidget);
    });

    testResponsive('own profile shows statuses and post button; no follow', (
      t,
      size,
      scale,
    ) async {
      when(() => c.state).thenReturn(
        CreatorProfileLoaded(
          profile: CreatorProfile(
            creator: creator('me'),
            followerCount: 0,
            followingCount: 0,
            reelCount: 0,
            isSelf: true,
          ),
          reels: [
            reel('p', mine: true, status: ReelStatus.inReview),
            reel(
              'q',
              mine: true,
              status: ReelStatus.rejected,
              rejection: 'sexual_content',
            ),
          ],
          nextCursor: null,
        ),
      );
      await pumpPage(t, page('me'), size: size, textScale: scale);
      expect(t.takeException(), isNull);
      expect(find.text('My reels'), findsOneWidget);
      // Short landscape windows with large text: the grid is below the fold.
      await t.scrollUntilVisible(
        find.text('Not approved'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('In safety review'), findsOneWidget);
      expect(find.text('Not approved'), findsOneWidget);
      expect(find.text('Follow'), findsNothing);
      expect(find.text('Post a reel'), findsOneWidget);
      expect(find.textContaining('Video call'), findsNothing);
    });

    testWidgets('own rejected reel sheet offers appeal and delete', (t) async {
      when(() => c.state).thenReturn(
        CreatorProfileLoaded(
          profile: CreatorProfile(
            creator: creator('me'),
            followerCount: 0,
            followingCount: 0,
            reelCount: 0,
            isSelf: true,
          ),
          reels: [
            reel(
              'q',
              mine: true,
              status: ReelStatus.rejected,
              rejection: 'sexual_content',
            ),
          ],
          nextCursor: null,
        ),
      );
      await pumpPage(t, page('me'));
      await t.tap(find.text('Not approved'));
      await t.pumpAndSettle();
      expect(find.textContaining('nudity or sexual content'), findsOneWidget);
      expect(find.text('Appeal this decision'), findsOneWidget);
      expect(find.text('Delete reel'), findsOneWidget);
    });

    testResponsive('error state has retry', (t, size, scale) async {
      when(
        () => c.state,
      ).thenReturn(const CreatorProfileFailed(NotFoundFailure()));
      await pumpPage(t, page('x'), size: size, textScale: scale);
      expect(t.takeException(), isNull);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('ReelUploadPage', () {
    late MockUploadCubit c;
    setUp(() {
      c = MockUploadCubit();
      when(() => c.pick(any())).thenAnswer((_) async {});
      when(() => c.submit(any())).thenAnswer((_) async {});
    });
    Widget page() => BlocProvider<ReelUploadCubit>.value(
      value: c,
      child: const ReelUploadPage(),
    );

    testResponsive('pick screen: record, gallery and rules', (
      t,
      size,
      scale,
    ) async {
      when(() => c.state).thenReturn(const UploadPick(config));
      await pumpPage(t, page(), size: size, textScale: scale);
      expect(t.takeException(), isNull);
      expect(find.text('Record video'), findsOneWidget);
      expect(find.text('Choose from gallery'), findsOneWidget);
      expect(find.textContaining('15–60 seconds'), findsOneWidget);
      await tapVisible(t, find.text('Record video'));
      verify(() => c.pick(ReelVideoSource.camera)).called(1);
    });

    testResponsive('unavailable is explained', (t, size, scale) async {
      when(() => c.state).thenReturn(
        const UploadUnavailable(
          "Video uploads aren't set up on this server yet.",
        ),
      );
      await pumpPage(t, page(), size: size, textScale: scale);
      expect(t.takeException(), isNull);
      expect(find.text('Posting is unavailable'), findsOneWidget);
    });

    testResponsive('preview with caption and an error banner', (
      t,
      size,
      scale,
    ) async {
      when(() => c.state).thenReturn(
        UploadPreview(
          config,
          PickedVideo(bytes: List.filled(2 << 20, 0), contentType: 'video/mp4'),
          22000,
          error: 'You can post up to 10 reels a day.',
        ),
      );
      await pumpPage(t, page(), size: size, textScale: scale);
      expect(t.takeException(), isNull);
      expect(find.text('22.0 s · 2.0 MB'), findsOneWidget);
      expect(find.text('You can post up to 10 reels a day.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testResponsive('progress and tracking states', (t, size, scale) async {
      when(() => c.state).thenReturn(const UploadSending(0.42));
      await pumpPage(t, page(), size: size, textScale: scale);
      expect(find.text('42%'), findsOneWidget);
      when(() => c.state).thenReturn(
        UploadTracking(
          reel('n', mine: true, status: ReelStatus.inReview),
          polling: true,
        ),
      );
      await pumpPage(t, page(), size: size, textScale: scale);
      expect(t.takeException(), isNull);
      expect(find.text('Safety review'), findsOneWidget);
      expect(
        find.text('Only you can see it until it is approved.'),
        findsOneWidget,
      );
      when(() => c.state).thenReturn(
        UploadTracking(
          reel(
            'n',
            mine: true,
            status: ReelStatus.rejected,
            rejection: 'graphic_or_offensive',
          ),
          polling: false,
        ),
      );
      await pumpPage(t, page(), size: size, textScale: scale);
      expect(find.text('Your reel was not published'), findsOneWidget);
      expect(find.textContaining('graphic or offensive'), findsOneWidget);
    });

    // Regression (2026-11-27): an upload the server had not confirmed was
    // shown as "Uploaded" with a ticked first step.
    testResponsive('an unconfirmed upload is not shown as uploaded', (
      t,
      size,
      scale,
    ) async {
      when(() => c.state).thenReturn(
        UploadTracking(
          reel('n', mine: true, status: ReelStatus.awaitingUpload),
          polling: true,
        ),
      );
      await pumpPage(t, page(), size: size, textScale: scale);
      expect(t.takeException(), isNull);
      expect(find.text('Confirming your upload'), findsOneWidget);
      expect(
        find.text('Confirming your upload with the server…'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check_circle), findsNothing);
      when(() => c.state).thenReturn(
        UploadTracking(
          reel('n', mine: true, status: ReelStatus.awaitingUpload),
          polling: false,
        ),
      );
      await pumpPage(t, page(), size: size, textScale: scale);
      expect(
        find.textContaining("couldn't confirm the upload"),
        findsOneWidget,
      );
    });
  });
}
