import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_chat/feature_chat.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fixtures.dart';
import '../helpers/pump.dart';

class InboxCubitMock extends MockCubit<ConversationsState>
    implements ConversationsCubit {}

class ConversationCubitMock extends MockCubit<ConversationState>
    implements ConversationCubit {}

ConversationState ready({
  List<ChatBubble>? bubbles,
  bool filterNotice = false,
}) => ConversationState(
  status: ConversationStatus.ready,
  conversationId: 'c1',
  peerUserId: 'peer',
  peerName: 'Meera',
  bubbles:
      bubbles ??
      [
        ChatBubble.fromMessage(msg('m1'), myUserId: 'me'),
        ChatBubble.fromMessage(
          msg('m2', sender: 'me', body: 'Haha it is my happy place'),
          myUserId: 'me',
        ),
      ],
  filterNotice: filterNotice,
);

ConversationCubitMock convCubit(ConversationState s) {
  final c = ConversationCubitMock();
  when(() => c.state).thenReturn(s);
  when(() => c.send(any())).thenAnswer((_) async {});
  when(c.retry).thenAnswer((_) async {});
  when(c.loadOlder).thenAnswer((_) async {});
  return c;
}

Widget inbox(
  InboxCubitMock cubit, {
  Widget Function(BuildContext, Conversation)? b,
}) => BlocProvider<ConversationsCubit>.value(
  value: cubit,
  child: ConversationsPage(
    conversationBuilder:
        b ?? (_, c) => Text('conversation:${c.peerDisplayName}'),
  ),
);

void main() {
  for (final size in [phone, tablet]) {
    final expanded = size.width >= 840;
    group('at ${size.width.toInt()}x${size.height.toInt()}', () {
      testWidgets('CH01 inbox rows, unread badge, "You:" prefix and open', (
        tester,
      ) async {
        final cubit = InboxCubitMock();
        when(() => cubit.state).thenReturn(
          ConversationsStateLoaded(Page(items: [meera, kavya]), myUserId: 'me'),
        );
        when(cubit.loadMore).thenAnswer((_) async {});
        await pumpPage(tester, inbox(cubit), size: size, textScale: 1.3);
        expect(find.text('Meera'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('You: Thank you'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Meera'));
        await tester.pumpAndSettle();
        if (expanded) {
          // Two-pane: the conversation opens on the right.
          expect(find.text('conversation:Meera'), findsOneWidget);
          expect(find.text('Chats'), findsOneWidget);
        } else {
          expect(find.text('route:/messages/c1'), findsOneWidget);
        }
      });

      // UI/UX pass: known bug "Chats tab doesn't refresh" — coming back from
      // a conversation re-fetches, so unread counts and previews update.
      if (!expanded) {
        testWidgets('CH01 returning from a conversation refreshes the inbox', (
          tester,
        ) async {
          final cubit = InboxCubitMock();
          when(() => cubit.state).thenReturn(
            ConversationsStateLoaded(Page(items: [meera]), myUserId: 'me'),
          );
          when(() => cubit.isClosed).thenReturn(false);
          when(cubit.refresh).thenAnswer((_) async {});
          when(cubit.loadMore).thenAnswer((_) async {});
          final router = await pumpPage(tester, inbox(cubit), size: size);
          await tester.tap(find.text('Meera'));
          await tester.pumpAndSettle();
          verifyNever(cubit.refresh);
          router.pop();
          await tester.pumpAndSettle();
          verify(cubit.refresh).called(1);
        });
      }

      testWidgets('CH01 search filters by name', (tester) async {
        final cubit = InboxCubitMock();
        when(
          () => cubit.state,
        ).thenReturn(ConversationsStateLoaded(Page(items: [meera, kavya])));
        when(cubit.loadMore).thenAnswer((_) async {});
        await pumpPage(tester, inbox(cubit), size: size);
        await tester.enterText(find.byType(TextField), 'kav');
        await tester.pump();
        expect(find.text('Meera'), findsNothing);
        expect(find.text('Kavya'), findsOneWidget);
      });

      testWidgets('CH03 empty inbox and error state', (tester) async {
        final cubit = InboxCubitMock();
        when(
          () => cubit.state,
        ).thenReturn(const ConversationsStateLoaded(Page(items: [])));
        await pumpPage(tester, inbox(cubit), size: size);
        expect(find.text('No conversations yet'), findsOneWidget);
        await tester.tap(find.text('Discover hosts'));
        await tester.pumpAndSettle();
        expect(find.text('route:/discover'), findsOneWidget);

        final failed = InboxCubitMock();
        when(
          () => failed.state,
        ).thenReturn(const ConversationsStateFailed(NetworkFailure()));
        when(failed.load).thenAnswer((_) async {});
        await pumpPage(tester, inbox(failed), size: size);
        await tester.tap(find.text('Try again'));
        verify(failed.load).called(1);
      });

      testWidgets('CH02 messages, send, and report/block menu', (tester) async {
        final c = convCubit(ready());
        await pumpPage(
          tester,
          BlocProvider<ConversationCubit>.value(
            value: c,
            child: const ConversationPage(),
          ),
          size: size,
        );
        expect(find.text('message m1'), findsOneWidget);
        expect(find.text('Haha it is my happy place'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Hello there');
        await tester.tap(find.byTooltip('Send'));
        verify(() => c.send('Hello there')).called(1);

        await tester.tap(find.byTooltip('More'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Block'));
        await tester.pumpAndSettle();
        expect(
          find.text('route:/report?userId=peer&name=Meera&mode=block'),
          findsOneWidget,
        );
      });

      testWidgets('CH02 pending and failed bubbles', (tester) async {
        final c = convCubit(
          ready(
            bubbles: [
              ChatBubble(
                localId: 'k1',
                body: 'on its way',
                sentAt: t0,
                mine: true,
                status: BubbleStatus.sending,
              ),
              ChatBubble(
                localId: 'k2',
                body: 'oops',
                sentAt: t0,
                mine: true,
                status: BubbleStatus.failed,
              ),
            ],
          ),
        );
        when(() => c.retrySend(any())).thenAnswer((_) async {});
        await pumpPage(
          tester,
          BlocProvider<ConversationCubit>.value(
            value: c,
            child: const ConversationPage(),
          ),
          size: size,
        );
        expect(find.text('Sending…'), findsOneWidget);
        await tester.tap(find.text('oops'));
        verify(() => c.retrySend('k2')).called(1);
      });

      testWidgets('CH05 filter notice and rejected bubble', (tester) async {
        final c = convCubit(
          ready(
            filterNotice: true,
            bubbles: [
              ChatBubble(
                localId: 'k1',
                body: 'my number is 98204',
                sentAt: t0,
                mine: true,
                status: BubbleStatus.rejected,
              ),
            ],
          ),
        );
        await pumpPage(
          tester,
          BlocProvider<ConversationCubit>.value(
            value: c,
            child: const ConversationPage(),
          ),
          size: size,
          textScale: 1.3,
        );
        expect(find.text('Keep conversations on Dashuri'), findsOneWidget);
        expect(find.text('Not sent'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('CH04 restricted: explanation and Call instead', (
        tester,
      ) async {
        final c = convCubit(
          const ConversationState(
            status: ConversationStatus.restricted,
            peerUserId: 'peer',
            peerName: 'Naina',
          ),
        );
        await pumpPage(
          tester,
          BlocProvider<ConversationCubit>.value(
            value: c,
            child: const ConversationPage(),
          ),
          size: size,
        );
        expect(
          find.text('Naina accepts messages after a call'),
          findsOneWidget,
        );
        expect(find.byType(TextField), findsNothing);
        await tester.tap(find.text('Call instead'));
        await tester.pumpAndSettle();
        expect(find.text('route:/hosts/peer/call'), findsOneWidget);
      });

      testWidgets('CH02 error state retries; new route is replaced', (
        tester,
      ) async {
        final c = convCubit(
          const ConversationState(
            status: ConversationStatus.failed,
            failure: NetworkFailure(),
          ),
        );
        await pumpPage(
          tester,
          BlocProvider<ConversationCubit>.value(
            value: c,
            child: const ConversationPage(),
          ),
          size: size,
        );
        await tester.tap(find.text('Try again'));
        verify(c.retry).called(1);

        final started = ConversationCubitMock();
        whenListen(
          started,
          Stream.fromIterable([
            const ConversationState(
              status: ConversationStatus.loading,
              conversationId: 'c9',
              peerUserId: 'peer',
            ),
          ]),
          initialState: const ConversationState(
            status: ConversationStatus.starting,
            peerUserId: 'peer',
          ),
        );
        await pumpPage(
          tester,
          BlocProvider<ConversationCubit>.value(
            value: started,
            child: const ConversationPage(replaceRouteWhenStarted: true),
          ),
          size: size,
        );
        await tester.pumpAndSettle();
        expect(find.text('route:/messages/c9'), findsOneWidget);
      });
    });
  }
}
