import 'package:feature_host/feature_host.dart';
import 'package:feature_host/src/data/models/beans_json.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an on-hold call line', () {
    final i = beanHistoryItemFromJson({
      'id': 'e1',
      'occurred_at': '2026-11-28T09:00:00Z',
      'type': 'call',
      'title': 'Call with Bruce',
      'subtitle': '1 min 04 s · 500 Diamonds/min',
      'beans': 319,
      'balance_after': 5957,
      'status': 'on_hold',
      'releases_at': '2026-12-05T09:00:00Z',
      'call_id': 'c1',
      'peer_name': 'Bruce',
    });
    expect(i.type, BeanLineType.call);
    expect(i.type.isEarning, isTrue);
    expect(i.beans, 319);
    expect(i.balanceAfter, 5957);
    expect(i.onHold, isTrue);
    expect(i.releasesAt, DateTime.utc(2026, 12, 5, 9));
    expect(i.releasedAt, isNull);
    expect(i.movedBeans, isNull);
    expect(i.callId, 'c1');
    expect(i.peerName, 'Bruce');
  });

  test('a released line and a pure move', () {
    final released = beanHistoryItemFromJson({
      'id': 'e2',
      'occurred_at': '2026-11-28T09:00:00Z',
      'type': 'gift',
      'title': '🌹 Rose from Bruce',
      'beans': 899,
      'balance_after': 899,
      'status': 'released',
      'released_at': '2026-12-05T09:00:00Z',
    });
    expect(released.onHold, isFalse);
    expect(released.releasedAt, DateTime.utc(2026, 12, 5, 9));

    final move = beanHistoryItemFromJson({
      'id': 'e3',
      'occurred_at': '2026-11-28T09:00:00Z',
      'type': 'release',
      'title': 'Released from hold',
      'beans': 0,
      'moved_beans': 899,
      'balance_after': 899,
    });
    expect(move.type, BeanLineType.release);
    expect(move.type.isEarning, isFalse);
    expect(move.beans, 0);
    expect(move.movedBeans, 899);
    expect(move.onHold, isNull);
  });

  test('negative lines and unknown types stay safe', () {
    final claw = beanHistoryItemFromJson({
      'id': 'e4',
      'occurred_at': '2026-11-28T09:00:00Z',
      'type': 'reversal',
      'title': 'Earnings reversed',
      'beans': -100,
      'balance_after': 5857,
    });
    expect(claw.beans, -100);
    expect(claw.type, BeanLineType.reversal);
    final future = beanHistoryItemFromJson({
      'id': 'e5',
      'occurred_at': '2026-11-28T09:00:00Z',
      'type': 'a_type_from_the_future',
      'title': 'Beans activity',
      'beans': 1,
      'balance_after': 1,
    });
    expect(future.type, BeanLineType.other);
  });

  test('summary maps every field and tolerates missing ones', () {
    final s = beanSummaryFromJson({
      'balance_beans': 5957,
      'beans_on_hold': 5798,
      'beans_available': 159,
      'beans_pending_payout': 40,
      'lifetime_earned': 6497,
      'from_calls': 599,
      'from_gifts': 3898,
      'from_free_calls': 2000,
      'reversed': 100,
      'paid_out': 400,
      'earned_today': 4217,
      'earned_7_days': 6497,
      'earned_30_days': 6497,
    });
    expect(s.balance, 5957);
    expect(s.onHold + s.available, s.balance);
    expect(s.fromCalls + s.fromGifts + s.fromFreeCalls, s.lifetimeEarned);
    expect(s.pendingPayout, 40);
    expect(s.paidOut, 400);
    expect(beanSummaryFromJson({}).balance, 0);
  });
}
