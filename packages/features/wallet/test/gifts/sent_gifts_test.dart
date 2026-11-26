import 'dart:async';

import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:feature_wallet/feature_wallet.dart';
import 'package:feature_wallet/src/data/models/sent_gift_json.dart';
import 'package:feature_wallet/src/presentation/widgets/wallet_format.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _List extends Mock implements ListSentGifts {}

final _gift = SentGift(
  giftTransactionId: 'g1',
  giftName: 'Diamond Ring',
  emoji: '💎',
  diamondCost: 25000,
  recipientName: 'Meera',
  callId: 'c1',
  sentAt: DateTime.utc(2026, 11, 26, 10),
);

void main() {
  setUpAll(() => registerFallbackValue(const PageRequest()));

  test('JSON: cost, recipient and call', () {
    final g = sentGiftFromJson({
      'gift_transaction_id': 'g1',
      'gift_name': 'Rose',
      'emoji': '🌹',
      'diamond_cost': 1500,
      'diamond_value': 1500,
      'recipient': {'user_id': 'h1', 'display_name': 'Meera'},
      'call_id': 'c1',
      'sent_at': '2026-11-26T10:00:00Z',
    });
    expect(g.diamondCost, 1500);
    expect(g.recipientName, 'Meera');
    expect(g.callId, 'c1');
  });

  test('wallet history names gift entries for each side', () {
    WalletEntry e(String currency, int amount) => WalletEntry(
      id: 'e',
      currency: currency,
      kind: 'gift_send',
      amount: amount,
      createdAt: DateTime.utc(2026),
      reference: 'g1',
    );
    expect(WalletFormat.title(e('DIAMOND', -1500)), 'Gift sent');
    expect(WalletFormat.title(e('BEAN', 899)), 'Gift received');
  });

  test('cubit pages through gifts', () async {
    final list = _List();
    when(() => list(any())).thenAnswer((i) async {
      final p = i.positionalArguments.single as PageRequest;
      return Success(
        Page(items: [_gift], nextCursor: p.cursor == null ? 'n' : null),
      );
    });
    final c = SentGiftsCubit(list);
    await c.load();
    await c.loadMore();
    expect((c.state as SentGiftsLoaded).items, hasLength(2));
    expect((c.state as SentGiftsLoaded).nextCursor, isNull);
    await c.close();
  });

  testWidgets('page shows gift, recipient and Diamond cost', (t) async {
    DashuriText.useGoogleFonts = false;
    final list = _List();
    when(
      () => list(any()),
    ).thenAnswer((_) async => Success(Page(items: [_gift])));
    final c = SentGiftsCubit(list);
    addTearDown(c.close);
    unawaited(c.load());
    await t.pumpWidget(
      MaterialApp(
        theme: DashuriTheme.light(),
        home: BlocProvider.value(value: c, child: const SentGiftsPage()),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Diamond Ring to Meera'), findsOneWidget);
    expect(find.textContaining('25,000'), findsOneWidget);
  });
}
