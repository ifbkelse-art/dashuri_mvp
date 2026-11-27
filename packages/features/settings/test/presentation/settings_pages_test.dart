import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';
import '../helpers/pump.dart';

void main() {
  setUpAll(() => registerFallbackValue(WhoCanMessage.everyone));

  group('SettingsPage (S03)', () {
    // Phase 9 accessibility.
    testWidgets('meets tap-target and label guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      final cubit = MockSettingsCubit();
      whenListen(
        cubit,
        const Stream<SettingsState>.empty(),
        initialState: const SettingsState(
          whoCanMessage: WhoCanMessage.everyone,
        ),
      );
      await pumpPage(
        tester,
        BlocProvider<SettingsCubit>.value(
          value: cubit,
          child: const SettingsPage(),
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testResponsive('groups and danger zone', (tester, size, scale) async {
      final cubit = MockSettingsCubit();
      when(cubit.signOut).thenAnswer((_) async {});
      whenListen(
        cubit,
        const Stream<SettingsState>.empty(),
        initialState: const SettingsState(
          whoCanMessage: WhoCanMessage.everyone,
        ),
      );
      await pumpPage(
        tester,
        BlocProvider<SettingsCubit>.value(
          value: cubit,
          child: const SettingsPage(),
        ),
        size: size,
        textScale: scale,
      );
      expect(find.text('Who can message me'), findsOneWidget);
      expect(find.text('Everyone'), findsOneWidget);
      expect(find.text('Become a host'), findsOneWidget);
      expect(find.text('Delete account'), findsOneWidget);
      await tapVisible(tester, find.text('Log out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
      await tester.pumpAndSettle();
      verify(cubit.signOut).called(1);
    });

    testWidgets('data export confirmation and failure snackbars', (
      tester,
    ) async {
      final cubit = MockSettingsCubit();
      whenListen(
        cubit,
        Stream.fromIterable(const [
          SettingsState(
            export: DataExportRequest(requestId: 'x', status: 'queued'),
          ),
        ]),
        initialState: const SettingsState(),
      );
      await pumpPage(
        tester,
        BlocProvider<SettingsCubit>.value(
          value: cubit,
          child: const SettingsPage(),
        ),
      );
      await tester.pump();
      expect(find.textContaining("We're preparing a copy"), findsOneWidget);
    });
  });

  group('PrivacyPage (S04)', () {
    testResponsive('two choices', (tester, size, scale) async {
      final cubit = MockPrivacyCubit();
      when(() => cubit.select(any())).thenAnswer((_) async {});
      whenListen(
        cubit,
        const Stream<PrivacyState>.empty(),
        initialState: const PrivacyState(
          status: PrivacyStatus.ready,
          value: WhoCanMessage.everyone,
        ),
      );
      await pumpPage(
        tester,
        BlocProvider<PrivacyCubit>.value(
          value: cubit,
          child: const PrivacyPage(),
        ),
        size: size,
        textScale: scale,
      );
      await tapVisible(tester, find.text("People I've called"));
      verify(() => cubit.select(WhoCanMessage.pastCallPartners)).called(1);
    });

    testWidgets('error retries', (tester) async {
      final cubit = MockPrivacyCubit();
      when(cubit.load).thenAnswer((_) async {});
      whenListen(
        cubit,
        const Stream<PrivacyState>.empty(),
        initialState: const PrivacyState(
          status: PrivacyStatus.failed,
          failure: NetworkFailure(),
        ),
      );
      await pumpPage(
        tester,
        BlocProvider<PrivacyCubit>.value(
          value: cubit,
          child: const PrivacyPage(),
        ),
        size: tablet,
      );
      await tapVisible(tester, find.text('Try again'));
      verify(cubit.load).called(1);
    });
  });

  group('NotificationSettingsPage (S05)', () {
    testResponsive('consent switches', (tester, size, scale) async {
      final cubit = MockConsentsCubit();
      when(() => cubit.setMarketing(any())).thenAnswer((_) async {});
      whenListen(
        cubit,
        const Stream<ConsentsState>.empty(),
        initialState: ConsentsState(data: consents),
      );
      await pumpPage(
        tester,
        BlocProvider<ConsentsCubit>.value(
          value: cubit,
          child: const NotificationSettingsPage(),
        ),
        size: size,
        textScale: scale,
      );
      expect(find.text('Safety & account'), findsOneWidget);
      await tapVisible(tester, find.text('Offers and reminders'));
      verify(() => cubit.setMarketing(false)).called(1);
    });

    testWidgets('error', (tester) async {
      final cubit = MockConsentsCubit();
      whenListen(
        cubit,
        const Stream<ConsentsState>.empty(),
        initialState: const ConsentsState(failure: NetworkFailure()),
      );
      await pumpPage(
        tester,
        BlocProvider<ConsentsCubit>.value(
          value: cubit,
          child: const NotificationSettingsPage(),
        ),
      );
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('HelpSupportPage (S07)', () {
    testResponsive('email and grievance form', (tester, size, scale) async {
      final cubit = MockGrievanceCubit();
      whenListen(
        cubit,
        const Stream<GrievanceState>.empty(),
        initialState: const GrievanceState(),
      );
      await pumpPage(
        tester,
        BlocProvider<GrievanceCubit>.value(
          value: cubit,
          child: const HelpSupportPage(supportEmail: 'help@example.test'),
        ),
        size: size,
        textScale: scale,
      );
      expect(find.text('Safety Centre'), findsOneWidget);
      expect(find.text('help@example.test'), findsOneWidget);
      expect(find.text('Raise a complaint or grievance'), findsOneWidget);
    });

    testWidgets('unconfigured email and submitted grievance', (tester) async {
      final cubit = MockGrievanceCubit();
      whenListen(
        cubit,
        const Stream<GrievanceState>.empty(),
        initialState: const GrievanceState(submitted: true, referenceId: 'r1'),
      );
      await pumpPage(
        tester,
        BlocProvider<GrievanceCubit>.value(
          value: cubit,
          child: const HelpSupportPage(supportEmail: ''),
        ),
      );
      expect(find.textContaining('not configured'), findsOneWidget);
      expect(find.textContaining('Reference: r1'), findsOneWidget);
    });
  });

  group('LegalPage (S08)', () {
    testResponsive('list marked as draft', (tester, size, scale) async {
      await pumpPage(tester, const LegalPage(), size: size, textScale: scale);
      expect(
        find.textContaining('Draft — pending legal review'),
        findsOneWidget,
      );
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Grievance Officer'), findsOneWidget);
    });

    testResponsive('document view', (tester, size, scale) async {
      await pumpPage(
        tester,
        const LegalPage(docId: 'privacy'),
        size: size,
        textScale: scale,
      );
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(
        find.textContaining('Draft — pending legal review'),
        findsOneWidget,
      );
      expect(find.text('Location'), findsOneWidget);
    });
  });

  group('DeleteAccountPage (S09/S10)', () {
    testResponsive('consequences, forfeiture and double confirmation', (
      tester,
      size,
      scale,
    ) async {
      final cubit = MockDeleteAccountCubit();
      when(cubit.delete).thenAnswer((_) async {});
      whenListen(
        cubit,
        const Stream<DeleteAccountState>.empty(),
        initialState: const DeleteAccountState(
          balanceLoaded: true,
          diamonds: 12480,
          acknowledged: true,
        ),
      );
      await pumpPage(
        tester,
        BlocProvider<DeleteAccountCubit>.value(
          value: cubit,
          child: const DeleteAccountPage(),
        ),
        size: size,
        textScale: scale,
      );
      expect(find.textContaining('12,480 Diamonds'), findsOneWidget);
      await tapVisible(tester, find.text('Continue to delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete your account?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
      await tester.pumpAndSettle();
      verify(cubit.delete).called(1);
    });

    testWidgets('pending balance explains why deletion is refused', (
      tester,
    ) async {
      final cubit = MockDeleteAccountCubit();
      whenListen(
        cubit,
        const Stream<DeleteAccountState>.empty(),
        initialState: const DeleteAccountState(
          balanceLoaded: true,
          diamonds: 0,
          failure: BusinessRuleFailure(code: 'pending_balance_or_payout'),
        ),
      );
      await pumpPage(
        tester,
        BlocProvider<DeleteAccountCubit>.value(
          value: cubit,
          child: const DeleteAccountPage(),
        ),
      );
      expect(find.textContaining('Beans on hold'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });

    testWidgets('scheduled state', (tester) async {
      final cubit = MockDeleteAccountCubit();
      whenListen(
        cubit,
        const Stream<DeleteAccountState>.empty(),
        initialState: DeleteAccountState(
          request: DeletionRequest(
            requestId: 'd',
            status: 'scheduled',
            scheduledFor: DateTime(2026, 11, 28, 12),
          ),
        ),
      );
      await pumpPage(
        tester,
        BlocProvider<DeleteAccountCubit>.value(
          value: cubit,
          child: const DeleteAccountPage(),
        ),
        size: tablet,
      );
      expect(find.text('Account deletion scheduled'), findsOneWidget);
      expect(find.textContaining('28 November 2026'), findsOneWidget);
    });
  });
}
