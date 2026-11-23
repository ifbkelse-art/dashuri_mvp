# Dashuri Reels — safety and moderation (EXPERIMENT)

Dashuri is an 18+ product. Reels adds **user-generated video**, the highest-risk content type the app has. The existing call pipeline is not enough on its own: it checks live frames during the first three minutes of a call, and nothing waits on it before content is seen. Reels therefore has its own lifecycle, in which **nothing is public until a moderation decision exists.**

## 1. Rules that are enforced in code

| Rule | Enforcement | Test |
|---|---|---|
| No public visibility before moderation | Feeds and `GET /v1/reels/{id}` return only `published` reels to others. Playback URLs are signed only for published reels (or the creator, or moderators). Mux assets use the `signed` policy | `TestLifecycleFirstReelNeedsHumanThenAutomated` |
| Publication requires a decision, **in the database** | Trigger `reels.guard_publication`: `→ published` only if the latest decision is `approve` or `restore`; inserts must start as `awaiting_upload` | `TestDatabaseRefusesPublicationWithoutDecision` |
| **Fail closed** on provider outage | No classifier configured → human review. Classifier errors → retry each minute, and after 30 minutes → human review (`provider_unavailable`). Never published by default | `TestFailClosedWithoutClassifierOrOnOutage` |
| Audit trail | `reels.moderation_decisions` is append-only (trigger, and UPDATE/DELETE revoked from service roles). Every moderator decision also writes `audit.events` | Append-only check in the publication test |
| No self-moderation | `403 self_review` when a moderator decides their own reel | Lifecycle test |
| 18+ only | Every Reels endpoint requires `AgeEligible` (`409 not_age_eligible`). Restricted accounts cannot upload or interact | `TestAgeAndRestrictionGates` |
| Clients cannot read Reels tables | RLS forced, service roles only, `anon` and `authenticated` revoked | `TestClientRolesCannotReadReels` |

## 2. Moderation lifecycle

### 1. Automated check (job `reels-moderate`)

When the provider reports the asset ready, the job samples **one frame every 2 s** across the whole reel. It uses signed Mux thumbnails at each time offset, so up to 30 frames for a 60 s reel. Each frame goes to Sightengine with `nudity-2.1`, `gore-2.0` and `offensive-2.0`. The maxima across frames decide:

| Result | Threshold (default) | Outcome |
|---|---|---|
| Sexual activity, sexual display or erotica | ≥ 0.80 | **Reject** (`sexual_content`), appealable, media held 90 days as evidence |
| Gore or offensive | ≥ 0.85 | **Reject** (`graphic_or_offensive`) |
| Sexual ≥ 0.20, or very suggestive ≥ 0.50 | — | **Human review**, priority 2 |
| Other ≥ 0.30 | — | **Human review**, priority 3 |
| Clean, but the creator's **first reel** | — | **Human review**, priority 4 (new-creator rule) |
| Clean, and the creator already has a human-approved reel | — | **Automated approve → published** |

All thresholds are configurable in `reels.DefaultThresholds`.

**The audio track is not analysed automatically.** Speech, music and copyright are covered by the creator rules, reports and human review. See §5.

### 2. Human review

**Queue:** `GET /v1/admin/reels/queue` shows open cases with:
- source (automated, report, appeal or provider unavailable);
- priority;
- classifier maxima;
- report count;
- appeal statement;
- a 15-minute signed playback URL.

**Decision:** `POST /v1/admin/reels/{id}/decision`, with one of:

| Decision | From status | To status |
|---|---|---|
| `approve` | pending or in review | published |
| `reject` | pending or in review | rejected |
| `remove` | published or in review | removed |
| `restore` | rejected or removed | published (appeal overturned) |

Every decision needs a `reason_code` and an optional note, and is idempotent (Idempotency-Key).

**Account-level enforcement** (warn, suspend or ban) stays in the existing safety system. A moderator who finds a serious violation opens or decides a user report there. Reels never bans anyone on its own.

### 3. Reports

`POST /v1/reels/{id}/reports` takes one of 10 categories:
- nudity;
- sexual content;
- **minor safety**;
- harassment;
- violence;
- hate;
- spam or scam;
- copyright;
- privacy;
- other.

How a report is handled:
- It hides the reel **from the reporter at once** and opens or raises a case.
- **`minor_safety` or `nudity` hides the reel from everyone immediately** (back to `in_review`, priority 1).
- **3 distinct reporters** hide it pending review.
- Repeat reports by the same person are no-ops. Reporting your own reel is refused.

### 4. Block creator

Blocking uses the existing `safety.blocks` and the report/block screen (`/report?mode=block`). Blocks in either direction hide reels, creator profiles and feeds.

### 5. Appeals

A creator may appeal a rejected or removed reel once (`POST /v1/reels/{id}/appeals`, ≤ 2,000 characters). The appeal opens a case. The decision marks it upheld or overturned. Media is never purged while an appeal is open.

## 3. Evidence retention and deletion

| Situation | What is kept | For how long |
|---|---|---|
| Rejected or removed by moderation | Provider media (for review and legal requests) | 90 days (`evidence_hold_until`), then purged by `reels-purge-media` |
| Creator deletes a reel that had reports, an open case, or a rejection | Media | 90 days, then purged |
| Creator deletes a clean reel | Nothing | Media purged within the hour |
| Account deletion | Reports and decisions (ids, no media) for audit | Kept. Reels, likes and follows are deleted by `reels-account-cleanup` |

Moderation decisions and audit events are never deleted.

**Legal hold:** for CSAM or law-enforcement requests, a moderator must not purge the media. Report CSAM to NCMEC/I4C and preserve the evidence. This needs a written procedure before launch (see §6).

## 4. Privacy and personal information

- The app tells creators not to include phone numbers, payment ids, other people without consent, or private information. Reports have a **privacy** category.
- **Captions are not yet run through the existing contact-detail filter** used in chat (`modules/textfilter`). Recommended before launch: a one-line call in `CreateUpload`.
- Analytics hold ids and durations only. Stored events need the user's analytics consent; view counters are functional and use ids only.
- Coordinates, device ids and IP addresses are not stored by Reels.

## 5. Copyright and licensed audio

- No music library is offered. One would need licences from IPRS, PPL or the labels.
- The creator rules on the upload screen say to use only music and clips you own or have rights to.
- **Copyright** is a report category. The moderator `remove` decision with `reason_code: copyright` is the takedown path. Keep a log of takedown notices for the IT Rules 2021 (grievance officer, 36-hour takedown on government or court order).
- Not automated: audio fingerprinting (for example Audible Magic or ACRCloud) is a paid add-on and is not included.

## 6. Before any public launch

1. Write a moderator runbook covering the CSAM/minor procedure, legal hold, takedown log and review SLA (suggested: priority 1 within 1 hour, others within 24 hours).
2. Decide who staffs the queue. The first-reel rule makes human review a daily task.
3. Run captions through `textfilter` (contact details).
4. Get a legal review of the Reels terms and community rules (UGC liability, IT Rules due diligence, copyright).
5. Review Play Store policy for user-generated content in an 18+ app: in-app reporting and blocking (done), and moderation before publication (done).
6. Confirm Mux's acceptable-use policy covers the product.

**What was not weakened:** the call moderation pipeline, safety reports, blocks and enforcement are untouched.
