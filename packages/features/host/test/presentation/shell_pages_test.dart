import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_host/feature_host.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

void main() {
  setUpAll(registerHostFallbacks);

  group('H11/H12 dashboard and H13 availability', () {
    late MockGetHostStatus getStatus;
    late MockSetAvailability setAvailability;
    late MockSetFreeCallOptIn setOptIn;
    late MockGetMyHostProfile getProfile;
    late MockSendHeartbeat heartbeat;
    late HostPresenceController presence;

    setUp(() {
      getStatus = MockGetHostStatus();
      setAvailability = MockSetAvailability();
      setOptIn = MockSetFreeCallOptIn();
      getProfile = MockGetMyHostProfile();
      heartbeat = MockSendHeartbeat();
      presence = HostPresenceController(
        heartbeat,
        timerFactory: FakeTimers().call,
      );
      when(
        () => getProfile(any()),
      ).thenAnswer((_) async => const Success(sampleProfile));
      when(() => heartbeat(any())).thenAnswer((_) async => const Success(null));
      when(
        () => getStatus(any()),
      ).thenAnswer((_) async => const Success(approvedOffline));
    });
    tearDown(() => presence.dispose());

    Widget dashboard([Widget page = const HostDashboardPage()]) => BlocProvider(
      create: (_) => HostDashboardCubit(
        getStatus,
        setAvailability: setAvailability,
        setFreeCallOptIn: setOptIn,
        getMyProfile: getProfile,
        presence: presence,
      )..load(),
      child: page,
    );

    for (final MapEntry(key: name, value: size) in testSizes.entries) {
      testWidgets('offline home renders at $name', (tester) async {
        await pumpHostPage(tester, dashboard(), size: size);
        expect(find.text("You're offline"), findsOneWidget);
        expect(find.text('Go online'), findsOneWidget);
        expect(find.text('Ananya'), findsOneWidget);
        expect(find.text('6'), findsOneWidget);
      });
    }

    testWidgets('go online toggles to H12 and starts heartbeats', (
      tester,
    ) async {
      when(
        () => setAvailability(true),
      ).thenAnswer((_) async => Success(approvedOnline));
      await pumpHostPage(tester, dashboard(), textScale: 1.3);
      await tester.tap(find.text('Go online'));
      await tester.pumpAndSettle();
      expect(find.text("You're online"), findsOneWidget);
      expect(find.text('Go offline'), findsOneWidget);
      expect(presence.isBeating, isTrue);
    });

    testWidgets('a refused toggle shows a message', (tester) async {
      when(() => setAvailability(true)).thenAnswer(
        (_) async => const Err(BusinessRuleFailure(code: 'in_call')),
      );
      await pumpHostPage(tester, dashboard(), size: tablet);
      await tester.tap(find.text('Go online'));
      await tester.pumpAndSettle();
      expect(
        find.text("You can't change availability during a call."),
        findsOneWidget,
      );
    });

    testWidgets('not approved shows the application card', (tester) async {
      when(
        () => getStatus(any()),
      ).thenAnswer((_) async => const Success(kycPendingHost));
      await pumpHostPage(tester, dashboard());
      expect(find.text('Your application is in review'), findsOneWidget);
      await tester.tap(find.text('View status'));
      await tester.pumpAndSettle();
      expect(find.text('stub:/host/verification'), findsOneWidget);
    });

    for (final size in [phone, tablet]) {
      testWidgets('error state with retry at $size', (tester) async {
        when(
          () => getStatus(any()),
        ).thenAnswer((_) async => const Err(NetworkFailure()));
        await pumpHostPage(tester, dashboard(), size: size);
        expect(find.text('Try again'), findsOneWidget);
        when(
          () => getStatus(any()),
        ).thenAnswer((_) async => const Success(approvedOffline));
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();
        expect(find.text("You're offline"), findsOneWidget);
      });

      testWidgets('H13 availability at $size', (tester) async {
        when(() => setOptIn(false)).thenAnswer(
          (_) async => Success(approvedOffline.copyWith(freeCallOptIn: false)),
        );
        await pumpHostPage(
          tester,
          dashboard(const HostAvailabilityPage()),
          size: size,
        );
        expect(find.text('Accept free calls'), findsOneWidget);
        await tester.tap(find.text('Accept free calls'));
        await tester.pumpAndSettle();
        verify(() => setOptIn(false)).called(1);
      });
    }

    testWidgets('H13 error state', (tester) async {
      when(
        () => getStatus(any()),
      ).thenAnswer((_) async => const Err(NetworkFailure()));
      await pumpHostPage(tester, dashboard(const HostAvailabilityPage()));
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('H22 calls', () {
    late MockListHostCalls list;
    setUp(() => list = MockListHostCalls());

    Widget page() => BlocProvider(
      create: (_) => HostCallsCubit(list)..load(),
      child: HostCallsPage(now: () => DateTime(2026, 11, 21, 23)),
    );

    for (final MapEntry(key: name, value: size) in testSizes.entries) {
      testWidgets('list renders at $name', (tester) async {
        when(() => list(any())).thenAnswer(
          (_) async => Success(
            Page(
              items: [
                sampleCall(),
                sampleCall(id: 'c2', phase: 'missed', seconds: 0, beans: null),
                sampleCall(id: 'c3', at: DateTime(2026, 11, 20, 22)),
              ],
              nextCursor: 'n',
            ),
          ),
        );
        await pumpHostPage(tester, page(), size: size);
        expect(find.text('TODAY'), findsOneWidget);
        expect(find.text('YESTERDAY'), findsOneWidget);
        expect(find.text('Load more'), findsOneWidget);
      });
    }

    testWidgets('report action opens the report route with ids', (
      tester,
    ) async {
      when(
        () => list(any()),
      ).thenAnswer((_) async => Success(Page(items: [sampleCall()])));
      await pumpHostPage(tester, page());
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'stub:/report?userId=22222222-2222-2222-2222-222222222222&callId=c1&name=Arjun',
        ),
        findsOneWidget,
      );
    });

    testWidgets('empty and error states', (tester) async {
      when(
        () => list(any()),
      ).thenAnswer((_) async => const Success(Page<HostCall>(items: [])));
      await pumpHostPage(tester, page(), size: tablet);
      expect(find.text('No calls yet'), findsOneWidget);
    });

    for (final size in [phone, tablet]) {
      testWidgets('error at $size', (tester) async {
        when(
          () => list(any()),
        ).thenAnswer((_) async => const Err(NetworkFailure()));
        await pumpHostPage(tester, page(), size: size);
        expect(find.text('Try again'), findsOneWidget);
      });
    }
  });

  group('H23 profile tab and H24 settings', () {
    late MockGetMyHostProfile getProfile;
    late MockGetHostStatus getStatus;
    late MockSetAvailability setAvailability;
    late HostPresenceController presence;

    setUp(() {
      getProfile = MockGetMyHostProfile();
      getStatus = MockGetHostStatus();
      setAvailability = MockSetAvailability();
      final hb = MockSendHeartbeat();
      presence = HostPresenceController(hb, timerFactory: FakeTimers().call);
      when(
        () => getProfile(any()),
      ).thenAnswer((_) async => const Success(sampleProfile));
      when(
        () => getStatus(any()),
      ).thenAnswer((_) async => const Success(approvedOffline));
    });
    tearDown(() => presence.dispose());

    Widget page({HostModeSwitch? modeSwitch}) => BlocProvider(
      create: (_) =>
          HostProfileTabCubit(getProfile, getStatus, setAvailability, presence)
            ..load(),
      child: HostProfileTabPage(modeSwitch: modeSwitch),
    );

    for (final MapEntry(key: name, value: size) in testSizes.entries) {
      testWidgets('profile tab renders at $name', (tester) async {
        await pumpHostPage(
          tester,
          page(modeSwitch: HostModeSwitch(() async {})),
          size: size,
        );
        expect(find.text('Verified host'), findsOneWidget);
        expect(find.text('Level 4'), findsOneWidget);
        expect(find.text('Switch to customer mode'), findsOneWidget);
      });
    }

    testWidgets('switch to customer calls the app callback', (tester) async {
      var switched = false;
      await pumpHostPage(
        tester,
        page(modeSwitch: HostModeSwitch(() async => switched = true)),
      );
      await tester.ensureVisible(find.text('Switch to customer mode'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Switch to customer mode'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Switch'));
      await tester.pumpAndSettle();
      expect(switched, isTrue);
    });

    testWidgets('without a mode switch the action is hidden', (tester) async {
      await pumpHostPage(tester, page());
      expect(find.text('Switch to customer mode'), findsNothing);
      await tester.tap(find.text('Preview as customer'));
      await tester.pumpAndSettle();
      expect(find.text('stub:/hosts/${sampleProfile.userId}'), findsOneWidget);
    });

    for (final size in [phone, tablet]) {
      testWidgets('profile tab error at $size', (tester) async {
        when(
          () => getStatus(any()),
        ).thenAnswer((_) async => const Err(NetworkFailure()));
        await pumpHostPage(tester, page(), size: size);
        expect(find.text('Try again'), findsOneWidget);
      });

      testWidgets('settings at $size link to shared settings', (tester) async {
        await pumpHostPage(tester, const HostSettingsPage(), size: size);
        await tester.ensureVisible(find.text('Blocked users'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Blocked users'));
        await tester.pumpAndSettle();
        expect(find.text('stub:/settings/blocked'), findsOneWidget);
      });
    }
  });
}
