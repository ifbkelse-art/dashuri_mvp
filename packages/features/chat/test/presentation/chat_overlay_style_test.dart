import 'package:feature_chat/src/presentation/widgets/message_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + .05) / (lo + .05);
}

void main() {
  // In-call chat is drawn over live video. Whatever the frame shows — pure
  // white, pure black — white text on each bubble's own backing must stay
  // readable (WCAG AA, 4.5:1).
  for (final (name, backing) in [
    ('their bubble', ChatOverlayStyle.theirBubble),
    ('my bubble', ChatOverlayStyle.myBubble),
    ('composer field', ChatOverlayStyle.field),
  ]) {
    for (final (frame, video) in [
      ('white', Colors.white),
      ('black', Colors.black),
      ('mid grey', const Color(0xFF808080)),
    ]) {
      test('$name keeps white text readable over a $frame video frame', () {
        final shown = Color.alphaBlend(backing, video);
        expect(_contrast(Colors.white, shown), greaterThanOrEqualTo(4.5));
      });
    }
  }
}
