import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_location/feature_location.dart';
import 'package:feature_location/src/data/datasources/location_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_api.dart';

void main() {
  late FakeApi api;
  setUp(() async => api = await FakeApi.start());
  tearDown(() => api.close());

  test('GET /v1/locations/cities with a query', () async {
    api.response = {
      'items': [
        {'id': 'pune', 'name': 'Pune', 'state': 'Maharashtra'},
      ],
    };
    final r = await LocationRemoteDataSource(api.client).searchCities('pu');
    expect((r as Success<List<City>>).value.single.name, 'Pune');
    expect(api.last.uri.path, '/v1/locations/cities');
    expect(api.last.uri.queryParameters, {'query': 'pu'});
    await LocationRemoteDataSource(api.client).searchCities('');
    expect(api.last.uri.queryParameters, isEmpty);
  });

  test('POST /v1/locations/resolve sends rounded coordinates only', () async {
    api.response = {'id': 'pune', 'name': 'Pune', 'state': 'Maharashtra'};
    await LocationRemoteDataSource(
      api.client,
    ).resolve(CoarseCoordinates(18.520431, 73.856743));
    expect(api.last.body, {'latitude': 18.52, 'longitude': 73.86});
  });

  test('404 no_supported_city_nearby is a NotFoundFailure', () async {
    api
      ..status = 404
      ..response = {'code': 'no_supported_city_nearby'};
    final r = await LocationRemoteDataSource(
      api.client,
    ).resolve(CoarseCoordinates(10, 10));
    expect((r as Err).failure, isA<NotFoundFailure>());
  });

  test('PATCH /v1/me/profile with city_id', () async {
    api.response = {};
    final r = await LocationRemoteDataSource(api.client).saveMyCity('pune');
    expect(r.isSuccess, isTrue);
    expect(api.last.method, 'PATCH');
    expect(api.last.body, {'city_id': 'pune'});
  });
}
