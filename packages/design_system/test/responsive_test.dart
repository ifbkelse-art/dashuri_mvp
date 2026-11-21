import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() => DashuriText.useGoogleFonts = false);

  test('window size classes follow Material 3 breakpoints', () {
    expect(WindowSize.fromWidth(390), WindowSize.compact);
    expect(WindowSize.fromWidth(599), WindowSize.compact);
    expect(WindowSize.fromWidth(600), WindowSize.medium);
    expect(WindowSize.fromWidth(839), WindowSize.medium);
    expect(WindowSize.fromWidth(840), WindowSize.expanded);
  });

  test('Indian number and rupee formatting', () {
    expect(DashuriFormat.count(999), '999');
    expect(DashuriFormat.count(12480), '12,480');
    expect(DashuriFormat.count(1234567), '12,34,567');
    expect(DashuriFormat.rupees(119900), '₹1,199');
    expect(DashuriFormat.rupees(101610), '₹1,016.10');
    expect(DashuriFormat.duration(65), '1:05');
    expect(DashuriFormat.duration(3723), '1:02:03');
  });

  Future<void> pumpShell(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: AdaptiveShell(
          selectedIndex: 0,
          onSelected: (_) {},
          destinations: const [
            ShellDestination(
              icon: Icons.explore_outlined,
              selectedIcon: Icons.explore,
              label: 'Discover',
            ),
            ShellDestination(
              icon: Icons.chat_bubble_outline,
              selectedIcon: Icons.chat_bubble,
              label: 'Chats',
              badgeCount: 3,
            ),
          ],
          body: const Text('body'),
        ),
      ),
    );
  }

  testWidgets('shell uses a bottom bar on phones', (tester) async {
    await pumpShell(tester, const Size(390, 844));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('shell uses a rail on tablets', (tester) async {
    await pumpShell(tester, const Size(1024, 768));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
