# ADR-002: Clean Architecture per feature, BLoC for state

- **Status:** Accepted, 2026-11-17

## Context
The founder owns the presentation layer and will write it independently. Business rules (money, eligibility, safety) must not end up in widgets. External services (Supabase, Play Billing, the video SDK) may change.

## Decision
- Each feature has four layers: domain (entities, repository contracts, use cases, ports), data (data sources, mappers, repository implementations, adapters), application (BLoC/Cubit), presentation (pages, widgets).
- Repositories and use cases return `Result<T>` with sealed `Failure`s.
- `get_it` composition happens only in the app; each feature exposes `registerXFeature`.
- `go_router` routes are contributed per feature through `FeatureRoutes`.
- Rules are enforced by `tool/check_dependencies.dart`.

## Alternatives
- **Riverpod:** capable, but BLoC was the founder's stated choice and suits event-driven flows (calls, purchases).
- **Code generation (`injectable`, `freezed`, `json_serializable`):** fewer handwritten lines, but adds build_runner to every package. Deferred; it can be adopted per package later without changing the boundaries.
- **No use-case layer:** thinner, but BLoCs would grow repository orchestration. Use cases also give each action one place for idempotency-key handling.

## Trade-offs
More files per feature, offset by the generator and consistent structure. Use cases are non-final classes so tests can mock them.

## Future
Use cases can gain caching or offline behaviour in repositories without touching BLoCs or pages.
