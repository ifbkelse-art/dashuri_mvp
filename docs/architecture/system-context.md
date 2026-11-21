# System context and trust boundaries

## Actors

| Actor | Uses | Trust |
|---|---|---|
| Customer (18+) | Android app: browse, buy Diamonds, call, chat, report | Untrusted |
| Host (18+, KYC-verified) | Android app: availability, rate, calls, earnings, withdrawals | Untrusted; identity verified |
| Moderator / admin / finance staff | Admin API (`/v1/admin/*`), with an internal tool to be built later | Trusted per role; every action is audit-logged |
| Founder | Owns pages, product decisions | — |

## External systems

| System | Direction | Purpose | Status |
|---|---|---|---|
| Supabase Auth | App ↔ | Phone OTP sign-in; issues JWTs verified by the API | Chosen; SMS/DLT setup pending |
| Supabase Postgres | API ↔ | System of record | Chosen |
| Supabase Realtime | API → App | Server-to-client events on private channels | Chosen (ADR-006) |
| Supabase Storage | App ↔ (signed URLs) | Profile photos, moderation evidence | Chosen |
| Google Play Billing | App ↔ | Diamond purchases (required for digital goods) | Required by policy |
| Google Play Developer API + RTDN (Pub/Sub) | API ↔ | Purchase verification, refunds and voided purchases | Required |
| Stream Video | App ↔ media; API ↔ tokens and webhooks | 1:1 video | **Pending validation (ADR-005)** |
| Payout provider | API → | Weekly host payouts | **Not chosen; launch blocker for payouts** |
| KYC vendor | App → vendor; vendor → API | Host identity and age verification | Not chosen |
| Nudity-detection vendor | API → | First-3-minute frame checks (S7) | Not chosen; prices UNVERIFIED |
| FCM | API → App | Push notifications (incoming calls, payouts) | Not wired |
| Play Integrity | App → API → Google | Device binding for the Free Call Card | Not wired |

## Trust boundaries

1. **Device → API.** Everything from the app is untrusted input. The API authenticates the JWT, loads roles from its own database, validates every body, and ignores any client-computed money or time.
2. **Device → Supabase.** The app holds only the publishable key. Database grants and RLS give anon and authenticated users no access to domain tables. Realtime policies allow receiving only on the user's own channels. Storage uses short-lived signed URLs issued by the API.
3. **Providers → API.** Webhooks must pass signature or OIDC verification before any processing, and are deduplicated by event id.
4. **API → database.** The API connects as `api_service`, which can insert but never update or delete ledger history. Triggers and constraints enforce the invariants even if application code is wrong.
5. **Staff → API.** Role-gated endpoints, dual control for ledger adjustments, separate approver for appeals, append-only audit log.
