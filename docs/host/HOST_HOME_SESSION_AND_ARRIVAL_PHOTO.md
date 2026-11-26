# Host Home online session and the arrival photo

Status: **built 2026-11-26, not deployed.** Revised 27 Nov 2026: the separate waiting room and its mini-games were removed (founder: Reels replaces the games, and gifts are app-wide). Everything that was worth keeping now lives on Host Home.

- **Online session on Host Home.** Client-only, so it has no flag. It reads the new `online_session` field when the server provides one.
- **Arrival photo.** Backend flag `ARRIVAL_PHOTOS_ENABLED`; app flag `DASHURI_ARRIVAL_PHOTOS_ENABLED`. Both default off.
- **Unscanned photos.** Backend flag `ARRIVAL_PHOTO_AUTO_APPROVE_UNSCANNED` (default off) is a founder decision (§3.4).

Decision record: [ADR-015](../architecture/decisions/ADR-015-virtual-gifts-and-arrival-photos.md).

## 1. Online sessions

`hosting.online_sessions` has one row per continuous online period of a host. A trigger on `hosting.hosts.is_available` keeps one invariant: **available ⇔ exactly one open session.** Every path that changes availability is covered:

- the host's toggle
- the heartbeat job
- KYC rejection
- moderation enforcement
- account deletion
- fixtures and imports that insert hosts already online

Each path names its end reason through `set_config('dashuri.offline_reason', …)`. The reasons are `host_offline`, `heartbeat_timeout`, `host_ineligible` and `superseded`.

`GET /v1/host` returns `online_session {id, started_at}`. Host Home shows the online duration from that.

## 2. Host Home (app)

There is no waiting room page and no mini-games. Host Home (`RoutePaths.hostDashboard`, the Home tab of the host shell) owns the whole online experience, driven by `HostSessionBloc` (explicit sealed states).

- **Go online** runs the optional arrival-photo step on Host Home itself (a bottom sheet), then goes online.
- **After a call** that was declined or missed, the host returns to Host Home with `?after=declined|missed`, and *Done* on the call summary returns with `?after=ended`. The availability card says "You're still online".
- **Heartbeats** are unchanged (`HostPresenceController`, one app-wide timer).
- Host Home refreshes its status, pricing and earnings whenever the session goes online or offline.

### 2.1 States (`HostSessionBloc`)

Each situation is one explicit sealed state, not a set of booleans:

| State | Meaning |
|---|---|
| `HostSessionLoading` / `HostSessionLoadFailed` | Reading the host status |
| `HostSessionOffline` | Offline (optionally with the failure of the last attempt) |
| `HostSessionGoingOnline` | The arrival step, then the availability request (`activating`) |
| `HostSessionOnline` | Online (`notice`: declined / missed / ended after a call) |
| `HostSessionRinging` | Incoming call |
| `HostSessionReconnecting` | A heartbeat failed (network); still listed |
| `HostSessionNetworkUnavailable` | 3 or more heartbeats failed; the server will take the host offline |
| `HostSessionUnavailable` | Not approved, suspended or restricted |
| `HostSessionGoingOffline` | Ending the session |
| `HostSessionSessionEnded` | Ended by the host or by the server, with its duration |

Accepted and declined calls are not states inside the bloc. The call screen replaces Host Home, and Host Home re-opens online with a notice.

### 2.2 Incoming calls have priority

1. The app's `IncomingCallWatcher` calls `HostPresenceController.notifyIncomingCall(callId)` **before** it pushes the call screen.
2. The bloc moves to `HostSessionRinging`, and the availability card shows "Incoming call" with *Go offline* disabled.

The arrival photo is taken only during *going online*, before the host is callable, so it cannot hold the camera while a call rings.

### 2.3 Content of Host Home

- **Availability card:** status, online duration, level, price, Verified badge, Free calls, *Go online* / *Go offline*, the network banner with *Retry now*, and the call notice.
- **Arrival-photo card** (online, when enabled): status (*In review* / *Visible to customers* / *Not approved*), "Captured N minutes ago", Retake, Remove.
- **Gifts card** (when gifts are enabled): today's gifts and Beans, recent gifts, and a link to the history page. Gifts are an app-wide feature, so this is an ordinary Home card and not part of any session screen.
- Today, Pricing, quick links, a rotating tip, and the hosting and safety reminders with a link to the Host Agreement.

The layout is tested at phone, foldable, tablet and desktop sizes with 1.3× text. Dark mode uses the existing `DashuriColors` tones.

## 3. Arrival photo

### 3.1 Flow

1. The host taps **Go online**, and Host Home shows "Add an arrival photo?" with **Capture photo** and **Skip**.
2. **Capture** opens the front camera (`ArrivalCamera` port → `image_picker` with `ImageSource.camera`). It is **never the gallery**. There are no filters, and the image is a JPEG of at most 1440 px at quality 85.
3. **Preview** offers **Retake** and **Use photo**.
4. **Use photo** or **Skip** → the host goes online, and that creates the session.
5. The confirmed photo then uploads to that session: ticket → signed PUT → confirm.

   If the upload fails, the host stays online and the card offers *Try again*. Each attempt uses a fresh ticket.

6. **Skip never blocks or delays going online, and never affects ranking.** Discovery does not sort or filter by it.

Because `image_picker`'s camera source on Android opens the system camera activity, the camera screen itself is the system one. Prompt, preview, retake and confirm are in-app. A fully in-app camera would need the `camera` plugin; that is listed in §5.

### 3.2 Server rules

| Step | Rule |
|---|---|
| `POST /v1/host/arrival-photo/upload-tickets` | Approved, unrestricted host, `is_available`, open session; JPEG only. Ends the session's previous photo (`removed`, reason `replaced`). The signed upload URL is for `<host>/<photo>.jpg` in the **private** `host-arrival-photos` bucket. |
| `POST /v1/host/arrival-photo/{id}/confirm` | Must be the owner, the session still open, and within **10 minutes** of the ticket, so an old picture can't be passed off as new. The server downloads the object and requires ≤ 2 MiB, JPEG magic bytes, a fully decodable image and 240–4096 px. It **re-encodes** the image, which drops EXIF/GPS, then overwrites the object. Invalid → `rejected` and purged at the next run. A missing object → `409 upload_missing` (retry). Idempotent. |
| Moderation | If the Sightengine classifier is configured (`MODERATION_ENABLED` + keys; **paid per image**), explicit ≥ 0.6 → `rejected`, otherwise `approved`, and a scan error → `pending_review`. Without a classifier, the photo goes to `pending_review` for staff (admin *Arrival photos*), unless `ARRIVAL_PHOTO_AUTO_APPROVE_UNSCANNED`. |
| `GET` / `DELETE /v1/host/arrival-photo` | The host's own current photo / remove it (idempotent). |
| Staff | `GET /v1/admin/arrival-photos` (signed URLs; the view is audited); `POST …/{id}/decision` approve / reject / remove with a reason (audited). |

### 3.3 Customer display

Discovery cards and the host profile carry `arrival_photo {photo_id, url, captured_at}` **only** when all of these hold:

- the photo is `approved`,
- its session is **open**,
- the host is online or busy.

Signed URLs last 15 minutes.

The app shows the photo as a small inset with "3 min ago" on cards. On the profile it appears as **Recent photo · Captured N minutes ago · Taken in the app when they came online**, with **Report photo**. That link opens the existing report flow with `arrival_photo_id`, which the server links only when the photo belongs to the reported host.

It is never labelled "Live", "Live video", "Verified identity" or "current appearance". Tests check this.

### 3.4 Lifecycle, retention and privacy

- **Going offline** (by any path) immediately sets the photo `expired` and ends it. It disappears from discovery. **It is never reused**: the next session starts empty (tested).
- The `purge-arrival-photos` job runs every 15 minutes:
  - abandoned tickets expire after 10 minutes;
  - objects are deleted **24 h** after an expiry or removal, and **7 days** after a rejection;
  - photos that an **open report** points to are **kept** until the report closes;
  - metadata rows remain, for audit.
- Storage keys stay on the server. Clients only ever receive short-lived signed URLs.
- RLS: `anon` and `authenticated` have no access to `hosting.*`.

### 3.5 Open founder decisions

1. Moderation path: a paid classifier for every photo, staff review (the current default), or auto-approve unscanned photos.
2. Retention windows: 24 h after a session, 7 days after a rejection.
3. Whether to build a fully in-app camera (`camera` plugin) instead of the system camera activity.
4. Activation: both flags and the migration, in order (migration → backend → app).
