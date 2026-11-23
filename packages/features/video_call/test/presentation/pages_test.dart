import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:feature_video_call/feature_video_call.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

class _PreCall extends MockCubit<PreCallState> implements PreCallCubit {}

class _Call extends MockBloc<CallBlocEvent, CallState> implements CallBloc {}

class _Summary extends MockCubit<CallSummaryState>
    implements CallSummaryCubit {}

class _History extends MockCubit<CallHistoryState>
    implements CallHistoryCubit {}

const _info = PreCallInfo(
  hostUserId: 'h1',
  hostName: 'Ananya',
  hostAge: 24,
  ratePerMinute: 2400,
  availability: 'available',
  availableDiamonds: 12480,
  approxPaisePerDiamondMilli: 2200,
);

void main() {
  for (final MapEntry(key: name, value: size) in {
    ...sizes,
    'landscape': const Size(640, 360),
  }.entries) {
    group(name, () {
      group('PreCallPage', () {
        Future<_PreCall> pump(WidgetTester t, PreCallState s) async {
          final c = _PreCall();
          when(() => c.state).thenReturn(s);
          when(() => c.load(any())).thenAnswer((_) async {});
          when(c.startCall).thenAnswer((_) async {});
          await pumpPage(
            t,
            BlocProvider<PreCallCubit>.value(
              value: c,
              child: const PreCallPage(hostUserId: 'h1'),
            ),
            size: size,
          );
          return c;
        }

        testWidgets('V01 shows rate, ₹ hint, balance and start', (t) async {
          final c = await pump(t, const PreCallReady(_info));
          expect(find.text('Ananya, 24'), findsOneWidget);
          expect(find.text('≈ ₹52.80 / min'), findsOneWidget);
          await t.ensureVisible(find.text('Start video call'));
          await t.pump();
          await t.tap(find.text('Start video call'));
          verify(c.startCall).called(1);
        });

        testWidgets('V06 insufficient balance offers Buy Diamonds', (t) async {
          await pump(
            t,
            const PreCallReady(
              PreCallInfo(
                hostUserId: 'h1',
                hostName: 'Kavya',
                ratePerMinute: 4500,
                availability: 'available',
                availableDiamonds: 1150,
              ),
            ),
          );
          expect(find.text('NEEDED TO START'), findsOneWidget);
          await t.ensureVisible(find.text('Buy Diamonds'));
          await t.pump();
          await t.tap(find.text('Buy Diamonds'));
          await t.pump();
          await t.pump(const Duration(milliseconds: 500));
          expect(find.text('route:/wallet/buy'), findsOneWidget);
        });

        testWidgets('busy host disables calling', (t) async {
          await pump(
            t,
            const PreCallReady(
              PreCallInfo(
                hostUserId: 'h1',
                hostName: 'Priya',
                ratePerMinute: 10,
                availability: 'busy',
                availableDiamonds: 1000,
              ),
            ),
          );
          expect(find.text('In a call. Try again soon'), findsOneWidget);
        });

        testWidgets('error offers retry', (t) async {
          final c = await pump(t, const PreCallFailed(NetworkFailure()));
          await t.tap(find.text('Try again'));
          verify(() => c.load('h1')).called(1);
        });
      });

      group('CallPage', () {
        Future<_Call> pump(WidgetTester t, CallState s) async {
          final b = _Call();
          when(() => b.state).thenReturn(s);
          await pumpPage(
            t,
            BlocProvider<CallBloc>.value(
              value: b,
              child: const CallPage(views: FakeViews(), manageSystemUi: false),
            ),
            size: size,
          );
          return b;
        }

        testWidgets('V02 ringing', (t) async {
          final b = await pump(
            t,
            CallState(
              status: CallUiStatus.ringing,
              session: session(phase: CallPhase.ringing),
            ),
          );
          expect(find.text('Ringing…'), findsOneWidget);
          await t.tap(find.byTooltip('Cancel call'));
          verify(() => b.add(const CallEndRequested())).called(1);
        });

        testWidgets('V03 connecting', (t) async {
          await pump(
            t,
            CallState(
              status: CallUiStatus.connecting,
              session: session(phase: CallPhase.connecting),
            ),
          );
          expect(find.text('Connecting securely…'), findsOneWidget);
          expect(find.text("You haven't been charged yet"), findsOneWidget);
          // One big avatar only: a second under the overlay shows through as
          // a doubled circle. (The small one in the top bar is separate.)
          expect(
            find.byWidgetPredicate((w) => w is UserAvatar && w.radius >= 40),
            findsOneWidget,
          );
        });

        testWidgets('V04/V05 active with safety chip and low balance', (
          t,
        ) async {
          final now = DateTime.now().toUtc();
          final b = await pump(
            t,
            CallState(
              status: CallUiStatus.active,
              mediaJoined: true,
              lowBalanceSecondsRemaining: 30,
              session: session(
                startedAt: now.subtract(const Duration(seconds: 30)),
                moderationEnds: now.add(const Duration(minutes: 2)),
                charged: 1200,
              ),
            ),
          );
          expect(find.text('remote-video'), findsOneWidget);
          expect(find.text('local-video'), findsOneWidget);
          expect(find.text('Safety check active'), findsOneWidget);
          expect(
            find.textContaining('seconds of talk time left'),
            findsOneWidget,
          );
          expect(find.textContaining('1,200 used'), findsOneWidget);
          await t.tap(find.byTooltip('Mute microphone'));
          verify(() => b.add(const CallMicrophoneToggled())).called(1);
        });

        testWidgets('safety chip hidden after the window', (t) async {
          final now = DateTime.now().toUtc();
          await pump(
            t,
            CallState(
              status: CallUiStatus.active,
              mediaJoined: true,
              session: session(
                moderationEnds: now.subtract(const Duration(seconds: 1)),
              ),
            ),
          );
          expect(find.text('Safety check active'), findsNothing);
        });

        testWidgets('report asks to confirm then ends with reason report', (
          t,
        ) async {
          final b = await pump(
            t,
            CallState(
              status: CallUiStatus.active,
              mediaJoined: true,
              session: session(),
            ),
          );
          await t.tap(find.byTooltip('Report'));
          await t.pump();
          await t.tap(find.text('End call and report'));
          await t.pump();
          verify(
            () => b.add(const CallEndRequested(reason: 'report')),
          ).called(1);
        });

        testWidgets('V07 reconnecting with server-confirmed pause', (t) async {
          await pump(
            t,
            CallState(
              status: CallUiStatus.paused,
              reconnecting: true,
              mediaJoined: true,
              session: session(phase: CallPhase.paused),
            ),
          );
          expect(find.text('Connection lost'), findsOneWidget);
          expect(find.textContaining('Billing is paused'), findsOneWidget);
        });

        testWidgets('V15 free minute', (t) async {
          await pump(
            t,
            CallState(
              status: CallUiStatus.active,
              mediaJoined: true,
              session: session(
                free: true,
                startedAt: DateTime.now().toUtc().subtract(
                  const Duration(seconds: 18),
                ),
              ),
            ),
          );
          expect(find.textContaining('FREE MINUTE'), findsOneWidget);
        });

        testWidgets('V16 incoming: accept and decline', (t) async {
          final b = await pump(
            t,
            CallState(
              status: CallUiStatus.incoming,
              session: session(
                role: CallRole.receiver,
                phase: CallPhase.ringing,
              ),
            ),
          );
          expect(find.text('Incoming video call'), findsOneWidget);
          // Everything is centred on the screen, not pushed to the left edge.
          final centre = t.getSize(find.byType(Scaffold).first).width / 2;
          expect(
            t.getCenter(find.text('Incoming video call')).dx,
            closeTo(centre, 8),
          );
          final pair =
              (t.getCenter(find.text('Decline')).dx +
                  t.getCenter(find.text('Accept')).dx) /
              2;
          expect(pair, closeTo(centre, 8), reason: 'buttons off-centre');
          await t.tap(find.byIcon(Icons.videocam_rounded));
          verify(() => b.add(const CallIncomingAccepted('c1'))).called(1);
          await t.tap(find.byTooltip('Decline'));
          verify(() => b.add(const CallIncomingDeclined('c1'))).called(1);
        });

        testWidgets('V17 host active shows server Beans', (t) async {
          await pump(
            t,
            CallState(
              status: CallUiStatus.active,
              mediaJoined: true,
              session: session(role: CallRole.receiver, beans: 10702),
            ),
          );
          expect(find.textContaining('Beans this call'), findsOneWidget);
        });

        testWidgets('failure shows the message and end action', (t) async {
          final b = await pump(
            t,
            CallState(
              status: CallUiStatus.failed,
              session: session(phase: CallPhase.accepted),
              failure: const PlatformFailure(code: 'video_not_configured'),
            ),
          );
          expect(
            find.text("Video calling isn't set up in this build yet."),
            findsOneWidget,
          );
          await t.tap(find.text('End call'));
          verify(() => b.add(const CallEndRequested())).called(1);
        });

        testWidgets('ended navigates to the summary', (t) async {
          final b = _Call();
          whenListen(
            b,
            Stream.value(
              CallState(
                status: CallUiStatus.ended,
                session: session(phase: CallPhase.ended),
              ),
            ),
            initialState: CallState(
              status: CallUiStatus.active,
              session: session(),
            ),
          );
          await pumpPage(
            t,
            BlocProvider<CallBloc>.value(
              value: b,
              child: const CallPage(views: FakeViews(), manageSystemUi: false),
            ),
            size: size,
          );
          await t.pump();
          await t.pump();
          expect(find.text('route:/calls/c1/summary'), findsOneWidget);
        });
      });

      group('CallSummaryPage', () {
        Future<void> pump(WidgetTester t, CallSummaryState s) async {
          final c = _Summary();
          when(() => c.state).thenReturn(s);
          when(() => c.load(any())).thenAnswer((_) async {});
          await pumpPage(
            t,
            BlocProvider<CallSummaryCubit>.value(
              value: c,
              child: const CallSummaryPage(callId: 'c1'),
            ),
            size: size,
          );
        }

        testWidgets('V09 customer summary has no rating', (t) async {
          await pump(
            t,
            CallSummaryLoaded(
              session(phase: CallPhase.ended, billed: 185, charged: 7400),
              balance: 5080,
            ),
          );
          expect(find.text('3 min 05 s'), findsOneWidget);
          expect(find.text('Balance remaining'), findsOneWidget);
          expect(find.byIcon(Icons.star), findsNothing);
          expect(find.text('Report a problem'), findsOneWidget);
        });

        testWidgets('V10 balance ran out', (t) async {
          await pump(
            t,
            CallSummaryLoaded(
              session(phase: CallPhase.ended, endReason: 'low_balance'),
              balance: 0,
            ),
          );
          expect(find.textContaining('Your balance ran out'), findsOneWidget);
          expect(find.text('Top up Diamonds'), findsOneWidget);
        });

        testWidgets('V08 not answered', (t) async {
          await pump(t, CallSummaryLoaded(session(phase: CallPhase.missed)));
          expect(find.text("Ananya couldn't take your call"), findsOneWidget);
        });

        testWidgets('V14 failed and refunded', (t) async {
          await pump(t, CallSummaryLoaded(session(phase: CallPhase.failed)));
          expect(find.text('All Diamonds returned'), findsOneWidget);
        });

        testWidgets('V18 host without Beans points to Earnings', (t) async {
          await pump(
            t,
            CallSummaryLoaded(
              session(role: CallRole.receiver, phase: CallPhase.ended),
            ),
          );
          expect(
            find.textContaining('will appear in Earnings'),
            findsOneWidget,
          );
        });

        testWidgets('V18 host with server Beans', (t) async {
          await pump(
            t,
            CallSummaryLoaded(
              session(
                role: CallRole.receiver,
                phase: CallPhase.ended,
                beans: 18236,
              ),
            ),
          );
          expect(find.text('YOU EARNED'), findsOneWidget);
        });

        testWidgets('error', (t) async {
          await pump(t, const CallSummaryFailed(NetworkFailure()));
          expect(find.text('Try again'), findsOneWidget);
        });
      });

      group('CallHistoryPage', () {
        Future<void> pump(WidgetTester t, CallHistoryState s) async {
          final c = _History();
          when(() => c.state).thenReturn(s);
          when(c.load).thenAnswer((_) async {});
          when(c.loadMore).thenAnswer((_) async {});
          await pumpPage(
            t,
            BlocProvider<CallHistoryCubit>.value(
              value: c,
              child: const CallHistoryPage(),
            ),
            size: size,
          );
        }

        testWidgets('loaded', (t) async {
          await pump(
            t,
            CallHistoryLoaded([
              session(phase: CallPhase.ended, billed: 65, charged: 2600),
            ]),
          );
          expect(find.text('Ananya'), findsOneWidget);
          expect(find.textContaining('1 min 05 s'), findsOneWidget);
        });

        testWidgets('empty', (t) async {
          await pump(t, const CallHistoryLoaded([]));
          expect(find.text('No calls yet'), findsOneWidget);
        });

        testWidgets('error', (t) async {
          await pump(t, const CallHistoryFailed(NetworkFailure()));
          expect(find.text('Try again'), findsOneWidget);
        });
      });
    });
  }

  testWidgets('IncomingCallWatcher reports rings', (t) async {
    final cubit = _IncomingCubit();
    whenListen(
      cubit,
      Stream.value(const IncomingCallState(callId: 'c7', sequence: 1)),
      initialState: const IncomingCallState(),
    );
    final seen = <String>[];
    await t.pumpWidget(
      IncomingCallWatcher(
        cubit: cubit,
        onIncomingCall: seen.add,
        child: const SizedBox(),
      ),
    );
    await t.pump();
    expect(seen, ['c7']);
  });
}

class _IncomingCubit extends MockCubit<IncomingCallState>
    implements IncomingCallCubit {}
