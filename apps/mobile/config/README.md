# App configuration

Copy `<env>.example.json` to `<env>.json` (git-ignored) and fill in values, then run:

```sh
flutter run -t lib/main_development.dart --dart-define-from-file=config/development.json
```

Only client-safe values belong here: API base URL, Supabase URL, Supabase **publishable** key. Never put the Supabase service-role key, Google Play service-account JSON, video-provider secrets or payout credentials in the app.
