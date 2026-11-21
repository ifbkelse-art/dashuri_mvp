# auth pages (founder-owned)

Planned pages:
- SplashPage (RoutePaths.splash): shown while `SessionCubit` is `SessionUnknown`
- SignInPage (RoutePaths.signIn): phone entry and OTP entry, driven by `SignInCubit.step`

The age gate page lives in the safety feature. Route redirects come from the app's `RouteGuard`, which reads `SessionCubit`.
