# profile pages (founder-owned)

Put this feature's pages here, one file per page, then register each in `lib/src/routes/profile_routes.dart`.

Planned pages:
- MyProfilePage (RoutePaths.myProfile)
- EditProfilePage (RoutePaths.editProfile)
- PublicProfilePage (RoutePaths.hostProfile)

Rules: pages read state with `BlocBuilder`/`BlocListener` from the cubits in `lib/src/application/`, use `dashuri_design_system` for styling, and never import `data/` or `dashuri_network`.
