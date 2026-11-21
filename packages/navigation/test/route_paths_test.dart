import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('withParams fills and encodes path parameters', () {
    expect(
      RoutePaths.withParams(RoutePaths.call, {'callId': 'a b'}),
      '/calls/a%20b',
    );
  });
}
