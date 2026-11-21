# Page integration guide (for the founder)

You own every page. The architecture gives each page a BLoC, a route slot and design tokens. Nothing visual was invented.

## Where pages go

| Page | Package / folder | Route constant | BLoC / Cubit to use |
|---|---|---|---|
| Splash | `features/auth/lib/src/presentation/pages/` | `RoutePaths.splash` | `SessionCubit` (already provided app-wide) |
| Sign in (phone + OTP) | `features/auth/.../pages/` | `signIn` | `SignInCubit` |
| Age gate | `features/safety/.../pages/` | `ageGate` | add `AgeGateCubit` using `SubmitAgeDeclaration` |
| Discover hosts | `features/discovery/.../pages/` | `discovery` | `DiscoveryCubit` |
| Host public profile | `features/profile/.../pages/` | `hostProfile` | add `PublicProfileCubit` using `GetProfile` |
| Free Call | `features/free_call/.../pages/` | `freeCall` | `FreeCallCardCubit` (+ `RequestFreeCall`) |
| Call screen / incoming call | `features/video_call/.../pages/` | `call` | `CallBloc` |
| Conversations / chat | `features/chat/.../pages/` | `conversations`, `conversation` | `ConversationsCubit` (+ add `MessagesCubit`) |
| Wallet | `features/wallet/.../pages/` | `wallet` | `WalletCubit` |
| Buy Diamonds | `features/purchases/.../pages/` | `buyDiamonds` | `PurchaseBloc` |
| My profile / edit | `features/profile/.../pages/` | `myProfile`, `editProfile` | `MyProfileCubit` |
| Host dashboard / earnings / withdraw | `features/host/.../pages/` | `hostDashboard`, `hostEarnings`, `hostWithdraw` | `HostDashboardCubit` (+ cubits for earnings and withdrawal) |
| Report, blocked users, enforcement, appeal | `features/safety/.../pages/` | `report`, `blockedUsers` | `BlockedUsersCubit` (+ report/appeal cubits) |
| Notifications | `features/notifications/.../pages/` | `notifications` | `InboxCubit` |
| Settings | `features/settings/.../pages/` | `settings` | `SettingsCubit` |

Each `presentation/pages/README.md` lists that feature's planned pages and the rules specific to it.

## Wiring one page (example: Wallet)

1. Create `packages/features/wallet/lib/src/presentation/pages/wallet_page.dart`:

```dart
import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/wallet_cubit.dart';

class WalletPage extends StatelessWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WalletCubit, WalletState>(
      builder: (context, state) => switch (state) {
        WalletStateInitial() || WalletStateLoading() => const CircularProgressIndicator(),
        WalletStateLoaded(:final data) => Text('${data.availableDiamonds}'), // your design here
        WalletStateFailed(:final failure) => Text(failure.code),           // your error UI
      },
    );
  }
}
```

2. Register the route in `lib/src/routes/wallet_routes.dart`:

```dart
@override
List<RouteBase> get routes => [
      GoRoute(
        path: RoutePaths.wallet,
        builder: (context, state) => BlocProvider(
          create: (_) => GetIt.instance<WalletCubit>()..load(),
          child: const WalletPage(),
        ),
      ),
    ];
```

   Add `flutter_bloc` and `get_it` imports in the routes file. Route builders are the one place outside DI where `GetIt` is used.

3. Navigate from anywhere with `context.go(RoutePaths.wallet)` or `context.push(...)`. To open another feature's page, use its `RoutePaths` constant; never import the other feature.

4. Run `melos run analyze && melos run deps:check && melos run test`.

## Rules for pages

- Read state with `BlocBuilder`, `BlocListener` or `BlocSelector`; dispatch with `context.read<X>().method()` or `.add(Event())`.
- Styling comes from `Theme.of(context)` and `DashuriTokens`. Put reusable widgets in `dashuri_design_system/lib/src/components/`.
- Pages never import `data/`, `dashuri_network` or `get_it` (checked automatically).
- **Money and time shown on screen come from the server.** Show `CallSession.diamondsCharged` and `billedSeconds`, `WalletSummary`, `PurchaseVerification.diamondsCredited`. Never compute charges, Beans or XP in a widget.
- A rate shown before a call is `HostCard.ratePerMinute` (Diamonds per minute). Converting it to rupees for display is fine, labelled as approximate.
- Hide the Free Call Card on iOS (`defaultTargetPlatform == TargetPlatform.iOS`).
