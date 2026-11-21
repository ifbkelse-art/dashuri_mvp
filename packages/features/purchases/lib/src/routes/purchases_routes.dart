import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../application/payment_result_cubit.dart';
import '../application/purchase_bloc.dart';
import '../domain/entities/payment_rail.dart';
import '../domain/entities/payment_result.dart';
import '../presentation/pages/buy_diamonds_page.dart';
import '../presentation/pages/checkout_page.dart';
import '../presentation/pages/payment_result_page.dart';

/// W02 packages (`?rate=&host=` for the talk-time hint), W03/W04 checkout
/// (`?rail=google_play|cashfree` to skip the rail sheet) and W05–W07 results.
final class PurchasesRoutes implements FeatureRoutes {
  const PurchasesRoutes();

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: RoutePaths.buyDiamonds,
      builder: (context, state) {
        final q = state.uri.queryParameters;
        return BlocProvider(
          create: (_) =>
              GetIt.instance<PurchaseBloc>()
                ..add(const PurchasePackagesRequested()),
          child: BuyDiamondsPage(
            ratePerMinute: int.tryParse(q['rate'] ?? ''),
            hostName: q['host'],
          ),
        );
      },
    ),
    GoRoute(
      path: RoutePaths.checkout,
      builder: (context, state) {
        final productId = state.pathParameters['productId']!;
        final rail = PaymentRail.fromWire(
          state.uri.queryParameters['rail'] ?? '',
        );
        return BlocProvider(
          create: (_) =>
              GetIt.instance<PurchaseBloc>()
                ..add(PurchasePackagesRequested(productId: productId)),
          child: CheckoutPage(productId: productId, preferredRail: rail),
        );
      },
    ),
    GoRoute(
      path: RoutePaths.paymentResult,
      builder: (context, state) {
        final orderId = state.pathParameters['orderId']!;
        final extra = state.extra;
        return BlocProvider(
          create: (_) => PaymentResultCubit(
            GetIt.instance(),
            orderId: orderId,
            result: extra is PaymentResult ? extra : null,
          )..load(),
          child: const PaymentResultPage(),
        );
      },
    ),
  ];
}
