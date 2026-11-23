# Dashuri Reels — product requirements (EXPERIMENT)

**Status:** experimental and local only. The founder has not approved it for permanent inclusion.

**Feature flags:** everything is behind two flags, both off by default:
- server: `REELS_ENABLED`
- app: `DASHURI_REELS_ENABLED`

**Principle:** Discover. Express. Connect.

## 1. Problem and goal

Today Dashuri is a host marketplace. A customer finds a host from a photo, a rate and an availability dot, then pays per minute. The first paid call is a leap of faith. The financial model shows that **conversion and retention**, not costs, decide whether Dashuri works (`docs/finance`).

Reels adds a free, low-pressure way to get to know hosts and other people through short videos. It should:
1. give customers a reason to open the app between calls (retention);
2. let a customer see a host's personality before paying (conversion);
3. bring in new users through shared links (acquisition).

Reels must never weaken the calls, the wallet or safety.

## 2. Users and roles

| Role | Can do | Cannot do |
|---|---|---|
| **Viewer** (any 18+ account) | Watch the For you and Following feeds; like, share, follow, report, block | Upload while restricted |
| **Regular creator** (any 18+ active account) | Everything a viewer can, plus upload reels, have a creator profile, gain followers, appear in feeds | **Receive paid calls.** No call button, no rate, no Beans |
| **Verified host** (`hosting.hosts.state = approved`) | Everything a creator can, plus an availability badge and a **Video call** button on their reels and profile, using the existing rate, pre-call screen, billing and Beans | Nothing new: paid-call rules are unchanged |
| **Moderator / admin** | Review queue, decisions, appeals, analytics | Moderate their own reels |

Host status is read from the existing `hosting.hosts` table. Reels never grants or stores paid-call privileges.

## 3. MVP scope (built)

| Area | Requirement | Where |
|---|---|---|
| Video rules | 15–60 s, vertical 9:16 presentation. Checked on the device (MP4 `mvhd`), then re-checked on the provider-reported duration (±0.9 s) | `Mp4Duration`, `MarkReady` |
| Create | Record with the camera (capped at 60 s), choose from the gallery, preview, caption (≤ 300 characters), upload progress | `ReelUploadPage` |
| Lifecycle | `awaiting_upload` → `processing` → `pending_moderation` → `in_review` → `published` / `rejected`, plus `removed`, `failed` and `deleted`. The creator sees each status | `UploadTracking`, My reels |
| Feed | Full-screen vertical swipe; **For you** (ranked) and **Following** (newest first); cursor paging; no duplicates within a session | `ReelsFeedPage`, `reelsrank` |
| Actions | Like (optimistic), follow, share (copies a link), report (10 categories), block (existing safety flow), open creator, play/pause, mute | `ReelView` |
| Creator profile | Photo, name, bio, verified-host badge, followers, following, reel count, grid, follow/unfollow, availability and call button for approved hosts | `CreatorProfilePage` |
| Own reels | Every status with an explanation, delete (with confirmation), appeal rejected or removed reels | Own-reel sheet |
| Host CTA | Online host: **Video call · N Diamonds/min** opens the existing pre-call screen (V01). Busy or offline host: **View host profile** (C07–C09) | `hostCtaLocation` |
| Safety | Moderation before publication; fail closed; reports; blocks; appeals; audit trail; evidence retention; deletion | `DASHURI_REELS_SAFETY_AND_MODERATION.md` |
| Analytics | 12 events; consent-gated storage; call attribution | `DASHURI_REELS_ARCHITECTURE.md` §7 |
| States | Every screen has loading, empty, error (with retry) and success states. Phone, foldable, tablet and desktop widths tested, plus text at 1.3× | widget tests |

## 4. Not in the MVP (not built, and no buttons for them)

- Comments
- Direct video messages
- Live streaming
- Duets or remixes
- Music library
- Creator subscriptions
- Virtual gifts
- Paid promotion or ads
- A separate creator wallet or currency

A music library needs licences (IPRS/PPL in India, or label deals) before it is considered. Until then, the creator rules forbid audio the creator does not own.

## 5. Decisions taken in the founder's absence (reversible)

| # | Decision | Why | How to change |
|---|---|---|---|
| R-1 | **Reels is a fifth customer tab** ("Reels", after Discover), not a re-architecture into Home / Discover-Reels / Connect / Inbox / Profile | The proposed 5-tab layout would rename or move existing routes (Wallet would lose its tab). Adding one tab keeps every existing route and deep link working | `customerTabsFor` in `apps/mobile/lib/app/router/role_shells.dart` |
| R-2 | **Hosts' host shell is unchanged.** Hosts use Reels from the customer side (D-04: one account, two modes) | Avoids touching H11–H25 | Add the tab to `hostTabs` |
| R-3 | **Every creator's first reel is reviewed by a person,** even if the automated check is clean | 18+ product with user-generated video; first uploads carry the most risk | `Evaluate(..., firstReel)` |
| R-4 | **Share = copy a link** (`https://dashuri.app/r/<id>`) | No share-sheet package is installed and dependencies need approval | Add `share_plus` (needs approval) |
| R-5 | **Playback needs `video_player`** (Flutter team package), which is not installed. Until it is approved, the app shows the poster frame and says that playback is unavailable in this build, with no fake player | Workstream rule 4: no new dependencies without approval | See `DASHURI_REELS_IMPLEMENTATION_STATUS.md` §5 |
| R-6 | **Daily upload limit of 10 reels** per creator | Abuse and cost control | `DailyUploadLimit` |
| R-7 | **Mux** is the video provider | See `DASHURI_VIDEO_PROVIDER_COMPARISON.md` | Swap the `VideoProvider` adapter |
| R-8 | **Reels data lives in its own `reels` schema** | Removing the experiment is one `drop schema` | — |

## 6. Success metrics (measure before scaling)

1. **Retention:** month-2 retention of paying customers who watch Reels versus a holdout. This is the main bet: the financial break-even needs a **24% relative cut in payer churn** in the base case (see the financial analysis).
2. **Conversion:** reel-attributed paid calls per 1,000 host-reel views. The attribution rule is in the architecture document.
3. **Health:** share of uploads rejected, report rate per 1,000 views, median time to a moderation decision, and appeals overturned.
4. **Cost:** Reels cost per 1,000 views and per published reel, from the simulator, checked against real invoices.

## 7. Open questions for the founder

1. Approve `video_player` (required for playback) and optionally `share_plus`.
2. Who reviews first reels, and the review SLA (the first-reel rule makes this a daily task).
3. The web landing page for shared links (`/r/<id>`): needed before sharing is worth promoting.
4. Policy on hosts' reels showing their rate. It is shown now, the same as on the host card.
5. Whether regular (non-host) creators should exist at launch, or Reels should be hosts-only. Hosts-only halves the moderation load.
