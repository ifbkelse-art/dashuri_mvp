import 'package:feature_discovery/feature_discovery.dart';
import 'package:feature_discovery/src/data/models/host_card_json.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = <String, Object?>{
    'user_id': 'u1',
    'display_name': 'Ananya',
    'photo_url': null,
    'languages': ['hi', 'en'],
    'level': 3,
    'rate_per_minute': 2400,
    'availability': 'available',
  };

  test('parses the v1 HostCard', () {
    final h = hostCardFromJson(base);
    expect(h.status, HostAvailability.available);
    expect(h.city, isNull);
    expect(h.isVerified, isFalse);
  });

  test('parses contract 2.3 additions and host detail', () {
    final p = hostProfileFromJson({
      ...base,
      'availability': 'offline',
      'city': {'id': 'pune', 'name': 'Pune', 'state': 'Maharashtra'},
      'age': 24,
      'is_verified': true,
      'bio': 'Chai over coffee',
      'photo_urls': ['a', 'b'],
    });
    expect(p.card.status, HostAvailability.offline);
    expect(
      p.card.city,
      const City(id: 'pune', name: 'Pune', state: 'Maharashtra'),
    );
    expect(p.card.age, 24);
    expect(p.bio, 'Chai over coffee');
    expect(p.gallery, ['a', 'b']);
  });

  test('unknown availability is treated as offline', () {
    expect(HostAvailability.parse('away'), HostAvailability.offline);
  });

  test('filter query', () {
    expect(const DiscoveryFilter().toQuery(), {'sort': 'recommended'});
    expect(
      const DiscoveryFilter(
        language: 'ta',
        city: City(id: 'pune', name: 'Pune'),
        sort: DiscoverySort.rateHigh,
      ).toQuery(),
      {'language': 'ta', 'city_id': 'pune', 'sort': 'rate_high'},
    );
  });

  group('cityFromPickerResult', () {
    test('accepts a map', () {
      expect(
        cityFromPickerResult({'id': 'pune', 'name': 'Pune'}),
        const City(id: 'pune', name: 'Pune'),
      );
    });

    test('accepts an object with id and name', () {
      expect(
        cityFromPickerResult(_PickerCity()),
        const City(id: 'delhi', name: 'Delhi'),
      );
    });

    test('rejects anything else', () {
      expect(cityFromPickerResult(null), isNull);
      expect(cityFromPickerResult(42), isNull);
      expect(cityFromPickerResult({'id': 1}), isNull);
    });
  });
}

class _PickerCity {
  String get id => 'delhi';
  String get name => 'Delhi';
}
