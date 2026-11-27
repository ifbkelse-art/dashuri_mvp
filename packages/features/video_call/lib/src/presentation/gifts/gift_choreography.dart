import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/entities/gift.dart';
import 'gift_visuals.dart';

/// How the gift's hero (its emoji, large) moves during the celebration.
enum HeroMotion {
  /// Elastic pop, then a gentle float.
  pop,

  /// Drops in and bounces (soft, toy-like).
  bounce,

  /// Spins in on its vertical axis, catching the light.
  spin,

  /// Drives in from the left, pauses, drives out to the right.
  drive,

  /// Descends from above and settles.
  descend,

  /// Bobs on the waves.
  bob,

  /// Launches from the bottom to the top.
  launch,
}

/// Effect layers, all drawn by one painter with plain shapes (no images).
enum GiftFx {
  petals,
  hearts,
  sparkles,
  rays,
  goldDust,
  confetti,
  speedLines,
  waves,
  exhaust,
  fireworks,
  sweep,
}

/// A gift's celebration: hero motion, effect layers (with counts) and the
/// glow colour. Counts stay small: the whole celebration is bounded by
/// [maxParticles] so low-end Android phones keep the call smooth.
final class GiftChoreography {
  const GiftChoreography({
    required this.hero,
    required this.fx,
    required this.glow,
    required this.palette,
  });

  final HeroMotion hero;
  final Map<GiftFx, int> fx;
  final Color glow;
  final List<Color> palette;

  static const maxParticles = 40;

  int get particleCount => fx.values.fold(0, (a, b) => a + b);

  /// A comparable fingerprint (tests use it to prove gifts look different).
  String get signature =>
      '${hero.name}|${(fx.keys.map((k) => k.name).toList()..sort()).join(',')}';
}

const _gold = Color(0xFFE6B84D);
const _ice = Color(0xFFBFE6FF);

/// Per-gift choreography, keyed by the server's `animation_asset`
/// (`celebration/<name>`), then by gift id. Unknown gifts (added later in the
/// admin catalogue) get a tier-based default, so a new gift always works.
GiftChoreography choreographyFor(GiftEvent g) {
  final key = g.animationAsset.startsWith('celebration/')
      ? g.animationAsset.substring('celebration/'.length)
      : g.giftId;
  return switch (key) {
    'rose' => const GiftChoreography(
      hero: HeroMotion.pop,
      fx: {GiftFx.petals: 16, GiftFx.sparkles: 10},
      glow: Color(0xFFE0475B),
      palette: [Color(0xFFD7263D), Color(0xFFF46A7A), Color(0xFFB0102A)],
    ),
    'teddy' => const GiftChoreography(
      hero: HeroMotion.bounce,
      fx: {GiftFx.hearts: 16, GiftFx.sparkles: 6},
      glow: Color(0xFFF6A5C0),
      palette: [Color(0xFFFF6B9A), Color(0xFFFFA3C1), Color(0xFFFF3D7F)],
    ),
    'watch' => const GiftChoreography(
      hero: HeroMotion.pop,
      fx: {GiftFx.sweep: 1, GiftFx.sparkles: 12},
      glow: _gold,
      palette: [_gold, Color(0xFFFFF1C2)],
    ),
    'gold_ring' => const GiftChoreography(
      hero: HeroMotion.spin,
      fx: {GiftFx.goldDust: 20, GiftFx.sparkles: 10},
      glow: _gold,
      palette: [_gold, Color(0xFFFFD86B), Color(0xFFFFF1C2)],
    ),
    'diamond_ring' => const GiftChoreography(
      hero: HeroMotion.spin,
      fx: {GiftFx.rays: 1, GiftFx.sparkles: 18},
      glow: _ice,
      palette: [Colors.white, _ice, Color(0xFF9AD4FF)],
    ),
    'sports_car' => const GiftChoreography(
      hero: HeroMotion.drive,
      fx: {GiftFx.speedLines: 14, GiftFx.confetti: 14},
      glow: Color(0xFFFF5A36),
      palette: [Color(0xFFFF5A36), _gold, Colors.white, Color(0xFF7FB8E6)],
    ),
    'crown' => const GiftChoreography(
      hero: HeroMotion.descend,
      fx: {GiftFx.rays: 1, GiftFx.goldDust: 16, GiftFx.sparkles: 14},
      glow: _gold,
      palette: [_gold, Color(0xFFFFD86B), Colors.white],
    ),
    'yacht' => const GiftChoreography(
      hero: HeroMotion.bob,
      fx: {GiftFx.waves: 3, GiftFx.sparkles: 14},
      glow: Color(0xFFFF9F5A),
      palette: [Color(0xFF5AB4FF), Color(0xFFBFE6FF), Color(0xFFFFC38A)],
    ),
    'rocket' => const GiftChoreography(
      hero: HeroMotion.launch,
      fx: {GiftFx.exhaust: 22, GiftFx.fireworks: 2},
      glow: Color(0xFFC59BFF),
      palette: [Color(0xFFFFB347), Color(0xFFFF5A36), Color(0xFFC59BFF), _gold],
    ),
    'castle' => const GiftChoreography(
      hero: HeroMotion.pop,
      fx: {GiftFx.fireworks: 4, GiftFx.confetti: 16, GiftFx.sparkles: 10},
      glow: Color(0xFFC59BFF),
      palette: [Color(0xFFC59BFF), _gold, Color(0xFF7FB8E6), Color(0xFFFF6B9A)],
    ),
    _ => GiftChoreography(
      hero: HeroMotion.pop,
      fx: {GiftFx.sparkles: giftParticleCount(g.tier)},
      glow: giftTierColor(g.tier),
      palette: [giftTierColor(g.tier), Colors.white],
    ),
  };
}

/// Hero transform at progress [t] (0–1): offset as a fraction of the band
/// size, scale, and a horizontal "spin" factor (1 = facing, 0 = edge-on).
({Offset offset, double scale, double spinX}) heroPose(HeroMotion m, double t) {
  double ease(double a, double b) =>
      Curves.easeOutCubic.transform(((t - a) / (b - a)).clamp(0, 1));
  final float = .03 * math.sin(t * math.pi * 6);
  switch (m) {
    case HeroMotion.pop:
      final pop = t < .18
          ? Curves.elasticOut.transform((t / .18).clamp(0, 1))
          : 1 + .04 * math.sin(t * math.pi * 6);
      return (offset: Offset(0, float), scale: pop, spinX: 1);
    case HeroMotion.bounce:
      final drop = Curves.bounceOut.transform((t / .3).clamp(0, 1));
      final squash = t > .3 ? 1 + .05 * math.sin((t - .3) * math.pi * 8) : 1.0;
      return (offset: Offset(0, -.6 * (1 - drop)), scale: squash, spinX: 1);
    case HeroMotion.spin:
      final turns = 2 * (1 - ease(0, .35));
      return (
        offset: Offset(0, float),
        scale: .6 + .4 * ease(0, .25),
        spinX: math.cos(turns * math.pi * 2).abs().clamp(.08, 1),
      );
    case HeroMotion.drive:
      // In (0–25 %), park (25–75 %), out (75–100 %).
      final x = t < .25
          ? -1.1 * (1 - ease(0, .25))
          : t < .75
          ? 0.0
          : 1.1 * Curves.easeInCubic.transform(((t - .75) / .25).clamp(0, 1));
      return (offset: Offset(x, 0), scale: 1, spinX: 1);
    case HeroMotion.descend:
      return (
        offset: Offset(0, -.7 * (1 - ease(0, .35)) + float),
        scale: 1,
        spinX: 1,
      );
    case HeroMotion.bob:
      return (
        offset: Offset(
          .04 * math.sin(t * math.pi * 2),
          .05 * math.sin(t * math.pi * 4),
        ),
        scale: 1,
        spinX: 1,
      );
    case HeroMotion.launch:
      // Rumble, then lift off to the top of the band.
      final rumble = t < .25 ? .01 * math.sin(t * 160) : 0.0;
      final y = t < .25
          ? 0.0
          : -1.2 * Curves.easeInCubic.transform(((t - .25) / .6).clamp(0, 1));
      return (offset: Offset(rumble, .25 + y), scale: 1, spinX: 1);
  }
}

final class _P {
  const _P(
    this.x,
    this.y,
    this.delay,
    this.speed,
    this.size,
    this.spin,
    this.color,
  );
  final double x, y, delay, speed, size, spin;
  final Color color;
}

/// Paints every effect layer of one celebration in a single pass.
class GiftFxPainter extends CustomPainter {
  GiftFxPainter({required this.choreo, required this.t, required int seed})
    : _layers = _seed(choreo, seed);

  final GiftChoreography choreo;
  final double t;
  final Map<GiftFx, List<_P>> _layers;

  static Map<GiftFx, List<_P>> _seed(GiftChoreography c, int seed) {
    final r = math.Random(seed);
    return {
      for (final e in c.fx.entries)
        e.key: List.generate(
          e.value,
          (i) => _P(
            r.nextDouble(),
            r.nextDouble(),
            r.nextDouble() * .4,
            .6 + r.nextDouble() * .6,
            .6 + r.nextDouble() * .8,
            (r.nextDouble() - .5) * 6,
            c.palette[r.nextInt(c.palette.length)],
          ),
        ),
    };
  }

  /// Local progress of a particle that starts after its delay.
  double _local(_P p) => ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .45);
    final s = size.shortestSide;

    // Soft glow behind the hero.
    final gr = s * (.34 + .04 * math.sin(t * math.pi * 4));
    canvas.drawCircle(
      center,
      gr,
      Paint()
        ..shader = RadialGradient(
          colors: [
            choreo.glow.withValues(alpha: .30),
            choreo.glow.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: gr)),
    );

    for (final e in _layers.entries) {
      switch (e.key) {
        case GiftFx.rays:
          _rays(canvas, center, s);
        case GiftFx.sweep:
          _sweep(canvas, center, s);
        case GiftFx.waves:
          _waves(canvas, size, e.value.length);
        case GiftFx.petals:
          for (final p in e.value) {
            final l = _local(p);
            if (l <= 0) continue;
            final pos = Offset(
              size.width * (p.x + .06 * math.sin(l * math.pi * 3 + p.spin)),
              size.height * (-.05 + l * p.speed * 1.1),
            );
            _petal(canvas, pos, 9 * p.size, l * p.spin, p.color, 1 - l * .6);
          }
        case GiftFx.hearts:
          for (final p in e.value) {
            final l = _local(p);
            if (l <= 0) continue;
            final pos = Offset(
              size.width * (p.x + .05 * math.sin(l * math.pi * 4)),
              size.height * (1.02 - l * p.speed),
            );
            _heart(canvas, pos, 10 * p.size, p.color, 1 - l * .7);
          }
        case GiftFx.sparkles:
          for (final p in e.value) {
            final tw = math.sin((t * 3 + p.delay * 5) * math.pi).abs();
            final pos = Offset(
              size.width * (.1 + .8 * p.x),
              size.height * (.1 + .75 * p.y),
            );
            _sparkle(canvas, pos, 7 * p.size * tw, p.color, tw);
          }
        case GiftFx.goldDust:
          for (final p in e.value) {
            final l = _local(p);
            if (l <= 0) continue;
            final a = p.x * math.pi * 2;
            final d = s * (.08 + .42 * Curves.easeOut.transform(l) * p.speed);
            canvas.drawCircle(
              center + Offset(math.cos(a), math.sin(a)) * d,
              2.4 * p.size,
              Paint()..color = p.color.withValues(alpha: (1 - l) * .9),
            );
          }
        case GiftFx.confetti:
          for (final p in e.value) {
            final l = _local(p);
            if (l <= 0) continue;
            canvas
              ..save()
              ..translate(
                size.width * (p.x + .05 * math.sin(l * math.pi * 5)),
                size.height * (-.05 + l * p.speed * 1.1),
              )
              ..rotate(l * p.spin * 2);
            canvas.drawRect(
              Rect.fromCenter(
                center: Offset.zero,
                width: 8 * p.size,
                height: 4 * p.size,
              ),
              Paint()..color = p.color.withValues(alpha: (1 - l * .5)),
            );
            canvas.restore();
          }
        case GiftFx.speedLines:
          for (final p in e.value) {
            final l = ((t * 2 + p.delay) % 1);
            final y = size.height * (.3 + .35 * p.y);
            final x = size.width * (1.1 - 1.4 * l);
            canvas.drawLine(
              Offset(x, y),
              Offset(x + 50 * p.size, y),
              Paint()
                ..strokeWidth = 2
                ..strokeCap = StrokeCap.round
                ..color = Colors.white.withValues(
                  alpha: .45 * math.sin(l * math.pi),
                ),
            );
          }
        case GiftFx.exhaust:
          // Trail under the launching rocket.
          final pose = heroPose(HeroMotion.launch, t);
          final origin =
              center +
              Offset(
                pose.offset.dx * size.width,
                (pose.offset.dy + .12) * size.height,
              );
          for (final p in e.value) {
            final l = ((t * 2.2 + p.delay) % 1);
            if (t < .2) continue;
            final pos = origin + Offset((p.x - .5) * 70 * l, 130 * l * p.speed);
            canvas.drawCircle(
              pos,
              (4 + 11 * l) * p.size,
              Paint()..color = p.color.withValues(alpha: (1 - l) * .7),
            );
          }
        case GiftFx.fireworks:
          for (var i = 0; i < e.value.length; i++) {
            final p = e.value[i];
            final start = .35 + .45 * (i / e.value.length);
            final l = ((t - start) / .4).clamp(0.0, 1.0);
            if (l <= 0 || l >= 1) continue;
            final c = Offset(
              size.width * (.2 + .6 * p.x),
              size.height * (.1 + .3 * p.y),
            );
            final reach = s * .22 * Curves.easeOutCubic.transform(l);
            final fade = 1 - Curves.easeIn.transform(l);
            if (l < .12) {
              // Brief flash at the burst point.
              canvas.drawCircle(
                c,
                s * .05,
                Paint()
                  ..color = Colors.white.withValues(alpha: (1 - l / .12) * .8),
              );
            }
            for (var k = 0; k < 14; k++) {
              final a = k / 14 * math.pi * 2 + p.spin;
              final dir = Offset(math.cos(a), math.sin(a));
              final color = choreo.palette[(k + i) % choreo.palette.length];
              // A streak (spark with a short trail), drooping slightly.
              final head = c + dir * reach + Offset(0, 18 * l * l);
              final tail = c + dir * reach * .7 + Offset(0, 12 * l * l);
              canvas
                ..drawLine(
                  tail,
                  head,
                  Paint()
                    ..strokeWidth = 2.2
                    ..strokeCap = StrokeCap.round
                    ..color = color.withValues(alpha: fade * .9),
                )
                ..drawCircle(
                  head,
                  2.6,
                  Paint()..color = color.withValues(alpha: fade),
                );
            }
          }
      }
    }
  }

  void _rays(Canvas canvas, Offset c, double s) {
    // Soft light rays: short, fading outwards, gently pulsing. They stay
    // around the hero so faces in the video are not washed out.
    final r = s * .36;
    final pulse = .75 + .25 * math.sin(t * math.pi * 3);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: .22 * pulse),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    for (var i = 0; i < 8; i++) {
      final a = i / 8 * math.pi * 2 + t * math.pi * .5;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + math.cos(a - .045) * r, c.dy + math.sin(a - .045) * r)
        ..lineTo(c.dx + math.cos(a + .045) * r, c.dy + math.sin(a + .045) * r)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  void _sweep(Canvas canvas, Offset c, double s) {
    final r = s * .2;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas
      ..drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = choreo.glow.withValues(alpha: .25),
      )
      ..drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * t,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = choreo.glow.withValues(alpha: .9),
      );
  }

  void _waves(Canvas canvas, Size size, int n) {
    for (var i = 0; i < n; i++) {
      final y = size.height * (.62 + i * .06);
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= size.width; x += 8) {
        path.lineTo(x, y + 6 * math.sin(x / 28 + t * math.pi * 4 + i));
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = choreo.palette[i % choreo.palette.length].withValues(
            alpha: .55 - i * .12,
          ),
      );
    }
  }

  void _petal(
    Canvas canvas,
    Offset p,
    double r,
    double angle,
    Color c,
    double alpha,
  ) {
    canvas
      ..save()
      ..translate(p.dx, p.dy)
      ..rotate(angle);
    final path = Path()
      ..moveTo(0, -r)
      ..quadraticBezierTo(r, 0, 0, r)
      ..quadraticBezierTo(-r, 0, 0, -r);
    canvas
      ..drawPath(path, Paint()..color = c.withValues(alpha: alpha.clamp(0, 1)))
      ..restore();
  }

  void _heart(Canvas canvas, Offset p, double r, Color c, double alpha) {
    final path = Path()
      ..moveTo(p.dx, p.dy + r * .9)
      ..cubicTo(
        p.dx - r * 1.4,
        p.dy - r * .1,
        p.dx - r * .6,
        p.dy - r * 1.2,
        p.dx,
        p.dy - r * .4,
      )
      ..cubicTo(
        p.dx + r * .6,
        p.dy - r * 1.2,
        p.dx + r * 1.4,
        p.dy - r * .1,
        p.dx,
        p.dy + r * .9,
      );
    canvas.drawPath(
      path,
      Paint()..color = c.withValues(alpha: alpha.clamp(0, 1)),
    );
  }

  void _sparkle(Canvas canvas, Offset p, double r, Color c, double alpha) {
    if (r <= .5) return;
    final path = Path()
      ..moveTo(p.dx, p.dy - r)
      ..quadraticBezierTo(p.dx, p.dy, p.dx + r, p.dy)
      ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + r)
      ..quadraticBezierTo(p.dx, p.dy, p.dx - r, p.dy)
      ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - r);
    canvas.drawPath(
      path,
      Paint()..color = c.withValues(alpha: alpha.clamp(0, 1)),
    );
  }

  @override
  bool shouldRepaint(GiftFxPainter old) => old.t != t || old.choreo != choreo;
}
