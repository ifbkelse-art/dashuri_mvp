import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/bean_history.dart';

int _n(Object? v) => v is num ? v.toInt() : 0;

DateTime? _d(Object? v) => v is String ? DateTime.tryParse(v)?.toUtc() : null;

BeanHistoryItem beanHistoryItemFromJson(JsonMap j) {
  final status = j['status'] as String?;
  return BeanHistoryItem(
    id: j['id']! as String,
    occurredAt: DateTime.parse(j['occurred_at']! as String).toUtc(),
    type: BeanLineType.fromWire(j['type'] as String?),
    title: j['title']! as String,
    subtitle: j['subtitle'] as String?,
    beans: _n(j['beans']),
    movedBeans: j['moved_beans'] == null ? null : _n(j['moved_beans']),
    balanceAfter: _n(j['balance_after']),
    onHold: status == null ? null : status != 'released',
    releasesAt: _d(j['releases_at']),
    releasedAt: _d(j['released_at']),
    callId: j['call_id'] as String?,
    peerName: j['peer_name'] as String?,
  );
}

BeanSummary beanSummaryFromJson(JsonMap j) => BeanSummary(
  balance: _n(j['balance_beans']),
  onHold: _n(j['beans_on_hold']),
  available: _n(j['beans_available']),
  pendingPayout: _n(j['beans_pending_payout']),
  lifetimeEarned: _n(j['lifetime_earned']),
  fromCalls: _n(j['from_calls']),
  fromGifts: _n(j['from_gifts']),
  fromFreeCalls: _n(j['from_free_calls']),
  reversed: _n(j['reversed']),
  paidOut: _n(j['paid_out']),
  earnedToday: _n(j['earned_today']),
  earned7Days: _n(j['earned_7_days']),
  earned30Days: _n(j['earned_30_days']),
);
