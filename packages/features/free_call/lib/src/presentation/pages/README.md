# free_call pages (founder-owned)

Put this feature's pages here, one file per page, then register each in `lib/src/routes/free_call_routes.dart`.

Planned pages:
- FreeCallPage (RoutePaths.freeCall)

Rules: pages read state with `BlocBuilder`/`BlocListener` from the cubits in `lib/src/application/`, use `dashuri_design_system` for styling, and never import `data/` or `dashuri_network`.
