/// Diamond purchases on two rails (Google Play Billing by default, Cashfree
/// PG behind a flag) with server verification. The app never credits Diamonds.
library;

export 'src/application/payment_result_cubit.dart';
export 'src/application/purchase_bloc.dart';
export 'src/data/datasources/store_billing.dart';
export 'src/di/purchases_module.dart';
export 'src/domain/entities/cashfree_checkout_outcome.dart';
export 'src/domain/entities/cashfree_order.dart';
export 'src/domain/entities/diamond_package.dart';
export 'src/domain/entities/package_catalogue.dart';
export 'src/domain/entities/payment_rail.dart';
export 'src/domain/entities/payment_result.dart';
export 'src/domain/entities/purchase_update.dart';
export 'src/domain/entities/purchase_verification.dart';
export 'src/domain/ports/cashfree_checkout.dart';
export 'src/domain/repositories/purchases_repository.dart';
export 'src/domain/usecases/cashfree_orders.dart';
export 'src/domain/usecases/get_client_rails.dart';
export 'src/domain/usecases/load_diamond_packages.dart';
export 'src/domain/usecases/start_purchase.dart';
export 'src/domain/usecases/verify_purchase.dart';
export 'src/domain/usecases/watch_purchase_updates.dart';
export 'src/presentation/pages/buy_diamonds_page.dart';
export 'src/presentation/pages/checkout_page.dart';
export 'src/presentation/pages/payment_result_page.dart';
export 'src/routes/purchases_routes.dart';
