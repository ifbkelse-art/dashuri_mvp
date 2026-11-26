import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/gift.dart';

/// One visual system for every gift: the tier sets the accent colour and
/// how rich the celebration is (particle count, glow, rings).
Color giftTierColor(GiftTier t) => switch (t) {
  GiftTier.common => DashuriTokens.burgundy300,
  GiftTier.rare => DashuriTokens.gold,
  GiftTier.epic => const Color(0xFF7FB8E6),
  GiftTier.legendary => const Color(0xFFE6B84D),
  GiftTier.mythic => const Color(0xFFC59BFF),
};

/// Particles per tier (bounded for low-end Android).
int giftParticleCount(GiftTier t) => switch (t) {
  GiftTier.common => 8,
  GiftTier.rare => 12,
  GiftTier.epic => 18,
  GiftTier.legendary => 24,
  GiftTier.mythic => 30,
};

bool giftHasGlow(GiftTier t) => t.index >= GiftTier.epic.index;

bool giftHasRings(GiftTier t) => t.index >= GiftTier.legendary.index;
