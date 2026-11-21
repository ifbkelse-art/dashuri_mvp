import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/diamond_package.dart';
import '../domain/entities/purchase_update.dart';
import '../domain/entities/purchase_verification.dart';
import '../domain/usecases/load_diamond_packages.dart';
import '../domain/usecases/start_purchase.dart';
import '../domain/usecases/verify_purchase.dart';
import '../domain/usecases/watch_purchase_updates.dart';

part 'purchase_event.dart';
part 'purchase_state.dart';

/// Buy-Diamonds flow: load packages → launch Play sheet → receive Play
/// update → server verification → show the server's result.
/// One idempotency key per purchase token, reused on retry.
final class PurchaseBloc extends Bloc<PurchaseEvent, PurchaseState> {
  PurchaseBloc(this._load, this._start, this._watch, this._verify)
    : super(const PurchaseState()) {
    on<PurchasePackagesRequested>(_onPackagesRequested);
    on<PurchasePackageSelected>(_onPackageSelected);
    on<PurchaseStoreUpdated>(_onStoreUpdated);
    _subscription = _watch(
      const NoInput(),
    ).listen((u) => add(PurchaseStoreUpdated(u)));
  }

  final LoadDiamondPackages _load;
  final StartPurchase _start;
  final WatchPurchaseUpdates _watch;
  final VerifyPurchase _verify;
  late final StreamSubscription<PurchaseUpdate> _subscription;
  final Map<String, IdempotencyKey> _keysByToken = {};

  Future<void> _onPackagesRequested(
    PurchasePackagesRequested e,
    Emitter<PurchaseState> emit,
  ) async {
    emit(state.copyWith(status: PurchaseStatus.loading));
    final result = await _load(const NoInput());
    emit(switch (result) {
      Success(:final value) => state.copyWith(
        status: PurchaseStatus.ready,
        packages: value,
      ),
      Err(:final failure) => state.copyWith(
        status: PurchaseStatus.failed,
        failure: failure,
      ),
    });
  }

  Future<void> _onPackageSelected(
    PurchasePackageSelected e,
    Emitter<PurchaseState> emit,
  ) async {
    emit(state.copyWith(status: PurchaseStatus.inStore));
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
      case PurchasePending():
        emit(state.copyWith(status: PurchaseStatus.pendingPayment));
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
        emit(state.copyWith(status: PurchaseStatus.verifying));
        final key = _keysByToken.putIfAbsent(
          p.purchaseToken,
          IdempotencyKey.generate,
        );
        final result = await _verify((purchase: p, key: key));
        emit(switch (result) {
          Success(:final value) => state.copyWith(
            status: PurchaseStatus.completed,
            lastVerification: value,
          ),
          Err(:final failure) => state.copyWith(
            status: PurchaseStatus.failed,
            failure: failure,
          ),
        });
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
