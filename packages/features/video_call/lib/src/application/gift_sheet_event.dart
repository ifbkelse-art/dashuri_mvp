part of 'gift_sheet_bloc.dart';

sealed class GiftSheetEvent extends Equatable {
  const GiftSheetEvent();

  @override
  List<Object?> get props => [];
}

/// The customer opened the sheet (loads catalogue + balance; refreshes on
/// every open so disabled gifts and price changes show up).
final class GiftSheetOpened extends GiftSheetEvent {
  const GiftSheetOpened({required this.callId, required this.recipientUserId});

  final String callId;
  final String recipientUserId;

  @override
  List<Object?> get props => [callId, recipientUserId];
}

final class GiftSelected extends GiftSheetEvent {
  const GiftSelected(this.giftId);

  final String giftId;

  @override
  List<Object?> get props => [giftId];
}

final class GiftSendPressed extends GiftSheetEvent {
  const GiftSendPressed();
}

/// The call became (in)eligible for gifting (only an active call is).
final class GiftCallEligibilityChanged extends GiftSheetEvent {
  const GiftCallEligibilityChanged({required this.eligible});

  final bool eligible;

  @override
  List<Object?> get props => [eligible];
}
