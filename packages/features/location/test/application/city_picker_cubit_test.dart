import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_location/feature_location.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';

void main() {
  late MockSearchCities search;
  late MockDetectMyCity detect;
  late MockSaveMyCity save;
  late MockOpenLocationSettings open;

  setUpAll(() => registerFallbackValue(const NoInput()));
  setUp(() {
    search = MockSearchCities();
    detect = MockDetectMyCity();
    save = MockSaveMyCity();
    open = MockOpenLocationSettings();
    when(
      () => search(any()),
    ).thenAnswer((_) async => const Success([pune, mumbai]));
    when(() => save(any())).thenAnswer((_) async => const Success<void>(null));
  });

  CityPickerCubit build() => CityPickerCubit(
    search,
    detect,
    save,
    open,
    debounce: const Duration(milliseconds: 10),
  );

  blocTest<CityPickerCubit, CityPickerState>(
    'load lists cities',
    build: build,
    act: (c) => c.load(),
    expect: () => const [
      CityPickerState(),
      CityPickerState(
        listStatus: CityListStatus.loaded,
        cities: [pune, mumbai],
      ),
    ],
  );

  blocTest<CityPickerCubit, CityPickerState>(
    'typing is debounced into one search',
    build: build,
    act: (c) {
      c
        ..queryChanged('p')
        ..queryChanged('pu');
    },
    wait: const Duration(milliseconds: 50),
    verify: (_) {
      verify(() => search('pu')).called(1);
      verifyNever(() => search('p'));
    },
  );

  blocTest<CityPickerCubit, CityPickerState>(
    'use my location saves the resolved city',
    setUp: () =>
        when(() => detect(any())).thenAnswer((_) async => const Success(pune)),
    build: build,
    seed: () => const CityPickerState(listStatus: CityListStatus.loaded),
    act: (c) => c.useMyLocation(),
    expect: () => const [
      CityPickerState(listStatus: CityListStatus.loaded, locating: true),
      CityPickerState(listStatus: CityListStatus.loaded, detected: pune),
      CityPickerState(
        listStatus: CityListStatus.loaded,
        detected: pune,
        saving: pune,
      ),
      CityPickerState(
        listStatus: CityListStatus.loaded,
        detected: pune,
        saved: pune,
      ),
    ],
    verify: (_) => verify(() => save('pune')).called(1),
  );

  blocTest<CityPickerCubit, CityPickerState>(
    'permission denied is reported and nothing is saved',
    setUp: () => when(() => detect(any())).thenAnswer(
      (_) async => const Err(
        PlatformFailure(code: 'location_permission_permanently_denied'),
      ),
    ),
    build: build,
    seed: () => const CityPickerState(listStatus: CityListStatus.loaded),
    act: (c) => c.useMyLocation(),
    skip: 1,
    expect: () => const [
      CityPickerState(
        listStatus: CityListStatus.loaded,
        detectFailure: PlatformFailure(
          code: 'location_permission_permanently_denied',
        ),
      ),
    ],
    verify: (_) => verifyNever(() => save(any())),
  );

  blocTest<CityPickerCubit, CityPickerState>(
    'save failure is surfaced',
    setUp: () => when(
      () => save(any()),
    ).thenAnswer((_) async => const Err(NetworkFailure())),
    build: build,
    seed: () => const CityPickerState(listStatus: CityListStatus.loaded),
    act: (c) => c.select(mumbai),
    expect: () => const [
      CityPickerState(listStatus: CityListStatus.loaded, saving: mumbai),
      CityPickerState(
        listStatus: CityListStatus.loaded,
        saveFailure: NetworkFailure(),
      ),
    ],
  );

  blocTest<CityPickerCubit, CityPickerState>(
    'search failure',
    setUp: () => when(
      () => search(any()),
    ).thenAnswer((_) async => const Err(NetworkFailure())),
    build: build,
    act: (c) => c.load(),
    expect: () => const [
      CityPickerState(),
      CityPickerState(
        listStatus: CityListStatus.failed,
        listFailure: NetworkFailure(),
      ),
    ],
  );
}
