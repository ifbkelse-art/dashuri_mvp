# Shared components

Put reusable widgets here once two or more features need them: buttons, rate badges, Diamond and Bean amount labels, level badges, empty/error/loading states.

Rules:
- Components take data and callbacks as parameters. No BLoCs, repositories or `GetIt` lookups inside them.
- Style comes from `Theme.of(context)` and `DashuriTokens`.
- Export each component from `lib/dashuri_design_system.dart`.
- Add a widget test in `test/components/` for every component.
