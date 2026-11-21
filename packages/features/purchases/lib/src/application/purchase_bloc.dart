import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/cashfree_checkout_outcome.dart';
import '../domain/entities/cashfree_order.dart';
import '../domain/entities/diamond_package.dart';
import '../domain/entities/payment_rail.dart';
import '../domain/entities/payment_result.dart';
import '../domain/entities/purchase_update.dart';
import '../domain/entities/purchase_verification.dart';
import '../domain/usecases/cashfree_orders.dart';
import '../domain/usecases/get_client_rails.dart';
import '../domain/usecases/load_diamond_packages.dart';
import '../domain/usecases/start_purchase.dart';
import '../domain/usecases/verify_purchase.dart';
import '../domain/usecases/watch_purchase_updates.dart';

part 'purchase_event.dart';
part 'purchase_state.dart';

/// Polling plan for confirming a Cashfree order with the server.
final class ConfirmSchedule {
  const ConfirmSchedule({
    this.delays = const [
      Duration(seconds: 2),
      Duration(seconds: 3),
      Duration(seconds: 5),
      Duration(seconds: 8),
      Duration(seconds: 10),
    ],
    this.budget = const Duration(seconds: 60),
  });

  /// Backoff between checks; the last value repeats.
  final List<Duration> delays;

  /// Stop polling (and show "pending") after about this long.
  final Duration budget;

  Duration delayFor(int attempt) =>
      delays[attempt < delays.length ? attempt : delays.length - 1];
}

typedef Sleep = Future<void> Function(Duration);

/// Buy-Diamonds flow on two rails (founder decision F1).
///
/// Google Play: launch Play sheet → Play update → server verification →
/// server result. One idempotency key per purchase token, reused on retry.
///
/// Cashfree: server creates the order (one key per Pay intent, reused on
/// retry) → SDK checkout → ALWAYS confirm with the server, polling with
/// backoff while pending. Diamonds shown come from the server only.
// Not final: page tests mock the bloc.
class PurchaseBloc extends Bloc<PurchaseEvent, PurchaseState> {
  PurchaseBloc(
    this._load,
    this._start,
    this._watch,
    this._verify, {
    required GetClientRails clientRails,
    required CreateCashfreeOrder createCashfreeOrder,
    required GetCashfreeOrder getCashfreeOrder,
    required OpenCashfreeCheckout openCashfreeCheckout,
    ConfirmSchedule schedule = const ConfirmSchedule(),
    Sleep? sleep,
  }) : _clientRails = clientRails,
       _createOrder = createCashfreeOrder,
       _getOrder = getCashfreeOrder,
       _openCheckout = openCashfreeCheckout,
       _schedule = schedule,
       _sleep = sleep ?? Future<void>.delayed,
       super(const PurchaseState()) {
    on<PurchasePackagesRequested>(_onPackagesRequested);
    on<PurchasePackageHighlighted>(
      (e, emit) => emit(state.copyWith(selectedProductId: e.productId)),
    );
    on<PurchasePackageSelected>(_onPackageSelected);
    on<PurchaseCashfreeRequested>(_onCashfreeRequested);
    on<PurchaseStoreUpdated>(_onStoreUpdated);
    on<PurchaseVerificationRetried>(_onVerificationRetried);
    _subscription = _watch(
      const NoInput(),
    ).listen((u) => add(PurchaseStoreUpdated(u)));
  }

  final LoadDiamondPackages _load;
  final StartPurchase _start;
  final WatchPurchaseUpdates _watch;
  final VerifyPurchase _verify;
  final GetClientRails _clientRails;
  final CreateCashfreeOrder _createOrder;
  final GetCashfreeOrder _getOrder;
  final OpenCashfreeCheckout _openCheckout;
  final ConfirmSchedule _schedule;
  final Sleep _sleep;
  late final StreamSubscription<PurchaseUpdate> _subscription;

  final Map<String, IdempotencyKey> _keysByToken = {};

  /// One key per Cashfree "Pay" intent, kept until the order exists.
  final Map<String, IdempotencyKey> _cashfreeKeys = {};
  PurchaseNeedsVerification? _lastPlayPurchase;

  Future<void> _onPackagesRequested(
    PurchasePackagesRequested e,
    Emitter<PurchaseState> emit,
  ) async {
    emit(state.copyWith(status: PurchaseStatus.loading));
    final (catalogue, client) = await (
      _load(const NoInput()),
      _clientRails(const NoInput()),
    ).wait;
    switch (catalogue) {
      case Err(:final failure):
        emit(state.copyWith(status: PurchaseStatus.failed, failure: failure));
      case Success(:final value):
        final clientRails = client.fold(
          onSuccess: (r) => r,
          onFailure: (_) => const <PaymentRail>{},
        );
        final preferred =
            e.productId ??
            state.selectedProductId ??
            _defaultSelection(value.packages);
        emit(
          state.copyWith(
            status: PurchaseStatus.ready,
            packages: value.packages,
            serverRails: value.rails,
            rails: value.rails.intersection(clientRails),
            currentBalance: value.currentBalance,
            selectedProductId: preferred,
          ),
        );
    }
  }

  static String? _defaultSelection(List<DiamondPackage> packages) {
    for (final p in packages) {
      if (p.badge != null) return p.productId;
    }
    return packages.isEmpty ? null : packages.first.productId;
  }

  Future<void> _onPackageSelected(
    PurchasePackageSelected e,
    Emitter<PurchaseState> emit,
  ) async {
    if (state.status != PurchaseStatus.initial &&
        !state.rails.contains(PaymentRail.googlePlay)) {
      emit(
        state.copyWith(
          status: PurchaseStatus.failed,
          failure: const PlatformFailure(code: 'billing_unavailable'),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: PurchaseStatus.inStore,
        selectedProductId: e.productId,
      ),
    );
    final result = await _start(e.productId);
    if (result case Err(:final failure)) {
      emit(state.copyWith(status: PurchaseStatus.failed, failure: failure));
    }
  }

  Future<void> _onStoreUpdated(
    PurchaseStoreUpdated e,
    Emitter<PurchaseState> emit,
  ) async {
    switch (e.update) {
      case PurchasePending(:final productId):
        emit(
          state.copyWith(
            status: PurchaseStatus.pendingPayment,
            result: PaymentResult(
              rail: PaymentRail.googlePlay,
              outcome: PaymentOutcome.pending,
              orderId: '',
              productId: productId,
              diamonds: _diamondsOf(productId),
              amountPaise: _priceOf(productId),
            ),
          ),
        );
      case PurchaseCancelled():
        emit(state.copyWith(status: PurchaseStatus.ready));
      case PurchaseStoreError(:final code):
        emit(
          state.copyWith(
            status: PurchaseStatus.failed,
            failure: PlatformFailure(code: code),
          ),
        );
      case final PurchaseNeedsVerification p:
        _lastPlayPurchase = p;
        await _verifyPlay(p, emit);
    }
  }

  Future<void> _onVerificationRetried(
    PurchaseVerificationRetried e,
    Emitter<PurchaseState> emit,
  ) async {
    final p = _lastPlayPurchase;
    if (p != null) await _verifyPlay(p, emit);
  }

  Future<void> _verifyPlay(
    PurchaseNeedsVerification p,
    Emitter<PurchaseState> emit,
  ) async {
    emit(state.copyWith(status: PurchaseStatus.verifying));
    final key = _keysByToken.putIfAbsent(
      p.purchaseToken,
      IdempotencyKey.generate,
    );
    final result = await _verify((purchase: p, key: key));
    switch (result) {
      case Success(:final value):
        emit(
          state.copyWith(
            status: PurchaseStatus.completed,
            lastVerification: value,
            result: PaymentResult(
              rail: PaymentRail.googlePlay,
              outcome: switch (value.status) {
                'credited' => PaymentOutcome.success,
                'pending' => PaymentOutcome.pending,
                _ => PaymentOutcome.failed,
              },
              orderId: value.purchaseId,
              productId: p.productId,
              diamonds: _diamondsOf(p.productId),
              diamondsCredited: value.diamondsCredited,
              amountPaise: _priceOf(p.productId),
              failureCode: value.status == 'rejected'
                  ? 'purchase_rejected'
                  : null,
            ),
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            status: PurchaseStatus.failed,
            failure: failure,
            canRetryVerification: true,
          ),
        );
    }
  }

  Future<void> _onCashfreeRequested(
    PurchaseCashfreeRequested e,
    Emitter<PurchaseState> emit,
  ) async {
    if (!state.rails.contains(PaymentRail.cashfree)) {
      emit(
        state.copyWith(
          status: PurchaseStatus.failed,
          failure: const ServerFailure(code: 'rail_disabled'),
        ),
      );
      return;
    }
    final key = _cashfreeKeys.putIfAbsent(e.productId, IdempotencyKey.generate);
    emit(
      state.copyWith(
        status: PurchaseStatus.creatingOrder,
        selectedProductId: e.productId,
      ),
    );
    final created = await _createOrder((productId: e.productId, key: key));
    final CashfreeOrder order;
    switch (created) {
      case Err(:final failure):
        // Keep the key: tapping Pay again replays the same order request.
        emit(state.copyWith(status: PurchaseStatus.failed, failure: failure));
        return;
      case Success(:final value):
        order = value;
        _cashfreeKeys.remove(e.productId);
    }
    emit(
      state.copyWith(status: PurchaseStatus.inCashfree, cashfreeOrder: order),
    );
    final opened = await _openCheckout(order);
    final outcome = opened.fold<CashfreeCheckoutOutcome>(
      onSuccess: (o) => o,
      onFailure: (f) => CashfreeCheckoutFailed(f.code),
    );
    if (isClosed) return;
    emit(state.copyWith(status: PurchaseStatus.confirming));
    final result = await _confirm(order, outcome);
    if (result == null) return; // bloc closed while polling
    emit(state.copyWith(status: PurchaseStatus.completed, result: result));
  }

  /// Asks the server for the verdict, polling with backoff while pending.
  Future<PaymentResult?> _confirm(
    CashfreeOrder order,
    CashfreeCheckoutOutcome outcome,
  ) async {
    final sdkCode = switch (outcome) {
      CashfreeCheckoutSucceeded() => null,
      CashfreeCheckoutDismissed() => 'payment_cancelled',
      CashfreeCheckoutFailed(:final code) => code,
    };
    var latest = order;
    var elapsed = Duration.zero;
    for (var attempt = 0; ; attempt++) {
      if (isClosed) return null;
      final r = await _getOrder(order.orderId);
      if (r case Success(:final value)) {
        latest = value;
        if (value.state.isFinal) {
          return PaymentResult.fromCashfreeOrder(
            value,
            fallbackFailureCode: sdkCode,
          );
        }
        // Never paid and the checkout ended without success: nothing to wait for.
        if (value.state == CashfreeOrderState.created && sdkCode != null) {
          return PaymentResult.fromCashfreeOrder(
            value,
          ).copyWith(outcome: PaymentOutcome.failed, failureCode: sdkCode);
        }
      }
      if (elapsed >= _schedule.budget) break;
      final delay = _schedule.delayFor(attempt);
      await _sleep(delay);
      elapsed += delay;
    }
    return PaymentResult.fromCashfreeOrder(
      latest,
    ).copyWith(outcome: PaymentOutcome.pending);
  }

  int? _diamondsOf(String productId) {
    for (final p in state.packages) {
      if (p.productId == productId) return p.diamonds;
    }
    return null;
  }

  int? _priceOf(String productId) {
    for (final p in state.packages) {
      if (p.productId == productId) return p.pricePaise;
    }
    return null;
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
