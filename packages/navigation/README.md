# dashuri_navigation

- `RoutePaths`: every path in the app. Navigate with `context.go(RoutePaths.wallet)`.
- `FeatureRoutes`: each feature returns its `GoRoute`s; `apps/mobile` composes them into one `GoRouter`.
- `RouteGuard`: redirect contract implemented by the app (signed out → sign-in; not age-eligible → age gate).
