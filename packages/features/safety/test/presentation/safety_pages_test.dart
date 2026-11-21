import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_safety/feature_safety.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';
import '../helpers/pump.dart';

void main() {
  setUpAll(() => registerFallbackValue(ReportCategory.other));

  group('AgeGatePage (A09/A10)', () {
    testResponsive('form with age and confirmation', (
      tester,
      size,
      scale,
    ) async {
      final cubit = MockAgeGateCubit();
      whenListen(
        cubit,
        const Stream<AgeGateState>.empty(),
        initialState: AgeGateState(dateOfBirth: DateTime(1998, 4, 14), age: 28),
      );
      await pumpPage(
        tester,
        BlocProvider<AgeGateCubit>.value(
          value: cubit,
          child: const AgeGatePage(),
        ),
        size: size,
        textScale: scale,
      );
      expect(find.text("When's your birthday?"), findsOneWidget);
      expect(find.text('14 April 1998'), findsOneWidget);
      expect(find.text('28 years'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tapVisible(tester, find.byType(Checkbox));
      verify(() => cubit.setConfirmed(true)).called(1);
    });

    testResponsive('blocked state for under 18', (tester, size, scale) async {
      final cubit = MockAgeGateCubit();
      whenListen(
        cubit,
        const Stream<AgeGateState>.empty(),
        initialState: const AgeGateState(outcome: AgeGateOutcome.blocked),
      );
      await pumpPage(
        tester,
        BlocProvider<AgeGateCubit>.value(
          value: cubit,
          child: const AgeGatePage(),
        ),
        size: size,
        textScale: scale,
      );
      expect(find.text('Dashuri is for adults only'), findsOneWidget);
      expect(find.text('Close app'), findsOneWidget);
    });

    testWidgets('error banner', (tester) async {
      final cubit = MockAgeGateCubit();
      whenListen(
        cubit,
        const Stream<AgeGateState>.empty(),
        initialState: const AgeGateState(failure: NetworkFailure()),
      );
      await pumpPage(
        tester,
        BlocProvider<AgeGateCubit>.value(
          value: cubit,
          child: const AgeGatePage(),
        ),
      );
      expect(find.textContaining('offline'), findsOneWidget);
    });
  });

  group('ReportPage (V11/V12)', () {
    testResponsive('reasons, details and also-block', (
      tester,
      size,
      scale,
    ) async {
      final cubit = MockReportCubit();
      whenListen(
        cubit,
        const Stream<ReportState>.empty(),
        initialState: const ReportState(),
      );
      await pumpPage(
        tester,
        BlocProvider<ReportCubit>.value(
          value: cubit,
          child: const ReportPage(name: 'Ananya', fromCall: true),
        ),
        size: size,
        textScale: scale,
      );
      expect(find.text('Report Ananya'), findsOneWidget);
      expect(find.textContaining('Reporting during a call'), findsOneWidget);
      for (final c in ReportCategory.values) {
        expect(find.text(c.label), findsOneWidget);
      }
      expect(find.text('Also block Ananya'), findsOneWidget);
      await tapVisible(tester, find.text('Appears to be under 18'));
      verify(() => cubit.selectCategory(ReportCategory.minorSafety)).called(1);
    });

    testResponsive('submitted confirmation', (tester, size, scale) async {
      final cubit = MockReportCubit();
      whenListen(
        cubit,
        const Stream<ReportState>.empty(),
        initialState: const ReportState(
          category: ReportCategory.nudity,
          submitted: true,
          blocked: true,
        ),
      );
      await pumpPage(
        tester,
        BlocProvider<ReportCubit>.value(
          value: cubit,
          child: const ReportPage(name: 'Ananya'),
        ),
        size: size,
        textScale: scale,
      );
      expect(find.text('Thanks for telling us'), findsOneWidget);
      expect(find.text('Ananya is blocked'), findsOneWidget);
    });

    testWidgets('report failure is shown', (tester) async {
      final cubit = MockReportCubit();
      whenListen(
        cubit,
        const Stream<ReportState>.empty(),
        initialState: const ReportState(
          category: ReportCategory.other,
          failure: BusinessRuleFailure(code: 'report_window_closed'),
        ),
      );
      await pumpPage(
        tester,
        BlocProvider<ReportCubit>.value(
          value: cubit,
          child: const ReportPage(name: 'Ananya'),
        ),
      );
      expect(find.textContaining('24 hours'), findsOneWidget);
    });
  });

  group('BlockConfirmPage (V13)', () {
    testResponsive('explains and blocks', (tester, size, scale) async {
      final cubit = MockBlockCubit();
      when(cubit.confirm).thenAnswer((_) async {});
      whenListen(
        cubit,
        const Stream<BlockState>.empty(),
        initialState: const BlockState(),
      );
      await pumpPage(
        tester,
        BlocProvider<BlockCubit>.value(
          value: cubit,
          child: const BlockConfirmPage(name: 'Ananya'),
        ),
        size: size,
        textScale: scale,
      );
      expect(find.text('Block Ananya?'), findsOneWidget);
      await tapVisible(tester, find.text('Block'));
      verify(cubit.confirm).called(1);
    });

    testWidgets('failure is shown', (tester) async {
      final cubit = MockBlockCubit();
      whenListen(
        cubit,
        const Stream<BlockState>.empty(),
        initialState: const BlockState(failure: NetworkFailure()),
      );
      await pumpPage(
        tester,
        BlocProvider<BlockCubit>.value(
          value: cubit,
          child: const BlockConfirmPage(name: 'Ananya'),
        ),
        size: tablet,
      );
      expect(find.textContaining('offline'), findsOneWidget);
    });
  });

  group('BlockedUsersPage (S06)', () {
    testResponsive('list with unblock confirmation', (
      tester,
      size,
      scale,
    ) async {
      final cubit = MockBlockedUsersCubit();
      when(() => cubit.unblock(any())).thenAnswer((_) async {});
      when(cubit.loadMore).thenAnswer((_) async {});
      whenListen(
        cubit,
        const Stream<BlockedUsersState>.empty(),
        initialState: BlockedUsersStateLoaded(Page(items: [blocked])),
      );
      await pumpPage(
        tester,
        BlocProvider<BlockedUsersCubit>.value(
          value: cubit,
          child: const BlockedUsersPage(),
        ),
        size: size,
        textScale: scale,
      );
      expect(find.text('Tara'), findsOneWidget);
      expect(find.text('Blocked 12 Nov'), findsOneWidget);
      await tapVisible(tester, find.text('Unblock'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Unblock'));
      await tester.pumpAndSettle();
      verify(() => cubit.unblock('b1')).called(1);
    });

    testResponsive('empty state', (tester, size, scale) async {
      final cubit = MockBlockedUsersCubit();
      whenListen(
        cubit,
        const Stream<BlockedUsersState>.empty(),
        initialState: const BlockedUsersStateLoaded(
          Page<BlockedUser>(items: []),
        ),
      );
      await pumpPage(
        tester,
        BlocProvider<BlockedUsersCubit>.value(
          value: cubit,
          child: const BlockedUsersPage(),
        ),
        size: size,
        textScale: scale,
      );
      expect(find.text("You haven't blocked anyone"), findsOneWidget);
    });

    testWidgets('error retries', (tester) async {
      final cubit = MockBlockedUsersCubit();
      when(cubit.load).thenAnswer((_) async {});
      whenListen(
        cubit,
        const Stream<BlockedUsersState>.empty(),
        initialState: const BlockedUsersStateFailed(NetworkFailure()),
      );
      await pumpPage(
        tester,
        BlocProvider<BlockedUsersCubit>.value(
          value: cubit,
          child: const BlockedUsersPage(),
        ),
      );
      await tapVisible(tester, find.text('Try again'));
      verify(cubit.load).called(1);
    });
  });

  group('EnforcementPage', () {
    testResponsive('notice with appeal', (tester, size, scale) async {
      final cubit = MockEnforcementCubit();
      whenListen(
        cubit,
        const Stream<EnforcementState>.empty(),
        initialState: EnforcementState(
          status: EnforcementStatus.loaded,
          notices: [notice],
        ),
      );
      await pumpPage(
        tester,
        BlocProvider<EnforcementCubit>.value(
          value: cubit,
          child: const EnforcementPage(),
        ),
        size: size,
        textScale: scale,
      );
      expect(find.text('Warning'), findsOneWidget);
      expect(find.text('Appeal this decision'), findsOneWidget);
    });

    testResponsive('good standing (empty)', (tester, size, scale) async {
      final cubit = MockEnforcementCubit();
      whenListen(
        cubit,
        const Stream<EnforcementState>.empty(),
        initialState: const EnforcementState(status: EnforcementStatus.loaded),
      );
      await pumpPage(
        tester,
        BlocProvider<EnforcementCubit>.value(
          value: cubit,
          child: const EnforcementPage(),
        ),
        size: size,
        textScale: scale,
      );
      expect(find.text('Your account is in good standing'), findsOneWidget);
    });

    testWidgets('error', (tester) async {
      final cubit = MockEnforcementCubit();
      whenListen(
        cubit,
        const Stream<EnforcementState>.empty(),
        initialState: const EnforcementState(
          status: EnforcementStatus.failed,
          failure: NetworkFailure(),
        ),
      );
      await pumpPage(
        tester,
        BlocProvider<EnforcementCubit>.value(
          value: cubit,
          child: const EnforcementPage(),
        ),
      );
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
