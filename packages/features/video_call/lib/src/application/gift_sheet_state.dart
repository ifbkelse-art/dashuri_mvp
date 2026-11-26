part of 'gift_sheet_bloc.dart';

enum GiftLoadStatus { idle, loading, ready, failed }

enum GiftSendStatus { idle, sending, sent, failed }

final class GiftSheetState extends Equatable {
  const GiftSheetState({
    this.load = GiftLoadStatus.idle,
    this.send = GiftSendStatus.idle,
    this.gifts = const [],
    this.balance,
    this.selectedId,
    this.callId,
    this.recipientUserId,
    this.callEligible = true,
    this.failure,
    this.lastReceipt,
    this.sentCount = 0,
  });

  final GiftLoadStatus load;
  final GiftSendStatus send;
  final List<Gift> gifts;

  /// The customer's available Diamonds as last reported by the server.
  final int? balance;
  final String? selectedId;
  final String? callId;
  final String? recipientUserId;

  /// False once the call is no longer active.
  final bool callEligible;
  final Failure? failure;

  /// The server's receipt for the latest successful send.
  final GiftReceipt? lastReceipt;

  /// Increments per successful send (listeners react to every success).
  final int sentCount;

  Gift? get selected {
    for (final g in gifts) {
      if (g.id == selectedId) return g;
    }
    return null;
  }

  /// Display hint only; the server decides.
  bool get insufficient {
    final g = selected;
    final b = balance;
    return g != null && b != null && b < g.diamondPrice;
  }

  bool get canSend =>
      load == GiftLoadStatus.ready &&
      callEligible &&
      selected != null &&
      !insufficient &&
      send != GiftSendStatus.sending;

  GiftSheetState copyWith({
    GiftLoadStatus? load,
    GiftSendStatus? send,
    List<Gift>? gifts,
    int? balance,
    String? selectedId,
    bool clearSelection = false,
    String? callId,
    String? recipientUserId,
    bool? callEligible,
    Failure? failure,
    GiftReceipt? lastReceipt,
    int? sentCount,
  }) => GiftSheetState(
    load: load ?? this.load,
    send: send ?? this.send,
    gifts: gifts ?? this.gifts,
    balance: balance ?? this.balance,
    selectedId: clearSelection ? null : (selectedId ?? this.selectedId),
    callId: callId ?? this.callId,
    recipientUserId: recipientUserId ?? this.recipientUserId,
    callEligible: callEligible ?? this.callEligible,
    failure: failure,
    lastReceipt: lastReceipt ?? this.lastReceipt,
    sentCount: sentCount ?? this.sentCount,
  );

  @override
  List<Object?> get props => [
    load,
    send,
    gifts,
    balance,
    selectedId,
    callId,
    recipientUserId,
    callEligible,
    failure,
    lastReceipt,
    sentCount,
  ];
}
