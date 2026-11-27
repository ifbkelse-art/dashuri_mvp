import 'package:equatable/equatable.dart';

/// Server-side filters of the Beans history (GET /v1/host/beans/history?type=).
enum BeanFilter {
  all('all', 'All'),
  calls('calls', 'Calls'),
  gifts('gifts', 'Gifts'),
  released('released', 'Released'),
  withdrawals('withdrawals', 'Withdrawals'),
  other('other', 'Other');

  const BeanFilter(this.wire, this.label);

  final String wire;
  final String label;
}

/// What a history line is, for its icon and colour.
enum BeanLineType {
  call,
  freeCall,
  gift,
  release,
  withdrawal,
  payoutPaid,
  payoutFailed,
  reversal,
  adjustment,
  other;

  static BeanLineType fromWire(String? v) => switch (v) {
    'call' => call,
    'free_call' => freeCall,
    'gift' => gift,
    'release' => release,
    'withdrawal' => withdrawal,
    'payout_paid' => payoutPaid,
    'payout_failed' => payoutFailed,
    'reversal' => reversal,
    'adjustment' => adjustment,
    _ => other,
  };

  /// Earnings are the lines that carry a hold status.
  bool get isEarning => this == call || this == freeCall || this == gift;
}

/// One Bean movement of the host. [beans] is the change to the balance (on
/// hold + available); pure moves between buckets are 0 and report
/// [movedBeans] instead. The newest line's [balanceAfter] is the balance.
final class BeanHistoryItem extends Equatable {
  const BeanHistoryItem({
    required this.id,
    required this.occurredAt,
    required this.type,
    required this.title,
    required this.beans,
    required this.balanceAfter,
    this.subtitle,
    this.movedBeans,
    this.onHold,
    this.releasesAt,
    this.releasedAt,
    this.callId,
    this.peerName,
  });

  final String id;
  final DateTime occurredAt;
  final BeanLineType type;
  final String title;
  final String? subtitle;
  final int beans;
  final int? movedBeans;
  final int balanceAfter;

  /// Earnings only: true while the 7-day hold runs, false once released.
  final bool? onHold;
  final DateTime? releasesAt;
  final DateTime? releasedAt;
  final String? callId;
  final String? peerName;

  @override
  List<Object?> get props => [id, beans, balanceAfter, onHold];
}

/// Header of the history screen (GET /v1/host/beans/summary).
final class BeanSummary extends Equatable {
  const BeanSummary({
    required this.balance,
    required this.onHold,
    required this.available,
    required this.pendingPayout,
    required this.lifetimeEarned,
    required this.fromCalls,
    required this.fromGifts,
    required this.fromFreeCalls,
    required this.reversed,
    required this.paidOut,
    required this.earnedToday,
    required this.earned7Days,
    required this.earned30Days,
  });

  final int balance;
  final int onHold;
  final int available;
  final int pendingPayout;
  final int lifetimeEarned;
  final int fromCalls;
  final int fromGifts;
  final int fromFreeCalls;
  final int reversed;
  final int paidOut;
  final int earnedToday;
  final int earned7Days;
  final int earned30Days;

  @override
  List<Object?> get props => [balance, lifetimeEarned, earnedToday, paidOut];
}
