import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:feature_video_call/feature_video_call.dart';
import 'package:feature_video_call/src/presentation/gifts/gift_choreography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The approved catalogue (2026-11-27): id, emoji, tier.
const _catalogue = [
  ('rose', '🌹', GiftTier.common),
  ('teddy', '🧸', GiftTier.common),
  ('watch', '⌚', GiftTier.rare),
  ('gold_ring', '💍', GiftTier.rare),
  ('diamond_ring', '💎', GiftTier.epic),
  ('sports_car', '🏎️', GiftTier.epic),
  ('crown', '👑', GiftTier.legendary),
  ('yacht', '🛥️', GiftTier.legendary),
  ('rocket', '🚀', GiftTier.mythic),
  ('castle', '🏰', GiftTier.mythic),
];

GiftEvent _gift(String asset, String emoji, GiftTier tier, {String? id}) =>
    GiftEvent(
      giftTransactionId: 'tx-$asset',
      giftId: id ?? asset,
      giftName: asset,
      emoji: emoji,
      tier: tier,
      diamondValue: 1500,
      senderId: 'u1',
      senderName: 'Asha',
      recipientId: 'h1',
      recipientName: 'Ananya',
      callId: 'c1',
      animationAsset: 'celebration/$asset',
      sentAt: DateTime.utc(2026, 11, 27),
    );

void main() {
  setUpAll(() => DashuriText.useGoogleFonts = false);

  // Phase 5 (2026-11-27): every gift used the same rising-emoji animation,
  // varied only by tier colour and particle count.
  test('every catalogue gift has its own celebration', () {
    final sigs = {
      for (final (asset, emoji, tier) in _catalogue)
        asset: choreographyFor(_gift(asset, emoji, tier)).signature,
    };
    expect(sigs.values.toSet(), hasLength(_catalogue.length), reason: '$sigs');
  });

  test('every celebration stays within the low-end particle budget', () {
    for (final (asset, emoji, tier) in _catalogue) {
      final c = choreographyFor(_gift(asset, emoji, tier));
      expect(
        c.particleCount,
        lessThanOrEqualTo(GiftChoreography.maxParticles),
        reason: asset,
      );
    }
  });

  test('the server animation asset wins; the gift id is the fallback', () {
    // Same gift id, renamed asset → follows the asset.
    final byAsset = choreographyFor(
      _gift('crown', '👑', GiftTier.legendary, id: 'royal_gift'),
    );
    expect(byAsset.hero, HeroMotion.descend);
    // An old event without an asset key falls back to the id.
    final noAsset = GiftEvent(
      giftTransactionId: 'tx',
      giftId: 'rose',
      giftName: 'Rose',
      emoji: '🌹',
      tier: GiftTier.common,
      diamondValue: 1500,
      senderId: 'u1',
      senderName: '',
      recipientId: 'h1',
      recipientName: '',
      callId: 'c1',
      sentAt: DateTime.utc(2026),
    );
    expect(choreographyFor(noAsset).fx.keys, contains(GiftFx.petals));
    // A gift added later in the admin catalogue still celebrates.
    final unknown = choreographyFor(_gift('lantern', '🏮', GiftTier.rare));
    expect(unknown.hero, HeroMotion.pop);
    expect(unknown.particleCount, greaterThan(0));
  });

  test('hero motions start and end where their story says', () {
    expect(heroPose(HeroMotion.drive, 0).offset.dx, lessThan(-1));
    expect(heroPose(HeroMotion.drive, .5).offset.dx, 0);
    expect(heroPose(HeroMotion.drive, 1).offset.dx, greaterThan(1));
    expect(heroPose(HeroMotion.launch, 1).offset.dy, lessThan(-.5));
    expect(heroPose(HeroMotion.descend, 0).offset.dy, lessThan(-.5));
    expect(heroPose(HeroMotion.descend, .9).offset.dy.abs(), lessThan(.1));
    expect(heroPose(HeroMotion.spin, 1).spinX, closeTo(1, .01));
  });

  for (final (asset, emoji, tier) in _catalogue) {
    testWidgets('$asset paints through all five seconds', (t) async {
      t.view.physicalSize = const Size(360, 780);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final c = choreographyFor(_gift(asset, emoji, tier));
      var progress = 0.0;
      late StateSetter set;
      await t.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, s) {
              set = s;
              return CustomPaint(
                size: const Size(360, 420),
                painter: GiftFxPainter(choreo: c, t: progress, seed: 7),
              );
            },
          ),
        ),
      );
      for (var i = 0; i <= 50; i++) {
        set(() => progress = i / 50);
        await t.pump(const Duration(milliseconds: 100));
        expect(t.takeException(), isNull, reason: '$asset at ${i * 2} %');
      }
    });
  }
}
