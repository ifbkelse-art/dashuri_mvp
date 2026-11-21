import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_location/feature_location.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';

void main() {
  test('coordinates are rounded to 2 decimals', () {
    final c = CoarseCoordinates(18.520431, 73.856743);
    expect(c.latitude, 18.52);
    expect(c.longitude, 73.86);
    expect(CoarseCoordinates(-0.005, 0.004).longitude, 0);
  });

  group('DetectMyCity', () {
    late MockLocationRepository repo;
    setUp(() {
      repo = MockLocationRepository();
      registerFallbackValue(CoarseCoordinates(0, 0));
    });

    test('resolves the rounded position', () async {
      when(
        repo.currentCoarsePosition,
      ).thenAnswer((_) async => Success(CoarseCoordinates(18.5204, 73.8567)));
      when(
        () => repo.resolveCity(any()),
      ).thenAnswer((_) async => const Success(pune));
      final r = await DetectMyCity(repo)(const NoInput());
      expect((r as Success<City>).value, pune);
      verify(() => repo.resolveCity(CoarseCoordinates(18.52, 73.86))).called(1);
    });

    test('a permission failure never reaches the server', () async {
      when(repo.currentCoarsePosition).thenAnswer(
        (_) async =>
            const Err(PlatformFailure(code: 'location_permission_denied')),
      );
      final r = await DetectMyCity(repo)(const NoInput());
      expect((r as Err).failure.code, 'location_permission_denied');
      verifyNever(() => repo.resolveCity(any()));
    });
  });
}
