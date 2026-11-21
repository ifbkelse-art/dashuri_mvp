import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfexceptions.dart';

import '../../domain/entities/cashfree_checkout_outcome.dart';
import '../../domain/entities/cashfree_order.dart';
import '../../domain/ports/cashfree_checkout.dart';

/// Cashfree PG checkout through `flutter_cashfree_pg_sdk` (Web Checkout,
/// which offers UPI intent, cards and net banking in Cashfree's own UI).
///
/// Uses `CFSessionBuilder` with the server's `payment_session_id`, order id
/// and environment, then `CFPaymentGatewayService().doPayment(...)`. The SDK
/// reports through two global callbacks: `verifyPayment(orderId)` and
/// `onError(CFErrorResponse, orderId)`. Neither credits anything: the caller
/// always confirms the order with the server.
final class CashfreeSdkCheckout implements CashfreeCheckout {
  CashfreeSdkCheckout({CFPaymentGatewayService? service})
    : _service = service ?? CFPaymentGatewayService();

  final CFPaymentGatewayService _service;

  /// Error codes the SDK uses when the user backs out of the checkout.
  static const _dismissCodes = {
    'action_cancelled',
    'payment_cancelled',
    'user_dropped',
    'user_cancelled',
  };

  @override
  Future<CashfreeCheckoutOutcome> open(CashfreeOrder order) async {
    final sessionId = order.paymentSessionId;
    if (sessionId == null || sessionId.isEmpty) {
      return const CashfreeCheckoutFailed('payment_session_missing');
    }
    final completer = Completer<CashfreeCheckoutOutcome>();
    void finish(CashfreeCheckoutOutcome o) {
      if (!completer.isCompleted) completer.complete(o);
    }

    try {
      final session = CFSessionBuilder()
          .setEnvironment(
            order.environment == 'production'
                ? CFEnvironment.PRODUCTION
                : CFEnvironment.SANDBOX,
          )
          .setOrderId(order.orderId)
          .setPaymentSessionId(sessionId)
          .build();
      final payment = CFWebCheckoutPaymentBuilder().setSession(session).build();
      _service.setCallback(
        (orderId) => finish(const CashfreeCheckoutSucceeded()),
        (CFErrorResponse error, String orderId) {
          final code = (error.getCode() ?? 'payment_failed').toLowerCase();
          finish(
            _dismissCodes.contains(code)
                ? const CashfreeCheckoutDismissed()
                : CashfreeCheckoutFailed(code, message: error.getMessage()),
          );
        },
      );
      _service.doPayment(payment);
    } on CFException catch (e) {
      finish(CashfreeCheckoutFailed('checkout_unavailable', message: '$e'));
    } on PlatformException catch (e) {
      finish(CashfreeCheckoutFailed(e.code, message: e.message));
    } on MissingPluginException {
      finish(const CashfreeCheckoutFailed('checkout_unavailable'));
    }
    return completer.future;
  }
}
