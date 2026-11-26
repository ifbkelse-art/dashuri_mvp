// Arrival photos in discovery (2026-11-26): an honest "Captured N minutes
// ago" label, never "live", and a way to report the photo.

import 'package:bloc_test/bloc_test.dart';
import 'package:feature_discovery/feature_discovery.dart';
import 'package:feature_discovery/src/data/models/host_card_json.dart';
import 'package:feature_discovery/src/presentation/widgets/discovery_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

class _Profile extends MockCubit<HostProfileState>
    implements HostProfileCubit {}

HostCard _withPhoto({String availability = 'available'}) {
  final h = host('a', availability: availability);
  return HostCard(
    userId: h.userId,
    displayName: h.displayName,
    photoUrl: null,
    languages: h.languages,
    level: h.level,
    ratePerMinute: h.ratePerMinute,
    availability: availability,
    arrivalPhoto: HostArrivalPhoto(
      id: 'p1',
      url: 'https://storage.test/sign/host-arrival-photos/a/p1.jpg?token=t',
      capturedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 3)),
    ),
  );
}

void main() {
  test('JSON: arrival_photo maps; missing or malformed is null', () {
    final base = {
      'user_id': 'a',
      'display_name': 'A',
      'languages': <Object?>[],
      'level': 1,
      'rate_per_minute': 500,
      'availability': 'available',
    };
    final card = hostCardFromJson({
      ...base,
      'arrival_photo': {
        'photo_id': 'p9',
        'url': 'https://x/p9.jpg',
        'captured_at': '2026-11-26T10:00:00Z',
      },
    });
    expect(card.arrivalPhoto?.photoId, 'p9');
    expect(card.arrivalPhoto?.capturedAt, DateTime.utc(2026, 11, 26, 10));
    expect(
      hostCardFromJson({...base, 'arrival_photo': null}).arrivalPhoto,
      isNull,
    );
    expect(
      hostCardFromJson({
        ...base,
        'arrival_photo': {'url': 1},
      }).arrivalPhoto,
      isNull,
    );
  });

  test('capture age wording', () {
    final now = DateTime.utc(2026, 11, 26, 12);
    expect(
      arrivalCapturedAgo(now.subtract(const Duration(seconds: 20)), now),
      'Captured just now',
    );
    expect(
      arrivalCapturedAgo(now.subtract(const Duration(minutes: 1)), now),
      'Captured 1 minute ago',
    );
    expect(
      arrivalCapturedAgo(now.subtract(const Duration(minutes: 3)), now),
      'Captured 3 minutes ago',
    );
    expect(
      arrivalCapturedAgo(now.subtract(const Duration(hours: 2)), now),
      'Captured 2 hours ago',
    );
  });

  testWidgets('grid card shows the photo age, never "live"', (t) async {
    await pumpPage(
      t,
      Scaffold(
        body: SizedBox(
          width: 180,
          height: 260,
          child: HostGridCard(host: _withPhoto(), onTap: () {}),
        ),
      ),
    );
    expect(find.text('3 min ago'), findsOneWidget);
    expect(
      find.textContaining(RegExp('live', caseSensitive: false)),
      findsNothing,
    );
    expect(find.bySemanticsLabel(RegExp('has a recent photo')), findsOneWidget);
  });

  testWidgets('profile: recent photo with timestamp and a report link', (
    t,
  ) async {
    final c = _Profile();
    when(() => c.state).thenReturn(
      HostProfileLoaded((
        profile: HostProfile(card: _withPhoto(), bio: null),
        balance: 1000,
        approxPaisePerDiamondMilli: null,
      )),
    );
    when(() => c.load(any())).thenAnswer((_) async {});
    await pumpPage(
      t,
      BlocProvider<HostProfileCubit>.value(
        value: c,
        child: const HostProfilePage(userId: 'a'),
      ),
    );
    await t.scrollUntilVisible(
      find.text('Report photo'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Recent photo'), findsOneWidget);
    expect(find.text('Captured 3 minutes ago'), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'\blive\b', caseSensitive: false)),
      findsNothing,
    );
    expect(find.textContaining('Verified identity'), findsNothing);
    await t.tap(find.text('Report photo'));
    await t.pumpAndSettle();
    expect(find.textContaining('arrivalPhotoId=p1'), findsOneWidget);
  });

  testWidgets('offline host: no arrival photo on the profile', (t) async {
    final c = _Profile();
    when(() => c.state).thenReturn(
      HostProfileLoaded((
        profile: HostProfile(
          card: _withPhoto(availability: 'offline'),
          bio: null,
        ),
        balance: 1000,
        approxPaisePerDiamondMilli: null,
      )),
    );
    when(() => c.load(any())).thenAnswer((_) async {});
    await pumpPage(
      t,
      BlocProvider<HostProfileCubit>.value(
        value: c,
        child: const HostProfilePage(userId: 'a'),
      ),
    );
    expect(find.text('Recent photo'), findsNothing);
  });
}
