# Verified Host and level-based Diamond pricing (2026-11-23)

Founder spec "DASHURI — VERIFIED HOST SYSTEM & LEVEL-BASED DIAMOND PRICING", as built. Decision record: ADR-014. Migration: `supabase/migrations/20261123000300_verified_hosts_and_level_pricing.sql`. Rule set: `2026-11-23-verified-pricing`.

## 1. Two separate statuses

| | Hosting approval (existing) | Verified Host (new) |
|---|---|---|
| Purpose | May host at all | Premium trust badge; unlocks prices above 3,000 D/min |
| Evidence | Manual KYC: age and identity (moderator decision) | Face video + ID document image, reviewed by staff |
| Stored in | `hosting.hosts.state`, `kyc_state` | `hosting.hosts.verification_status`, `hosting.verification_applications` |
| API flag | `HostStatus.state = approved` | `is_verified` on HostCard, call peer, chat peer, HostStatus |

**Behaviour change:** before 2026-11-23, `HostCard.is_verified` meant "hosting KYC approved", which was true for every listed host. It now means **ACTIVE Verified Host**. No existing host was made Verified; every host starts as Non-Verified.

## 2. Pricing rules

All prices are integer Diamonds per minute.

| Rule | Value |
|---|---|
| Minimum, every host | 500 |
| Maximum for a level | level × 1,000 (levels 1–10, so 1,000 to 10,000) |
| Above 3,000 | Only for an **active** Verified Host (`verification_status = verified`; suspended, revoked and the rest do not count) |
| Fractions | Refused: `rate_per_minute: must_be_integer` (422) |

| Level | Non-Verified max | Verified max |
|---|---|---|
| 1 | 1,000 | 1,000 |
| 2 | 2,000 | 2,000 |
| 3 | 3,000 | 3,000 |
| 4 | 3,000 | 4,000 |
| 5 | 3,000 | 5,000 |
| 6 | 3,000 | 6,000 |
| 7 | 3,000 | 7,000 |
| 8 | 3,000 | 8,000 |
| 9 | 3,000 | 9,000 |
| 10 | 3,000 | 10,000 |

Code: `economy.Rules.LevelMaxRate`, `EligibleMaxRate`, `CheckRate`, `CapRate` (`backend/internal/modules/economy/rules.go`). The level thresholds are still the P12 proposal (unresolved, D-16).

### Where the server enforces it

The Go API is the only authority. It never takes a level, a verification status or a price eligibility from the client: the request accepts only `rate_per_minute`, and unknown fields are refused.

| Point | What happens | Atomicity |
|---|---|---|
| `PUT /v1/host/rate` | Checks min, level max and the 3,000 threshold, in that order. Errors: `rate_below_minimum`, `rate_outside_level_limits`, `verification_required_for_rate` | Host row `FOR UPDATE`; level (from `ledger.user_xp`) and status are read in the same transaction |
| Verification suspend or revoke | Caps the stored price at min(3,000, level max) and audits it as `host.rate_capped` | Same transaction as the status change |
| Level drop (purchase reversal, the only path that lowers XP) | Caps the stored price at the new eligibility | Same transaction as the negative XP event |
| Call creation | If the stored price is above current eligibility, caps and persists it **before** snapshotting the call rate | Under the existing host row lock |
| Discovery | Exposes `min(stored, eligible)` | Read-only |
| Database | `CHECK (rate_per_minute <= 3000 or verification_status = 'verified')` | Defence in depth |

These rules always hold:
- An ongoing call is never re-priced. `calls.calls.rate_per_minute` is a snapshot, and settlement uses it.
- Approval, reinstatement and level-ups never change a stored price.

## 3. Verification workflow

| Action | Who | From | To | Reason |
|---|---|---|---|---|
| submit (`POST /v1/host/verification/submissions`) | host (approved) | not_applied, rejected, revoked | submitted (new application) | — |
| resubmit (same endpoint) | host | info_required | submitted | — |
| start_review | moderator/admin | submitted | under_review | optional |
| request_info | moderator/admin | submitted, under_review | info_required | `info_request` required |
| approve | moderator/admin | under_review | verified | optional; needs `face_video` + `id_document_front` |
| reject | moderator/admin | submitted, under_review, info_required | rejected | required |
| suspend | moderator/admin | verified | suspended (price capped) | required |
| reinstate | moderator/admin | suspended | verified (price unchanged) | required |
| revoke | moderator/admin | verified, suspended | revoked (price capped) | required |

The status names map to the spec's states:
- Not Applied = `not_applied`
- Application Submitted = `submitted`
- Under Review = `under_review`
- Additional Information Required = `info_required`
- Approved (Verified) = `verified`
- Rejected = `rejected`
- Suspended/Revoked = `suspended` / `revoked`

Controls:
- Only moderators and admins act on applications (route roles plus a service check).
- Nobody acts on their own account (`self_review` 403); the database also enforces `decided_by <> host_id` and `reviewer_id <> host_id`.
- An action that does not fit the table is refused with `invalid_transition` (409).
- There is one open application per host (unique partial index).
- Every action writes `audit.events` with the actor, time, action (`host.verification.<action>`), application id, from/to status, reason or info request, and any price cap. Staff views (`host.verification.viewed`) and evidence access (`host.verification.evidence_accessed`) are audited too.

Admin API (no admin web app exists yet; these are the foundations it will call):
- `GET /v1/admin/host-verifications?status=`: review queue, oldest first.
- `GET /v1/admin/hosts/{userId}/verification`: application, evidence metadata and audited history.
- `POST /v1/admin/hosts/{userId}/verification/actions`: `{action, reason, info_request}`.
- `POST /v1/admin/hosts/{userId}/verification/evidence/{evidenceId}/access`: a 5-minute signed URL.

## 4. Private evidence

- **Storage.** Objects live in the private Storage bucket `host-verification-evidence`. Upload uses a signed URL from `POST /v1/host/verification/evidence`, at a random path under the host id. The bucket is separate from `profile-photos`, so evidence is never a profile photo.
- **Metadata.** `hosting.verification_evidence` holds only the id, kind, content type, path, timestamps and `purged_at`. RLS is forced. Clients (`anon`, `authenticated`) get no grants.
- **What leaves the server.** Public APIs (discovery, profiles, calls, chat) expose only `is_verified`. The host's own view lists evidence ids and kinds, never paths or URLs. Staff get one 5-minute signed URL per request, audited before it is issued.
- **Retention** (job `purge-verification-evidence`, daily). It deletes the object, sets `purged_at`, and audits `host.verification.evidence_purged`. Metadata and the audit trail stay. Objects are deleted in these cases:
  - 90 days after a final decision (approved, rejected, revoked), configurable as `hosts.Deps.EvidenceRetention`;
  - 48 hours after upload for evidence never submitted;
  - immediately for deleted accounts.

  Evidence of a suspended host is kept while the case is open. **Legal review must confirm the 90 days** (DPDP).
- **No biometrics.** Nothing computes face embeddings or templates. A human reviewer compares the video with the ID.

## 5. Discovery

- `GET /v1/discovery/hosts?verification=all|verified|non_verified` (default `all`).
- **Ranking signal.** In the `recommended` sort, an active Verified Host ranks as if it had `DISCOVERY_VERIFIED_BOOST_XP` more lifetime XP. The default is 100,000; 0 turns it off. Non-verified hosts are never excluded except by the explicit filter.

## 6. App (Flutter)

- **Badge.** `VerifiedHostBadge` (shield with check, `Icons.verified_user_rounded`, label "Verified Host") appears on:
  - discovery cards and search results;
  - the host profile;
  - the incoming-call screen and the in-call top bar;
  - call summary and call history;
  - the chat inbox and conversation header;
  - the host's own profile tab.
- **Price selector (H10).** The slider runs from 500 to the server's `max_rate_per_minute`. It shows the level and level limit. Non-verified hosts see "Want to charge more than 3,000 Diamonds/minute? Become a Verified Host." The server's error codes map to messages.
- **Discovery filters.** The filter page has All / Verified / Non-Verified chips.
- **Host dashboard.** A Pricing card shows:
  - verification status;
  - current price;
  - the max you can set now;
  - level and level limit;
  - the next level's ceiling;
  - the CTA.
- **Verified Host page** (`/host/verified-host`). It shows status and reviewer note, records the face video (front camera, 10 s) and photographs the ID, then submits. It also carries the privacy notice. It has not been tested on a real device against Supabase Storage.

## 7. Not built / dependencies

- **Admin web app.** It does not exist. Reviewers need it, or API calls, to review applications and view evidence.
- **Hosted environments.** The migration has not been applied to the hosted Supabase project, and the API has not been deployed to Cloud Run. Both need founder approval.
- **Legal.** Retention period, consent text and the DPDP notice for face video and ID evidence need legal review.
- **Notifications.** Hosts are not notified of decisions yet. They see the change in the app.
