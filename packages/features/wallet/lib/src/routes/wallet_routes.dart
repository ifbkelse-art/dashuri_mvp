import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../application/sent_gifts_cubit.dart';
import '../application/transaction_detail_cubit.dart';
import '../application/wallet_cubit.dart';
import '../application/wallet_history_cubit.dart';
import '../di/wallet_module.dart';
import '../domain/entities/wallet_entry.dart';
import '../domain/usecases/list_sent_gifts.dart';
import '../presentation/pages/sent_gifts_page.dart';
import '../presentation/pages/transaction_detail_page.dart';
import '../presentation/pages/transaction_history_page.dart';
import '../presentation/pages/wallet_page.dart';

/// Wallet routes. [tabRoutes] is the W01 tab (inside the customer shell);
/// [routes] are the full-screen W08/W09 pages.
final class WalletRoutes implements TabFeatureRoutes {
  const WalletRoutes();

  @override
  List<RouteBase> get tabRoutes => [
    GoRoute(
      path: RoutePaths.wallet,
      builder: (context, state) => BlocProvider(
        create: (_) => GetIt.instance<WalletCubit>()..load(),
        child: WalletPage(
          onGiftsSent: GetIt.instance.isRegistered<WalletGiftsEnabled>()
              ? () => context.push(RoutePaths.giftsSent)
              : null,
        ),
      ),
    ),
  ];

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: RoutePaths.giftsSent,
      builder: (context, state) => BlocProvider(
        create: (_) => GetIt.instance<SentGiftsCubit>()..load(),
        child: const SentGiftsPage(),
      ),
    ),
    GoRoute(
      path: RoutePaths.transactions,
      builder: (context, state) => BlocProvider(
        create: (_) => GetIt.instance<WalletHistoryCubit>()..load(),
        child: const TransactionHistoryPage(),
      ),
    ),
    GoRoute(
      path: RoutePaths.transactionDetail,
      builder: (context, state) {
        final id = state.pathParameters['entryId']!;
        final extra = state.extra;
        return BlocProvider(
          create: (_) => TransactionDetailCubit(
            GetIt.instance(),
            listGifts: GetIt.instance<ListSentGifts>(),
            entryId: id,
            entry: extra is WalletEntry && extra.id == id ? extra : null,
          )..load(),
          child: const TransactionDetailPage(),
        );
      },
    ),
  ];
}
