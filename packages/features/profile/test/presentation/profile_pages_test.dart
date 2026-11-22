import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_profile/feature_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';
import '../helpers/pump.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Gender.man);
    registerFallbackValue(ExperienceMode.customer);
  });

  group('MyProfilePage (S01)', () {
    testResponsive('loaded: identity, level, diamonds and menu', (
      tester,
      size,
      scale,
    ) async {
      final cubit = MockMyProfileCubit();
      whenListen(
        cubit,
        const Stream<MyProfileState>.empty(),
        initialState: const MyProfileStateLoaded(
          profile,
          level: level,
          availableDiamonds: 12480,
        ),
      );
      await pumpPage(
        tester,
        BlocProvider<MyProfileCubit>.value(
          value: cubit,
          child: const MyProfilePage(),
        ),
        size: size,
        textScale: scale,
      );
      expect(find.text('Arjun'), findsOneWidget);
      expect(find.text('Pune'), findsOneWidget);
      expect(find.text('68% to Level 3'), findsOneWidget);
      expect(find.textContaining(amount('12,480')), findsOneWidget);
      expect(find.text('Become a host'), findsOneWidget);
      await tapVisible(tester, find.text('Buy'));
      await tester.pumpAndSettle();
      expect(find.text('Navigated to /wallet/buy'), findsOneWidget);
    });

    testWidgets('approved host sees the host mode switch', (tester) async {
      final cubit = MockMyProfileCubit();
      when(() => cubit.setMode(any())).thenAnswer((_) async {});
      whenListen(
        cubit,
        const Stream<MyProfileState>.empty(),
        initialState: const MyProfileStateLoaded(
          profile,
          hostModeAvailable: true,
        ),
      );
      await pumpPage(
        tester,
        BlocProvider<MyProfileCubit>.value(
          value: cubit,
          child: const MyProfilePage(),
        ),
      );
      expect(find.text('Host mode'), findsOneWidget);
      await tapVisible(tester, find.byType(Switch));
      verify(() => cubit.setMode(ExperienceMode.host)).called(1);
    });

    testResponsive('error state retries', (tester, size, scale) async {
      final cubit = MockMyProfileCubit();
      when(cubit.load).thenAnswer((_) async {});
      whenListen(
        cubit,
        const Stream<MyProfileState>.empty(),
        initialState: const MyProfileStateFailed(NetworkFailure()),
      );
      await pumpPage(
        tester,
        BlocProvider<MyProfileCubit>.value(
          value: cubit,
          child: const MyProfilePage(),
        ),
        size: size,
        textScale: scale,
      );
      await tapVisible(tester, find.text('Try again'));
      verify(cubit.load).called(1);
    });
  });

  group('EditProfilePage (S02)', () {
    EditProfileState ready({String? rejected}) => EditProfileState(
      status: EditProfileStatus.ready,
      original: profile,
      name: 'Arjun',
      bio: 'Hello',
      languages: const ['hi', 'en'],
      gender: Gender.man,
      city: profile.city,
      rejectedField: rejected,
      saveFailure: rejected == null
          ? null
          : const BusinessRuleFailure(code: 'profile_text_rejected'),
    );

    testResponsive('form shows fields, languages, private gender and city', (
      tester,
      size,
      scale,
    ) async {
      final cubit = MockEditProfileCubit();
      whenListen(
        cubit,
        Stream.value(ready()),
        initialState: const EditProfileState(),
      );
      await pumpPage(
        tester,
        BlocProvider<EditProfileCubit>.value(
          value: cubit,
          child: const EditProfilePage(),
        ),
        size: size,
        textScale: scale,
      );
      await tester.pump();
      expect(find.text('Display name'), findsOneWidget);
      expect(find.text('Hindi'), findsOneWidget);
      expect(find.text('Gender · private'), findsOneWidget);
      expect(find.text('Pune'), findsOneWidget);
      expect(
        find.textContaining('Photo upload is not available'),
        findsOneWidget,
      );
    });

    testWidgets('contact-detail rejection is shown inline', (tester) async {
      final cubit = MockEditProfileCubit();
      whenListen(
        cubit,
        const Stream<EditProfileState>.empty(),
        initialState: ready(rejected: 'display_name'),
      );
      await pumpPage(
        tester,
        BlocProvider<EditProfileCubit>.value(
          value: cubit,
          child: const EditProfilePage(),
        ),
      );
      expect(find.text(profileTextRejectedMessage), findsOneWidget);
    });

    testWidgets('load failure offers retry', (tester) async {
      final cubit = MockEditProfileCubit();
      when(cubit.load).thenAnswer((_) async {});
      whenListen(
        cubit,
        const Stream<EditProfileState>.empty(),
        initialState: const EditProfileState(
          status: EditProfileStatus.failed,
          loadFailure: NetworkFailure(),
        ),
      );
      await pumpPage(
        tester,
        BlocProvider<EditProfileCubit>.value(
          value: cubit,
          child: const EditProfilePage(),
        ),
        size: tablet,
      );
      await tapVisible(tester, find.text('Try again'));
      verify(cubit.load).called(1);
    });
  });

  group('CreateProfilePage (A08/A11)', () {
    testResponsive('name and gender options', (tester, size, scale) async {
      final cubit = MockCreateProfileCubit();
      whenListen(
        cubit,
        const Stream<CreateProfileState>.empty(),
        initialState: const CreateProfileState(),
      );
      await pumpPage(
        tester,
        BlocProvider<CreateProfileCubit>.value(
          value: cubit,
          child: const CreateProfilePage(),
        ),
        size: size,
        textScale: scale,
      );
      expect(find.text('How should we call you?'), findsOneWidget);
      for (final g in Gender.values) {
        expect(find.text(g.label), findsOneWidget);
      }
      await tapVisible(tester, find.text('Woman'));
      verify(() => cubit.genderSelected(Gender.woman)).called(1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });

    testWidgets('rejected name is shown inline', (tester) async {
      final cubit = MockCreateProfileCubit();
      whenListen(
        cubit,
        const Stream<CreateProfileState>.empty(),
        initialState: const CreateProfileState(
          name: 'x@y.z',
          gender: Gender.man,
          nameRejected: true,
          failure: BusinessRuleFailure(code: 'profile_text_rejected'),
        ),
      );
      await pumpPage(
        tester,
        BlocProvider<CreateProfileCubit>.value(
          value: cubit,
          child: const CreateProfilePage(),
        ),
      );
      expect(find.text(profileTextRejectedMessage), findsOneWidget);
    });
  });
}

/// A CurrencyAmount's text: the amount, after its inline glyph (UI/UX pass:
/// the glyph is now an inline span so the amount can wrap).
RegExp amount(String text) => RegExp('^\uFFFC?${RegExp.escape(text)}\$');
