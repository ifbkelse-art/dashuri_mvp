# wallet pages (founder-owned)

Put this feature's pages here, one file per page, then register each in `lib/src/routes/wallet_routes.dart`.

Planned pages:
- WalletPage (RoutePaths.wallet)
- Transaction history section

Rules: pages read state with `BlocBuilder`/`BlocListener` from the cubits in `lib/src/application/`, use `dashuri_design_system` for styling, and never import `data/` or `dashuri_network`.
