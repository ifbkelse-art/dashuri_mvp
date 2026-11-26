# Dashuri Admin (staff web console)

A small React + Vite web app for staff. It replaces running SQL by hand to:

- approve **new hosts** (basic activation: age and ID check);
- review **Verified Host** applications (photos, private face video and ID evidence, approve, reject, request info, suspend, reinstate, revoke);
- review **profile photos**;
- decide **reports**, **automated nudity flags** and **appeals**;
- see the **books** and run **two-person ledger adjustments**.

It has no business logic of its own. Every action calls an existing backend endpoint, and the backend checks the staff role, writes the audit log and enforces every rule again. Hiding a button in the console never grants or removes a permission.

## Who can see what

| Role (granted in the database only) | Sections |
|---|---|
| `admin` | Everything, including the recent audit log |
| `moderator` | Host applications, photos, reports and appeals |
| `finance` | Finance (reconciliation, adjustments) |
| `customer` / `host` only | Nothing. The console signs them out with an explanation. |

The backend also blocks, whatever the console shows:
- reviewing your own account;
- deciding an appeal against your own decision;
- approving your own ledger proposal, or adjusting your own wallet.

## Run locally

```sh
cd apps/admin
npm install
cp .env.example .env.local      # then fill it in (public values only)
npm run dev                     # http://localhost:5173
```

The backend must allow the console's origin through CORS:

```sh
ADMIN_ORIGINS=http://localhost:5173   # backend env; comma-separated; empty = CORS off
```

`npm test` runs the unit and screen tests. `npm run build` type-checks and builds `dist/`.

## Give someone a staff role

Staff sign in with their phone number and code, like the app. The console **cannot create accounts** (`shouldCreateUser: false`), so:

1. The person signs in once in the mobile app with their number. That creates the account and the profile name shown in the console.
2. An operator grants the role in the database (Supabase SQL editor), for example:

```sql
update identity.accounts
   set roles = array_append(roles, 'admin')
 where id = (select id from auth.users where phone = '919999999997')
   and not 'admin' = any(roles);
```

Use `'moderator'` or `'finance'` for narrower access. Remove a role with `array_remove`. Roles are read from the database on every request, so a change takes effect immediately.

## Deploy (Firebase Hosting, free tier)

Not deployed yet. Each step needs the founder's go-ahead.

1. Build with the production values:

```sh
VITE_API_BASE_URL=https://<cloud-run-url> \
VITE_SUPABASE_URL=https://<ref>.supabase.co \
VITE_SUPABASE_PUBLISHABLE_KEY=<publishable key> \
npm run build
```

2. Deploy `dist/` with `firebase deploy --only hosting` (config: `firebase.json`). It serves the app as a single page, with security headers, `noindex` and no framing.
3. Add the site's address (for example `https://dashuri-dev.web.app`) to the backend's `ADMIN_ORIGINS` and redeploy the backend.

## Security notes

- The browser holds only the **publishable** Supabase key and the staff member's own session. No secret or service key is in the bundle; the build is checked for `sb_secret` and `service_role`.
- Private verification evidence opens through a link that expires after 5 minutes. Each open is audited before the link is issued.
- Viewing the photo queue, a verification file and the books is audited by the backend. So the console never reads those in the background: counts are fetched on page load and after decisions, never polled.
- Pages are `noindex`. The session is stored in this browser under its own key, and Sign out clears it.

## Backend endpoints added for the console (2026-11-24)

All read-only and staff-only (OpenAPI: `api/openapi/dashuri.v1.yaml`):

| Endpoint | Roles | What |
|---|---|---|
| `GET /v1/admin/me` | moderator, admin, finance | Your name and roles |
| `GET /v1/admin/users?ids=` | moderator, admin, finance | Display names for up to 50 ids |
| `GET /v1/admin/host-applications` | moderator, admin | Hosts waiting for activation |
| `GET /v1/admin/appeals` | moderator, admin | Appeals with the original action |
| `GET /v1/admin/ledger/adjustments` | finance, admin | Adjustment proposals (`proposed_by_me`) |
| `GET /v1/admin/audit` | admin | Recent audit events (only the reason is exposed) |

The moderation queue also gained `details` (the reporter's own text). CORS for listed origins is in `backend/internal/platform/httpx/cors.go`.

## Known limits

- A new host can be decided only after they start the ID check in the app, because the decision closes that ID-check session. Until then the console shows "Waiting for ID check".
- No ID vendor is connected: the reviewer checks the ID outside the console and enters the date of birth from it. The server refuses anyone under 18.
- Lists show up to 100 items (no paging yet), which is enough for now.
- Payout cycles are not shown because payouts are switched off.
