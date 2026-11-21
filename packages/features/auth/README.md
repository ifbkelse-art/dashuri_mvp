# feature_auth

Phone OTP sign-in (Supabase Auth through the core `SessionGateway`), the app-wide `SessionCubit`, and account status from `GET /v1/me`.

| Layer | Contents |
|---|---|
| Domain | `AccountStatus`; `AuthRepository`; `RequestOtp`, `VerifyOtp`, `GetAccountStatus`, `SignOut`, `WatchSession` |
| Data | `AuthRepositoryImpl` (SessionGateway + `AccountRemoteDataSource`) |
| Application | `SessionCubit` (singleton, drives route guards), `SignInCubit` (per page) |
| Presentation | founder-owned: splash and sign-in pages |

Notes:
- The auth feature never imports Supabase; the adapter lives in `packages/supabase`.
- Eligibility (18+, host role, restrictions) comes from the Go API, not token claims.
- The SMS provider for Supabase phone auth (DLT-registered templates in India) is not configured yet.
