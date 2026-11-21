# ADR-001: Melos monorepo on pub workspaces

- **Status:** Accepted, 2026-11-17

## Context
The founder will build 50–100+ screens across many feature areas. Features must evolve independently but share contracts, design tokens and lint rules, with one command to analyse and test everything. Melos 8 (installed: 8.9.0) is built on Dart pub workspaces. **`melos.yaml` no longer exists:** configuration lives under `melos:` in the root `pubspec.yaml`, and each package declares `resolution: workspace`.

## Decision
- One repository holding `apps/mobile`, `packages/*` (shared), `packages/features/*`, `backend/` (Go), `supabase/`, `api/`, `docs/`.
- Dart side: a pub workspace (one lockfile, one dependency resolution) with Melos scripts: `analyze`, `format:check`, `test`, `test:dart`, `test:flutter`, `deps:check`, `new:feature`.
- Internal packages reference each other with `path:` dependencies.

## Alternatives
- **Separate repositories per package:** versioning overhead with no benefit for a solo founder.
- **Single Flutter package with folders:** no enforceable boundaries; slower analysis; features leak into each other.
- **Melos 6 with `melos.yaml` and pubspec overrides:** deprecated.

## Trade-offs
One lockfile means one version of each dependency across all features, which is simpler, but an upgrade touches everything. The workspace list in the root pubspec must be updated when adding a package (`tool/new_feature.dart` prints the step).

## Future
Workspace globs (Dart ≥ 3.11) could replace the explicit list. The backend can move to its own repository without changes, since it shares only `api/openapi`.
