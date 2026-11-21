import 'package:flutter/material.dart';

import '../tokens/dashuri_tokens.dart';

/// The Diamond glyph (customer currency), DS12.
class DiamondIcon extends StatelessWidget {
  const DiamondIcon({super.key, this.size = 18, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Diamonds',
    child: CustomPaint(
      size: Size.square(size),
      painter: _DiamondPainter(color ?? DashuriTokens.burgundy400),
    ),
  );
}

class _DiamondPainter extends CustomPainter {
  _DiamondPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final outline = Path()
      ..moveTo(w * .22, h * .14)
      ..lineTo(w * .78, h * .14)
      ..lineTo(w * .98, h * .40)
      ..lineTo(w * .5, h * .92)
      ..lineTo(w * .02, h * .40)
      ..close();
    canvas.drawPath(outline, Paint()..color = color);
    final facet = Paint()
      ..color = Colors.white.withValues(alpha: .45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .06
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..drawLine(Offset(w * .02, h * .40), Offset(w * .98, h * .40), facet)
      ..drawPath(
        Path()
          ..moveTo(w * .30, h * .40)
          ..lineTo(w * .5, h * .90)
          ..lineTo(w * .70, h * .40),
        facet,
      );
  }

  @override
  bool shouldRepaint(_DiamondPainter old) => old.color != color;
}

/// The Bean glyph (host earnings), DS12.
class BeanIcon extends StatelessWidget {
  const BeanIcon({super.key, this.size = 18, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Beans',
    child: CustomPaint(
      size: Size.square(size),
      painter: _BeanPainter(color ?? DashuriTokens.gold),
    ),
  );
}

class _BeanPainter extends CustomPainter {
  _BeanPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final r = Rect.fromLTWH(
      s.width * .12,
      s.height * .06,
      s.width * .76,
      s.height * .88,
    );
    canvas
      ..save()
      ..translate(s.width / 2, s.height / 2)
      ..rotate(.5)
      ..translate(-s.width / 2, -s.height / 2)
      ..drawOval(r, Paint()..color = color)
      ..drawArc(
        r.deflate(s.width * .2),
        -1.2,
        2.4,
        false,
        Paint()
          ..color = Colors.white.withValues(alpha: .55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.width * .07
          ..strokeCap = StrokeCap.round,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_BeanPainter old) => old.color != color;
}
