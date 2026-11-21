import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('call route takes a callId parameter', () {
    expect(
      RoutePaths.withParams(RoutePaths.call, {'callId': 'c1'}),
      '/calls/c1',
    );
  });
}
