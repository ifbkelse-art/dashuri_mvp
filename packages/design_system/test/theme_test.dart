import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('themes are Material 3 with matching brightness', () {
    expect(DashuriTheme.light().useMaterial3, isTrue);
    expect(DashuriTheme.dark().colorScheme.brightness.name, 'dark');
  });
}
