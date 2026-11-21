import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_notifications/feature_notifications.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';
import '../helpers/pump.dart';

void main() {
  final now = DateTime.utc(2026, 11, 21, 12);

  Future<MockInboxCubit> pump(
    WidgetTester t,
    InboxState s,
    Size size,
    double scale,
  ) async {
    final cubit = MockInboxCubit();
    when(() => cubit.markRead(any())).thenAnswer((_) async {});
    when(cubit.markAllRead).thenAnswer((_) async {});
    when(cubit.loadMore).thenAnswer((_) async {});
    when(cubit.refresh).thenAnswer((_) async {});
    whenListen(cubit, const Stream<InboxState>.empty(), initialState: s);
    await pumpPage(
      t,
      BlocProvider<InboxCubit>.value(
        value: cubit,
        child: NotificationsPage(now: now),
      ),
      size: size,
      textScale: scale,
    );
    return cubit;
  }

  testResponsive('grouped by day with unread dot and mark all', (
    tester,
    size,
    scale,
  ) async {
    final cubit = await pump(
      tester,
      InboxStateLoaded(
        Page(
          items: [
            item('a'),
            item(
              'b',
              at: DateTime.utc(2026, 11, 20, 9),
              read: true,
              kind: 'call.summary',
            ),
          ],
        ),
      ),
      size,
      scale,
    );
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('YESTERDAY'), findsOneWidget);
    await tapVisible(tester, find.byTooltip('Mark all as read'));
    verify(cubit.markAllRead).called(1);
  });

  testWidgets('tapping marks read and opens the related screen', (
    tester,
  ) async {
    final cubit = await pump(
      tester,
      InboxStateLoaded(Page(items: [item('a')])),
      phone,
      1,
    );
    await tapVisible(tester, find.text('Diamonds added'));
    await tester.pumpAndSettle();
    verify(() => cubit.markRead('a')).called(1);
    expect(find.text('Navigated to /wallet/transactions'), findsOneWidget);
  });

  testResponsive('empty state', (tester, size, scale) async {
    await pump(
      tester,
      const InboxStateLoaded(Page<InboxItem>(items: [])),
      size,
      scale,
    );
    expect(find.text('No notifications yet'), findsOneWidget);
  });

  testWidgets('error retries', (tester) async {
    final cubit = await pump(
      tester,
      const InboxStateFailed(NetworkFailure()),
      tablet,
      1,
    );
    when(cubit.load).thenAnswer((_) async {});
    await tapVisible(tester, find.text('Try again'));
    verify(cubit.load).called(1);
  });

  test('destinations by kind use route constants', () {
    expect(NotificationsPage.destinationFor('chat.message'), '/messages');
    expect(
      NotificationsPage.destinationFor('report.reviewed'),
      '/settings/account-status',
    );
    expect(NotificationsPage.destinationFor('mystery'), isNull);
  });
}
