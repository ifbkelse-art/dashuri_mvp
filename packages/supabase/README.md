# dashuri_supabase

The only package allowed to import `supabase_flutter` (enforced by `melos run deps:check`).

| Adapter | Implements | Used for |
|---|---|---|
| `SupabaseSessionGateway` | `SessionGateway` (core), `AccessTokenProvider` (network) | Phone OTP sign-in, session stream, access token for the Go API |
| `SupabaseRealtimeGateway` | `RealtimeGateway` (network) | Private broadcast channels the Go backend publishes to |
| `initSupabase` | — | Startup with the publishable key only |

The client never queries financial, call, moderation or payout tables directly. See `docs/architecture/database-architecture.md`.
