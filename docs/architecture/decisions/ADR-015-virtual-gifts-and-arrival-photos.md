# ADR-015: Virtual gifts, online sessions and arrival photos

- Status: accepted for implementation behind flags (2026-11-26). Production activation is a founder decision.
- Specs: [docs/gifts/VIRTUAL_GIFTS.md](../../gifts/VIRTUAL_GIFTS.md), [docs/host/HOST_HOME_SESSION_AND_ARRIVAL_PHOTO.md](../../host/HOST_HOME_SESSION_AND_ARRIVAL_PHOTO.md)

## Context

The founder asked for three things:

1. an online-session experience for hosts (first built as a separate waiting room; on 27 Nov 2026 that room and its mini-games were removed and everything useful moved to Host Home);
2. an optional arrival selfie for each online session;
3. customer-to-host virtual gifts during calls, paid in Diamonds and earning Beans.

All three had to fit the existing modular monolith, the double-entry ledger, the session-chat model and the Supabase Realtime hint model. None of them may change the approved financial conversion.

## Decisions

1. **Gifts are a new module (`internal/modules/gifts`), not a second wallet.**
   - Each gift is one `gift_send` ledger entry built by a template (`ledger.GiftSend`), keyed per gift transaction, with the same posting shape as `CallSettlement`.
   - Host Beans come from the active, versioned `economy.Rules`, with no gift-specific commission. 5:4 is not activated.
   - `gifts.transactions` is append-only and stores the charged price, split, Beans and rule-set version.
2. **Exactly-once comes from the database, not only the HTTP layer.**
   - The client's UUIDv4 Idempotency-Key is stored as `client_request_id`, unique per sender, together with a request hash.
   - The sender's balance rows are locked first, so concurrent and retried sends serialise.
   - The ledger key `gift_send:<id>` and the unique chat `gift_transaction_id` back this up.
3. **Call reservations are protected.**
   - A gift may only spend `balance − active reservations`, so it can never starve the live call's billing.
   - The call row is read `FOR SHARE`, so a settlement and a gift cannot interleave.
4. **The gift line is an ordinary chat message** of the pair's conversation, in the call's session (`kind = 'gift'`). It joins normal Chat when the call ends, exactly as typed session messages do. There is no second store and no copy.
5. **Realtime stays a hint.**
   - `call.gift` and `chat.message` are published after commit.
   - Clients de-duplicate by id and recover from `GET /v1/calls/{id}/gifts`.
   - Only server-confirmed gifts are celebrated.
6. **Online sessions come from a trigger on `hosting.hosts.is_available`.** This covers every existing availability path (host, heartbeat job, KYC, moderation, deletion) without changing each one's semantics.
7. **Arrival photos belong to one session.**
   - Private bucket, server validation and re-encoding (which drops metadata).
   - Moderated before display: classifier if configured, otherwise staff review by default.
   - Expired when the session ends; purged after a retention window.
   - Exposed only as "captured N minutes ago".
8. **The online session lives on Host Home and is client-only.**
   - `HostSessionBloc` uses explicit sealed states.
   - There is no waiting room page and no mini-games (founder, 27 Nov 2026: Reels replaces them).
   - An incoming call is shown at once through `HostPresenceController.notifyIncomingCall`, which the app calls before it opens the call screen.
9. **The call screen's camera on/off control is replaced** by the customer's Gift control. The Stream engine still owns the camera, which stays on (moderation frames are unaffected).

## Consequences

- New migrations:
  - `20261126000100_host_online_sessions_and_arrival_photos.sql`
  - `20261126000200_virtual_gifts.sql` (extends the `journal_entries.entry_type` check and adds `chat.messages.kind`)

  Apply them before deploying the backend.
- New flags, all off by default:
  - backend: `GIFTS_ENABLED` (requires `CHAT_MESSAGE_CONTEXT_ENABLED`), `ARRIVAL_PHOTOS_ENABLED`, `ARRIVAL_PHOTO_AUTO_APPROVE_UNSCANNED`
  - app: `DASHURI_GIFTS_ENABLED`, `DASHURI_ARRIVAL_PHOTOS_ENABLED`
- New job: `purge-arrival-photos`. `release-bean-holds` now includes `gift_send`.
- Fix found while testing: `postgres.AccountID` could return no rows when two transactions created the same ledger account concurrently. It now re-reads in a new statement.
- Known gaps (founder decisions or follow-ups):
  - chargeback clawback of gift Beans;
  - linked-account detection;
  - sounds;
  - a fully in-app camera;
  - limits values;
  - Play policy review.
