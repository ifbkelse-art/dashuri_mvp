import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/gift.dart';
import '../domain/usecases/gift_usecases.dart';

part 'gift_sheet_event.dart';
part 'gift_sheet_state.dart';

/// The customer's gift picker during a call: catalogue, selection, balance
/// and an idempotent Send.
///
/// The server is authoritative for every amount. The client only decides
/// what to SHOW (e.g. "not enough Diamonds" when the displayed balance is
/// below the displayed price); the server re-checks everything.
///
/// Idempotency: one key per Send intent. If the outcome is unknown (network
/// failure or timeout), the key is kept and reused when the customer taps
/// Send again for the same gift, so a retry can never charge twice. A
/// definite refusal or a new selection discards it.
final class GiftSheetBloc extends Bloc<GiftSheetEvent, GiftSheetState> {
  GiftSheetBloc({
    required GetGiftCatalogue catalogue,
    required GetGiftBalance balance,
    required SendGift send,
    IdempotencyKey Function()? newKey,
  }) : _catalogue = catalogue,
       _balance = balance,
       _send = send,
       _newKey = newKey ?? IdempotencyKey.generate,
       super(const GiftSheetState()) {
    on<GiftSheetOpened>(_onOpened);
    on<GiftSelected>(_onSelected);
    on<GiftSendPressed>(_onSend);
    on<GiftCallEligibilityChanged>(_onEligibility);
  }

  final GetGiftCatalogue _catalogue;
  final GetGiftBalance _balance;
  final SendGift _send;
  final IdempotencyKey Function() _newKey;

  /// Kept across retries of one intent (same gift) when the outcome is unknown.
  IdempotencyKey? _pendingKey;
  String? _pendingGiftId;

  Future<void> _onOpened(
    GiftSheetOpened e,
    Emitter<GiftSheetState> emit,
  ) async {
    emit(
      state.copyWith(
        callId: e.callId,
        recipientUserId: e.recipientUserId,
        load: GiftLoadStatus.loading,
        send: state.send == GiftSendStatus.sending
            ? GiftSendStatus.sending
            : GiftSendStatus.idle,
      ),
    );
    final results = await Future.wait([
      _catalogue(const NoInput()),
      _balance(const NoInput()),
    ]);
    final cat = results[0] as Result<List<Gift>>;
    final bal = results[1] as Result<int>;
    switch (cat) {
      case Success(:final value):
        final keep =
            state.selectedId != null &&
            value.any((g) => g.id == state.selectedId);
        emit(
          state.copyWith(
            load: GiftLoadStatus.ready,
            gifts: value,
            balance: bal is Success<int> ? bal.value : null,
            clearSelection: !keep,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(load: GiftLoadStatus.failed, failure: failure));
    }
  }

  void _onSelected(GiftSelected e, Emitter<GiftSheetState> emit) {
    if (state.send == GiftSendStatus.sending) return;
    if (e.giftId != _pendingGiftId) {
      _pendingKey = null;
      _pendingGiftId = null;
    }
    emit(state.copyWith(selectedId: e.giftId, send: GiftSendStatus.idle));
  }

  void _onEligibility(
    GiftCallEligibilityChanged e,
    Emitter<GiftSheetState> emit,
  ) => emit(state.copyWith(callEligible: e.eligible));

  Future<void> _onSend(GiftSendPressed e, Emitter<GiftSheetState> emit) async {
    final gift = state.selected;
    final callId = state.callId;
    final recipient = state.recipientUserId;
    // Repeated taps while a send is in flight are ignored.
    if (state.send == GiftSendStatus.sending ||
        gift == null ||
        callId == null ||
        recipient == null ||
        !state.callEligible) {
      return;
    }
    if (state.insufficient) {
      emit(
        state.copyWith(
          send: GiftSendStatus.failed,
          failure: const BusinessRuleFailure(code: 'insufficient_diamonds'),
        ),
      );
      return;
    }
    if (_pendingGiftId != gift.id) {
      _pendingKey = _newKey();
      _pendingGiftId = gift.id;
    }
    final key = _pendingKey!;
    emit(state.copyWith(send: GiftSendStatus.sending));
    final result = await _send(
      SendGiftInput(
        callId: callId,
        giftId: gift.id,
        recipientUserId: recipient,
        idempotencyKey: key,
      ),
    );
    switch (result) {
      case Success(:final value):
        _pendingKey = null;
        _pendingGiftId = null;
        emit(
          state.copyWith(
            send: GiftSendStatus.sent,
            balance: value.availableDiamonds,
            lastReceipt: value,
            sentCount: state.sentCount + 1,
          ),
        );
      case Err(:final failure):
        final unknownOutcome =
            failure is NetworkFailure ||
            failure is ServerFailure ||
            (failure is ConflictFailure &&
                failure.code == 'request_in_progress');
        if (!unknownOutcome) {
          _pendingKey = null;
          _pendingGiftId = null;
        }
        final ended = const {
          'call_not_giftable',
          'not_found',
        }.contains(failure.code);
        emit(
          state.copyWith(
            send: GiftSendStatus.failed,
            failure: failure,
            callEligible: ended ? false : state.callEligible,
            // A gift that became unavailable leaves the list on next open.
          ),
        );
        if (failure.code == 'insufficient_diamonds') {
          final bal = await _balance(const NoInput());
          if (bal case Success(:final value)) {
            emit(state.copyWith(balance: value));
          }
        }
    }
  }
}
