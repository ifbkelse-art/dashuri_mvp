import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:feature_chat/feature_chat.dart';
import 'package:feature_chat/src/presentation/widgets/chat_format.dart';
import 'package:feature_chat/src/presentation/widgets/message_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ChatBubble bubble({required bool gift}) => ChatBubble(
    localId: 'm1',
    serverId: 'm1',
    body: gift ? '🌹 Asha sent Rose to Meera.' : 'hello',
    sentAt: DateTime.utc(2026, 11, 26, 10),
    mine: true,
    context: MessageContext.call,
    isGift: gift,
  );

  for (final overlay in [false, true]) {
    testWidgets('gift line (overlay: $overlay) is a centred event, no delivery '
        'state', (t) async {
      DashuriText.useGoogleFonts = false;
      await t.pumpWidget(
        MaterialApp(
          theme: DashuriTheme.light(),
          home: Scaffold(
            body: MessageBubble(
              bubble: bubble(gift: true),
              delivery: DeliveryState.read,
              overlay: overlay,
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('gift-line')), findsOneWidget);
      // The sender sees "You", not their own name.
      expect(find.text('🌹 You sent Rose to Meera.'), findsOneWidget);
      expect(find.text('Read'), findsNothing);
      expect(
        find.bySemanticsLabel('Gift: 🌹 You sent Rose to Meera.'),
        findsOneWidget,
      );
    });
  }

  test('giftLineAsYou rewrites only the sender', () {
    expect(
      ChatFormat.giftLineAsYou('🌹 Asha Rao sent Rose to Meera.'),
      '🌹 You sent Rose to Meera.',
    );
    expect(ChatFormat.giftLineAsYou('hello'), 'hello');
  });

  test('giftLineFor reads naturally for the recipient', () {
    expect(
      ChatFormat.giftLineFor('🌹 Rita sent Rose to Meera.', mine: false),
      '🌹 Rita sent you Rose.',
    );
    expect(
      ChatFormat.giftLineFor('🌹 Rita sent Rose to Meera.', mine: true),
      '🌹 You sent Rose to Meera.',
    );
    expect(ChatFormat.giftLineFor('hello', mine: false), 'hello');
  });

  testWidgets('text messages are unchanged', (t) async {
    DashuriText.useGoogleFonts = false;
    await t.pumpWidget(
      MaterialApp(
        theme: DashuriTheme.light(),
        home: Scaffold(
          body: MessageBubble(
            bubble: bubble(gift: false),
            delivery: DeliveryState.read,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('gift-line')), findsNothing);
    expect(find.textContaining('Read'), findsOneWidget);
  });
}
