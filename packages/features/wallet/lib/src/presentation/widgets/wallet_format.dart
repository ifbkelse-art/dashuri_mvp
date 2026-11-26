import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/wallet_entry.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Display helpers for ledger entries. Amounts and kinds come from the
/// server; nothing here computes value.
abstract final class WalletFormat {
  static String time(DateTime t) {
    final l = t.toLocal();
    final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
    final m = l.minute.toString().padLeft(2, '0');
    return '$h:$m ${l.hour < 12 ? 'AM' : 'PM'}';
  }

  static DateTime dayOf(DateTime t) {
    final l = t.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  /// "Today", "Yesterday" or "19 Nov 2026".
  static String day(DateTime t, {DateTime? now}) {
    final d = dayOf(t);
    final today = dayOf(now ?? DateTime.now());
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  static String dateTime(DateTime t) => '${day(t)}, ${time(t)}';

  static bool isBeans(WalletEntry e) => e.currency == 'BEAN';

  static String title(WalletEntry e) => switch (e.kind) {
    'purchase_credit' => 'Diamonds purchased',
    'promo_grant' => 'Promotional Diamonds',
    'call_settlement' => isBeans(e) ? 'Call earnings' : 'Video call',
    'free_call_compensation' => 'Free call earnings',
    'bean_release' => 'Beans released from hold',
    'withdrawal_requested' => 'Withdrawal requested',
    'payout_paid' => 'Payout paid',
    'payout_failed' => 'Payout returned',
    'purchase_reversal' => 'Purchase refunded',
    'bean_clawback' => 'Beans reversed',
    'promo_expiry' => 'Promotional Diamonds expired',
    'adjustment' => 'Balance adjustment',
    'gift_send' => isBeans(e) ? 'Gift received' : 'Gift sent',
    _ => _humanize(e.kind),
  };

  static IconData icon(WalletEntry e) => switch (e.kind) {
    'purchase_credit' => Icons.download_rounded,
    'promo_grant' => Icons.card_giftcard_rounded,
    'call_settlement' || 'free_call_compensation' => Icons.videocam_outlined,
    'purchase_reversal' || 'payout_failed' => Icons.replay_rounded,
    'withdrawal_requested' || 'payout_paid' => Icons.account_balance_outlined,
    'promo_expiry' => Icons.hourglass_bottom_rounded,
    'gift_send' => Icons.redeem_rounded,
    _ => Icons.receipt_long_outlined,
  };

  /// (background, foreground) of the row icon tile.
  static (Color, Color) iconColors(
    WalletEntry e,
    ColorScheme scheme,
    DashuriColors tones,
  ) => switch (e.kind) {
    'purchase_credit' ||
    'promo_grant' => (tones.success.container, tones.success.icon),
    'purchase_reversal' ||
    'payout_failed' => (tones.info.container, tones.info.icon),
    _ => (scheme.surfaceContainerHighest, scheme.onSurface),
  };

  static String signedAmount(WalletEntry e) =>
      '${e.amount > 0
          ? '+'
          : e.amount < 0
          ? '−'
          : ''}'
      '${DashuriFormat.count(e.amount.abs())}';

  static String _humanize(String kind) {
    final s = kind.replaceAll('_', ' ').trim();
    return s.isEmpty ? 'Transaction' : s[0].toUpperCase() + s.substring(1);
  }

  /// [subject] names what failed to load on this screen.
  static String failureMessage(Failure f, {String subject = 'your wallet'}) =>
      switch (f) {
        NetworkFailure() => 'You seem to be offline. Check your connection.',
        UnauthenticatedFailure() =>
          'Your session expired. Please sign in again.',
        NotFoundFailure() => "We couldn't find this transaction.",
        _ => "We couldn't load $subject. Please try again.",
      };
}
