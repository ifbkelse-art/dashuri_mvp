import 'dart:async';
import 'dart:math' as math;

import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/gift_celebration_cubit.dart';
import '../../domain/entities/gift.dart';
import 'gift_visuals.dart';

/// Transparent, non-blocking gift celebration over the call video.
///
/// - Never takes touches (IgnorePointer): controls, chat and the report
///   button stay usable under it.
/// - Sits in the band between the top bar and the controls, so it never
///   covers them; the particles are transparent and the banner is small, so
///   faces stay visible.
/// - Reduced motion (system "remove animations"): a static banner only.
/// - One repaint boundary and one painter for all particles; no images, no
///   video, no extra GPU layers per particle.
class GiftCelebrationOverlay extends StatelessWidget {
  const GiftCelebrationOverlay({required this.viewerIsCustomer, super.key});

  /// The customer sees "You sent…", the host "… sent you …".
  final bool viewerIsCustomer;

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<GiftCelebrationCubit, GiftCelebrationState>(
        listenWhen: (a, b) => b.sequence != a.sequence && b.current != null,
        listener: (context, s) {
          if (!viewerIsCustomer) {
            // Host feedback: a light haptic (respects system settings).
            HapticFeedback.mediumImpact();
          }
          unawaited(
            SemanticsService.sendAnnouncement(
              View.of(context),
              giftBannerText(s.current!, viewerIsCustomer: viewerIsCustomer),
              Directionality.of(context),
            ),
          );
        },
        builder: (context, s) {
          final gift = s.current;
          if (gift == null) return const SizedBox.shrink();
          final reduced = MediaQuery.of(context).disableAnimations;
          return IgnorePointer(
            child: RepaintBoundary(
              child: _Celebration(
                key: ValueKey(gift.giftTransactionId),
                gift: gift,
                text: giftBannerText(gift, viewerIsCustomer: viewerIsCustomer),
                reducedMotion: reduced,
                duration: s.compact
                    ? const Duration(milliseconds: 1500)
                    : gift.animationDuration,
                pending: s.pending,
              ),
            ),
          );
        },
      );
}

/// The celebration banner from the viewer's side of the call.
String giftBannerText(GiftEvent g, {required bool viewerIsCustomer}) {
  final sender = g.senderName.isEmpty ? 'Someone' : g.senderName;
  final host = g.recipientName.isEmpty ? 'the host' : g.recipientName;
  return viewerIsCustomer
      ? 'You sent ${g.giftName} to $host'
      : '$sender sent you ${g.giftName}';
}

class _Celebration extends StatefulWidget {
  const _Celebration({
    required this.gift,
    required this.text,
    required this.reducedMotion,
    required this.duration,
    required this.pending,
    super.key,
  });

  final GiftEvent gift;
  final String text;
  final bool reducedMotion;
  final Duration duration;
  final int pending;

  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  late final List<_Particle> _particles = _seedParticles();

  List<_Particle> _seedParticles() {
    if (widget.reducedMotion) return const [];
    final r = math.Random(widget.gift.giftTransactionId.hashCode);
    return List.generate(
      giftParticleCount(widget.gift.tier),
      (_) => _Particle(
        x: r.nextDouble(),
        delay: r.nextDouble() * .35,
        speed: .55 + r.nextDouble() * .45,
        wobble: (r.nextDouble() - .5) * .12,
        scale: .6 + r.nextDouble() * .7,
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = giftTierColor(widget.gift.tier);
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        // The band between the top bar and the controls.
        final top = c.maxHeight * .16;
        final bottom = c.maxHeight * .30;
        return Padding(
          padding: EdgeInsets.only(top: top, bottom: bottom),
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value;
              // Fade in over the first 8 %, out over the last 12 %.
              final fade = t < .08
                  ? t / .08
                  : t > .88
                  ? (1 - t) / .12
                  : 1.0;
              return Opacity(
                opacity: fade.clamp(0, 1),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (!widget.reducedMotion)
                      CustomPaint(
                        key: const Key('gift-particles'),
                        painter: _ParticlePainter(
                          emoji: widget.gift.emoji,
                          particles: _particles,
                          t: t,
                          glow: giftHasGlow(widget.gift.tier) ? accent : null,
                          rings: giftHasRings(widget.gift.tier) ? accent : null,
                        ),
                      ),
                    Align(
                      alignment: const Alignment(0, -.1),
                      child: _Hero(
                        emoji: widget.gift.emoji,
                        t: t,
                        reduced: widget.reducedMotion,
                      ),
                    ),
                    Align(
                      alignment: const Alignment(0, .85),
                      child: _Banner(
                        text: widget.text,
                        value: widget.gift.diamondValue,
                        accent: accent,
                        pending: widget.pending,
                        theme: theme,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.emoji, required this.t, required this.reduced});

  final String emoji;
  final double t;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    // A short elastic pop, then a gentle float.
    final pop = reduced
        ? 1.0
        : t < .18
        ? Curves.elasticOut.transform((t / .18).clamp(0, 1))
        : 1 + .04 * math.sin(t * math.pi * 6);
    return Transform.scale(
      scale: pop,
      child: Text(
        emoji,
        style: const TextStyle(fontSize: 88),
        textScaler: TextScaler.noScaling,
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.text,
    required this.value,
    required this.accent,
    required this.pending,
    required this.theme,
  });

  final String text;
  final int value;
  final Color accent;
  final int pending;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 360),
    child: DecoratedBox(
      // Same per-element dark backing as the in-call chat: readable over any
      // video without hiding the faces behind a panel.
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .58),
        borderRadius: BorderRadius.circular(DashuriTokens.radiusPill),
        border: Border.all(color: accent.withValues(alpha: .8)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DashuriTokens.space4,
          vertical: DashuriTokens.space2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: DashuriTokens.space2),
            CurrencyAmount.diamonds(
              value,
              style: theme.textTheme.labelMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
            if (pending > 0) ...[
              const SizedBox(width: DashuriTokens.space2),
              Text(
                '+$pending',
                style: theme.textTheme.labelMedium?.copyWith(color: accent),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

final class _Particle {
  const _Particle({
    required this.x,
    required this.delay,
    required this.speed,
    required this.wobble,
    required this.scale,
  });

  final double x, delay, speed, wobble, scale;
}

/// Draws every particle with ONE cached emoji glyph (no per-particle
/// layers), plus an optional tier glow and expanding rings.
class _ParticlePainter extends CustomPainter {
  _ParticlePainter({
    required this.emoji,
    required this.particles,
    required this.t,
    this.glow,
    this.rings,
  });

  final String emoji;
  final List<_Particle> particles;
  final double t;
  final Color? glow;
  final Color? rings;

  static final Map<String, TextPainter> _glyphs = {};

  TextPainter get _glyph => _glyphs.putIfAbsent(
    emoji,
    () => TextPainter(
      text: TextSpan(text: emoji, style: const TextStyle(fontSize: 30)),
      textDirection: TextDirection.ltr,
    )..layout(),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .45);
    if (glow != null) {
      final r = size.shortestSide * (.35 + .05 * math.sin(t * math.pi * 4));
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [glow!.withValues(alpha: .35), glow!.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }
    if (rings != null) {
      for (var i = 0; i < 3; i++) {
        final p = ((t * 1.6) + i / 3) % 1;
        canvas.drawCircle(
          center,
          size.shortestSide * (.1 + .45 * p),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = rings!.withValues(alpha: (1 - p) * .6),
        );
      }
    }
    final glyph = _glyph;
    for (final p in particles) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = size.height * (1 - local * p.speed * 1.1);
      final x = size.width * (p.x + p.wobble * math.sin(local * math.pi * 3));
      canvas
        ..save()
        ..translate(x, y)
        ..scale(p.scale * (1 - local * .3));
      glyph.paint(canvas, Offset(-glyph.width / 2, -glyph.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.t != t || old.emoji != emoji;
}
