# safety pages (founder-owned)

Put this feature's pages here, one file per page, then register each in `lib/src/routes/safety_routes.dart`.

Planned pages:
- ReportSheet (RoutePaths.report, also opened from the call screen)
- BlockedUsersPage (RoutePaths.blockedUsers)
- AgeGatePage (RoutePaths.ageGate)
- Enforcement notice and appeal pages

Rules: pages read state with `BlocBuilder`/`BlocListener` from the cubits in `lib/src/application/`, use `dashuri_design_system` for styling, and never import `data/` or `dashuri_network`.
