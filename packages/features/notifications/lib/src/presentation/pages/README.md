# notifications pages (founder-owned)

Put this feature's pages here, one file per page, then register each in `lib/src/routes/notifications_routes.dart`.

Planned pages:
- NotificationsPage (RoutePaths.notifications)

Rules: pages read state with `BlocBuilder`/`BlocListener` from the cubits in `lib/src/application/`, use `dashuri_design_system` for styling, and never import `data/` or `dashuri_network`.
