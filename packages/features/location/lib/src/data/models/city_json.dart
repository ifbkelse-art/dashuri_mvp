import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/city.dart';

/// `City` (MVP contract 2.1): `{id, name, state}`.
City cityFromJson(JsonMap json) => City(
  id: json['id']! as String,
  name: json['name']! as String,
  state: (json['state'] as String?) ?? '',
);

List<City> cityListFromJson(JsonMap json) => (json['items']! as List<Object?>)
    .cast<JsonMap>()
    .map(cityFromJson)
    .toList();
