# host pages (founder-owned)

Put this feature's pages here, one file per page, then register each in `lib/src/routes/host_routes.dart`.

Planned pages:
- HostDashboardPage (RoutePaths.hostDashboard)
- HostEarningsPage (RoutePaths.hostEarnings)
- WithdrawPage (RoutePaths.hostWithdraw)
- Host application / KYC flow

Rules: pages read state with `BlocBuilder`/`BlocListener` from the cubits in `lib/src/application/`, use `dashuri_design_system` for styling, and never import `data/` or `dashuri_network`.
