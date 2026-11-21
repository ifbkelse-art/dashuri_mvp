import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_notifications/feature_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';

void main() {
  late MockListInbox list;
  late MockMarkRead markRead;
  late MockWatchNewNotifications watch;
  late StreamController<void> hints;

  setUpAll(() {
    registerFallbackValue(const PageRequest());
    registerFallbackValue(const NoInput());
  });
  setUp(() {
    list = MockListInbox();
    markRead = MockMarkRead();
    watch = MockWatchNewNotifications();
    hints = StreamController<void>.broadcast();
    when(() => watch(any())).thenAnswer((_) => hints.stream);
  });
  tearDown(() => hints.close());

  InboxCubit build() => InboxCubit(list, markRead, watch, FixedClock());

  blocTest<InboxCubit, InboxState>(
    'emits Loading then Failed when the use case fails',
    setUp: () => when(
      () => list(any()),
    ).thenAnswer((_) async => const Err(NetworkFailure())),
    build: build,
    act: (c) => c.load(),
    expect: () => const [
      InboxStateLoading(),
      InboxStateFailed(NetworkFailure()),
    ],
  );

  blocTest<InboxCubit, InboxState>(
    'a realtime notification.created hint re-fetches silently',
    setUp: () {
      var n = 0;
      when(() => list(any())).thenAnswer(
        (_) async =>
            Success(Page(items: [if (n++ > 0) item('new'), item('a')])),
      );
    },
    build: build,
    act: (c) async {
      await c.load();
      hints.add(null);
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => [
      const InboxStateLoading(),
      InboxStateLoaded(Page(items: [item('a')])),
      InboxStateLoaded(Page(items: [item('new'), item('a')])),
    ],
  );

  blocTest<InboxCubit, InboxState>(
    'markRead is optimistic and reverts on failure',
    setUp: () => when(
      () => markRead(any()),
    ).thenAnswer((_) async => const Err(NetworkFailure())),
    build: build,
    seed: () => InboxStateLoaded(Page(items: [item('a')])),
    act: (c) => c.markRead('a'),
    expect: () => [
      InboxStateLoaded(
        Page(
          items: [
            InboxItem(
              id: 'a',
              kind: item('a').kind,
              title: item('a').title,
              body: item('a').body,
              createdAt: item('a').createdAt,
              readAt: FixedClock().now(),
            ),
          ],
        ),
      ),
      InboxStateLoaded(Page(items: [item('a')])),
    ],
  );

  blocTest<InboxCubit, InboxState>(
    'markAllRead marks every unread item',
    setUp: () => when(
      () => markRead(any()),
    ).thenAnswer((_) async => const Success<void>(null)),
    build: build,
    seed: () => InboxStateLoaded(
      Page(items: [item('a'), item('b'), item('c', read: true)]),
    ),
    act: (c) => c.markAllRead(),
    verify: (c) {
      verify(() => markRead('a')).called(1);
      verify(() => markRead('b')).called(1);
      verifyNever(() => markRead('c'));
      expect((c.state as InboxStateLoaded).unreadCount, 0);
    },
  );

  blocTest<InboxCubit, InboxState>(
    'loadMore appends',
    setUp: () => when(
      () => list(any()),
    ).thenAnswer((_) async => Success(Page(items: [item('b')]))),
    build: build,
    seed: () => InboxStateLoaded(Page(items: [item('a')], nextCursor: 'n')),
    act: (c) => c.loadMore(),
    skip: 1,
    expect: () => [
      InboxStateLoaded(Page(items: [item('a'), item('b')])),
    ],
  );
}
