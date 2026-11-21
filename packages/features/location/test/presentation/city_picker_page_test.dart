import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_location/feature_location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';
import '../helpers/pump.dart';

void main() {
  setUpAll(() => registerFallbackValue(pune));

  Future<void> pump(
    WidgetTester t,
    CityPickerState s,
    Size size,
    double scale,
  ) async {
    final cubit = MockCityPickerCubit();
    when(() => cubit.select(any())).thenAnswer((_) async {});
    when(cubit.useMyLocation).thenAnswer((_) async {});
    whenListen(cubit, const Stream<CityPickerState>.empty(), initialState: s);
    await pumpPage(
      t,
      BlocProvider<CityPickerCubit>.value(
        value: cubit,
        child: const CityPickerPage(),
      ),
      size: size,
      textScale: scale,
    );
  }

  testResponsive('lists cities with search and use my location', (
    tester,
    size,
    scale,
  ) async {
    await pump(
      tester,
      const CityPickerState(
        listStatus: CityListStatus.loaded,
        cities: [pune, mumbai],
      ),
      size,
      scale,
    );
    expect(find.text('Use my location'), findsOneWidget);
    expect(find.text('Pune'), findsOneWidget);
    expect(find.text('Mumbai'), findsOneWidget);
    expect(
      find.textContaining('never store your exact location'),
      findsOneWidget,
    );
  });

  testResponsive('permission denied shows Open settings', (
    tester,
    size,
    scale,
  ) async {
    await pump(
      tester,
      const CityPickerState(
        listStatus: CityListStatus.loaded,
        detectFailure: PlatformFailure(
          code: 'location_permission_permanently_denied',
        ),
      ),
      size,
      scale,
    );
    expect(find.textContaining('Location access is off'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
  });

  testWidgets('no nearby city', (tester) async {
    await pump(
      tester,
      const CityPickerState(
        listStatus: CityListStatus.loaded,
        detectFailure: NotFoundFailure(),
      ),
      phone,
      1,
    );
    expect(find.textContaining("isn't available near you"), findsOneWidget);
  });

  testWidgets('empty search results', (tester) async {
    await pump(
      tester,
      const CityPickerState(listStatus: CityListStatus.loaded, query: 'zz'),
      tablet,
      1,
    );
    expect(find.text('No matching cities'), findsOneWidget);
  });

  testWidgets('list error retries', (tester) async {
    await pump(
      tester,
      const CityPickerState(
        listStatus: CityListStatus.failed,
        listFailure: NetworkFailure(),
      ),
      phone,
      1,
    );
    expect(find.text('Try again'), findsOneWidget);
  });
}
