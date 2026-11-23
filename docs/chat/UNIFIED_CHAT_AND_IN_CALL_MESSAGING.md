# Unified chat and in-call messaging (EXPERIMENT, 22 Nov 2026)

Committed 2026-11-22, flag-gated and off by default. Dashuri Reels is a separate experiment and is not part of this commit.
Not pushed, deployed or migrated on a hosted database, and no paid service
has been activated. Flags default to **off**. The in-call panel is
see-through (no background, no blur; each message has its own dark backing)
and the call screen has no flip-camera control (selfie camera only).

> **Update 23 Nov 2026 — video-call SESSION chat.** The in-call panel no
> longer shows the conversation history. Each call has its own session
> chat; it joins normal Chat when the call ends. See §0 below. Where §1–§11
> say the panel shows earlier history, §0 replaces that.

## 0. Session chat (23 Nov 2026)

**Model: link, don't copy.** One canonical conversation per pair (unchanged).
The session identifier is the **call id**. In-call messages are stored once,
in the canonical conversation, with `context = call` and `call_id`
(migration 20261123000200, already live on the dev database). Nothing is
ever moved or copied, so there is no migration step that can fail, run twice
or lose messages.

| View | Query (`GET /v1/conversations/{id}/messages`) | Shows |
|---|---|---|
| In-call panel | `?call_id=<call>` | only that call's messages (no earlier chat, no other call) |
| Normal Chat | no `call_id` | everything **except** messages of a call that is still live |

- **Isolation while live** is backend-authoritative: a session message is
  hidden from normal Chat (messages, inbox preview, unread count) while its
  `calls.calls.phase` is non-terminal (`requested … ending`).
- **"Append" at call end** = the call reaching a terminal phase (`ended`,
  `declined`, `missed`, `failed`). The messages then appear in normal Chat
  at their original `sent_at`, with original senders, in chronological
  order, after the earlier history. Repeated call-end events change nothing.
- **App killed / network lost / nobody calls `/end`:** the existing
  `settle-stale-calls` job ends the call (~90 s without media); the session
  appears without any client action. **Safety net:** a session message is
  shown in normal Chat at the latest 6 h after it was sent even if the call
  row is stuck live (`postgres.SessionRevealAfter`), e.g. if the job is not
  scheduled.
- **Refresh:** `calls.Deps.OnTerminated` → `chat.Service.CallEnded` sends a
  `chat.message` hint to both participants once per terminal transition, so
  an open Chat screen re-fetches. It is a hint only; correctness never
  depends on it.
- **Authorization:** `call_id` must be a call between the viewer and the
  conversation's other participant, else 404. Outsiders get 404 as before.
  With `CHAT_MESSAGE_CONTEXT_ENABLED` off the session view returns 503
  `in_call_chat_disabled` rather than the whole history.
- **Duplicates:** unchanged three layers (client key reused on retry,
  `Idempotency-Key` replay, unique `client_message_id`). Reconnection: the
  panel re-fetches the session (hint + 20 s poll).
- **Billing:** messaging never touches calls, ledger or reservations
  (Postgres byte-identical snapshot test).

Tests: `backend/internal/modules/chat/session_chat_test.go` (unit),
`session_chat_integration_test.go` (real Postgres: all 13 acceptance cases),
`calls_integration_test.go` (hook fires exactly once under 10 concurrent
`/end` + 10 sweeps), Flutter `test/application/in_call_chat_test.dart` and
`test/data/chat_data_test.dart` (wire format).

Contents: 1 Product requirements · 2 Provider assessment · 3 Architecture ·
4 Database · 5 API · 6 Flutter · 7 Safety, privacy, billing · 8 Tests ·
9 Flags, rollout, rollback · 10 Local demo · 11 Limitations

---

## 1. Product requirements

**Goal.** Two people can text each other in two places, and both places show
**one conversation**:
- **Normal Chat**: the existing Inbox conversation (CH01/CH02).
- **In-Call Chat**: a panel on the video-call screen. It opens without
  ending, pausing or re-billing the call.

**User stories**
1. During a call, I can tap **Chat**, type a message, and my partner sees it
   right away without leaving the video.
2. While the panel is closed, a message from my partner shows an **unread
   badge** on the chat control and a short **preview** above the controls.
   Tapping either opens the panel.
3. After the call, both of us find every in-call message in the normal
   Inbox conversation and can keep chatting there.
4. If we were already chatting before the call, the panel shows that history.
   New messages sync both ways between the panel and the Inbox.
5. Messages show the time, the sender (side and colour), and for my own
   messages a delivery state: **Sending… → Sent → Read**, or
   **Not sent · Tap to retry**.
6. In the Inbox, messages sent during a call carry a small
   "During video call" label.

**Scope**
- Text only, up to 1,000 characters (existing rule D-15).
- No attachments, audio, files or reactions. They don't exist today and were
  not added.

**Non-goals**
- No per-call conversation.
- No second messaging provider.
- No charge for messages.
- No change to call controls, billing, duration or settlement.

**Acceptance criteria**

| # | Criterion | Evidence |
|---|---|---|
| A1 | Normal Chat works | Existing 33 chat tests plus the new ones (§8) |
| A2 | In-call chat works | Call-screen tests, E2E UI test |
| A3 | One conversation for both | Go integration test against Postgres, cubit sync tests |
| A4 | Messages sync both ways | Sync tests 1–4, E2E UI tests |
| A5 | Messages survive the end of the call | Postgres test (call set to `ended`), cubit test 5 |
| A6 | Calls are unaffected | 182 video_call tests; zero call events recorded during chat use |
| A7 | Billing is unaffected | Postgres test: ledger, postings, balances, reservations and the call row are byte-identical before and after messaging |
| A8 | Tests show the behaviour | §8 |

## 2. Does the existing messaging provider support the full experience?

Dashuri does **not** use Stream Chat. Stream is used only for **video**.

Messaging is a **custom Go service** (`backend/internal/modules/chat`):
- Postgres `chat.conversations`: one row per pair, enforced by
  `unique(user_a, user_b)` with `user_a < user_b`.
- `chat.messages`.
- `chat.read_markers`.
- An `Idempotency-Key` on every send.
- Supabase Realtime broadcast **hints** (`chat.message` on `user:<id>`).
  Clients re-fetch after a hint.

**Verdict: yes.** The existing service already provides the canonical
conversation, the message model, persistence, authorisation, keyset
pagination and idempotent sends. The in-call panel needs **no new provider
and no new message store**. Five small changes close the gaps:

| Gap | Smallest change |
|---|---|
| No "sent during a call" marker | Nullable metadata columns `context`, `call_id` on `chat.messages` (migration below) |
| Hosts on "past call partners only" couldn't be messaged during their **first** call (a billed *ended* call was required) | A call in `active`/`paused` (billing started) also counts. A block always wins. |
| No read receipts in the API | `read_by_peer` per message, computed from the existing `read_markers`, plus a `chat.read` hint |
| Duplicate protection lived only in the 24 h idempotency-key store | `client_message_id` with a partial unique index (defence in depth) |
| Push notification for every in-call message, even though the recipient is looking at the call | No push for `context = call`; the realtime hint is enough |

## 3. Architecture

```
            ┌──────────── Flutter app ─────────────┐
 Inbox ──►  ConversationPage ─┐                    │
                              ├─ ConversationCubit ─┤── ChatRepository ── HTTP ──► Go chat API ──► Postgres chat.*
 Call  ──►  CallPage ─ port ──┤   (callId set for   │       ▲                         │
            (video_call)      │    the call panel)  │       └── Realtime hints ◄──────┘ (Supabase broadcast,
                InCallChat ◄──┘  InCallChatPanel    │           chat.message / chat.read   user:<peer>)
                 (app adapter → feature_chat)       │
            └──────────────────────────────────────┘
```

- **One cubit for both places.** The panel uses the same
  `ConversationCubit`, use cases, repository and API as the Inbox. It is
  opened with the peer's user id, and `POST /v1/conversations` returns the
  pair's existing conversation. With `callId` set, the cubit:
  - sends `context: call`;
  - starts **hidden**: it counts unseen messages and does **not** mark them
    read until the panel opens;
  - re-fetches every 20 s as a fallback if a realtime hint is missed.
- **Feature isolation is preserved.** `feature_video_call` defines only a
  port (`InCallChat` / `InCallChatSession`). The composition root
  (`apps/mobile/lib/app/di/in_call_chat_adapter.dart`) adapts
  `feature_chat` to it, the same pattern as `HostModeSwitch`. Neither
  feature depends on the other.
- **The call is untouched.** The panel is plain UI on `CallPage`. It never
  adds a `CallBloc` event, so it cannot end, pause or bill. Back closes the
  panel first. Ending the call closes the panel and the chat session, and
  history stays on the server.
- **Ordering and pagination.** Existing keyset `(sent_at, id)`, newest
  first. Clients merge by server id and sort by `sent_at`.
- **Idempotency, three layers.**
  1. The client keeps one key per message and reuses it on retry.
  2. Server `Idempotency-Key` replay.
  3. In-call messages: `client_message_id` unique per
     (conversation, sender), with `ON CONFLICT DO NOTHING`. A repeat returns
     the stored row and publishes nothing.

## 4. Database

Migration `supabase/migrations/20261123000200_chat_message_context.sql`.
It is additive and nullable, so existing rows are untouched:

| Column | Type | Meaning |
|---|---|---|
| `context` | text, `chat`/`call`, null = chat | where it was sent from |
| `call_id` | uuid → `calls.calls` | the call (server only; `check (call_id is null or context = 'call')`) |
| `client_message_id` | uuid | sender's message id; `unique (conversation_id, sender_id, client_message_id) where not null` |

Grants are table-level (unchanged).

Rollback (local/staging only):
`docs/reels/experiment/drop_chat_message_context.sql`.

## 5. API changes (`api/openapi/dashuri.v1.yaml`)

All changes are additive. Old clients and old payloads keep working.

- `ChatMessage`: `context` (`chat`|`call`), `read_by_peer` (bool).
- `SendMessageRequest`: optional `context`, `call_id`, `client_message_id`.
  Validation:
  - `call` requires `call_id`;
  - `call_id` is only allowed with `call`;
  - both ids must be UUIDs;
  - `call_id` must be a call **between the two participants**
    (else 422 `call_id: not_found`).
- `POST /v1/conversations/{id}/read`: publishes `chat.read`
  `{conversation_id}` to `user:<peer>`, **only** when the marker passed a new
  peer message. This prevents ping-pong between two open screens.
- The Flutter client sends the new fields **only** from the in-call panel.
  Inbox sends are byte-identical to today, so an old deployed backend
  (strict JSON decoding) keeps accepting them.

## 6. Flutter

| Piece | File |
|---|---|
| Message entity (`context`, `readByPeer`) | `packages/features/chat/lib/src/domain/entities/chat_message.dart` |
| Cubit: `callId`, `setVisible`, `unseenCount`, `latestUnseen`, `peerReadUpTo`, `deliveryOf`, poll, read hints | `application/conversation_cubit.dart`, `conversation_state.dart` |
| In-call controller (owns the cubit, exposes unseen/preview) | `application/in_call_chat_controller.dart` |
| Shared, constraint-based message widgets | `presentation/widgets/message_widgets.dart` |
| In-call panel | `presentation/widgets/in_call_chat_panel.dart` |
| Port | `packages/features/video_call/lib/src/presentation/in_call_chat.dart` |
| Call screen integration | `video_call/.../pages/call_page.dart`, `widgets/call_widgets.dart` |
| App wiring and flag | `apps/mobile/lib/app/di/in_call_chat_adapter.dart`, `injector.dart`, `packages/core/.../app_config.dart` |

**Call-screen layout.** The top bar, chat panel and controls share **one
column**, so they can never overlap on any screen:
- The panel takes about half the screen (240–520 px), capped at 420 px wide,
  and is right-aligned on screens ≥ 600 px.
- While typing, the controls give way to the keyboard. On short screens the
  top bar does too. Closing the keyboard brings the controls back.
- The self-view tile is hidden while the panel is open, so it never covers
  messages.
- The control bar no longer uses `FittedBox`. Controls stay 56 px and shrink
  to no less than **48 px**; on 320 px phones they wrap onto a second row.

## 7. Safety, privacy, billing

- **Every send re-applies the existing rules server-side:**
  - participant only (else 404);
  - 18+;
  - account not restricted;
  - no block **either way**;
  - the receiver's privacy setting;
  - the contact-details filter (CH05).

  A block made mid-call stops sending from the panel *and* the Inbox.
  Re-opening is refused. Blocked conversations stay hidden from the Inbox
  (unchanged).
- **Reporting.** The call's Report control (ends the call, then the report
  form) and the Inbox Report/Block menu are unchanged and reused.
- **Privacy.** `call_id` is never returned by the API. In-call messages send
  no push. Push stays data-light, as before.
- **Billing.** Chat endpoints never touch calls, the ledger or wallets. The
  Postgres test compares journal entries, postings, balance sums, diamond
  reservations and the call's `phase`/`billed_seconds`/`diamonds_charged`
  before and after a full in-call conversation: they are identical. Messages
  cost nothing.

## 8. Tests (actually run on 22 Nov 2026)

**Real Postgres** (`scripts/test-backend-integration.sh`, throwaway local
database, every migration applied, connected as least-privilege
`api_service`):
- `TestInCallChatIsTheSameConversation` covers:
  - privacy before and during the call;
  - same conversation id;
  - in-call send;
  - duplicate resend (one row, no hint);
  - replies from the panel and the Inbox;
  - push only for Inbox messages;
  - foreign call rejected;
  - **money/call snapshot unchanged**;
  - call ended → full history in order and chatting continues;
  - one conversation per pair;
  - read receipts and a single `chat.read`;
  - outsider read/send refused;
  - block mid-call refused both ways.
- `TestInCallChatOrderingAndPagination`: 25 interleaved messages walked
  7 per page, exactly once each, strictly ordered.
- `TestChatWithContextDisabledUsesTheOldColumns`: flag off means no metadata
  is written.
- The existing `TestChatFlowPrivacyAndBlocks` and
  `TestMessagingPrivacyAndEligibility` still pass.

**Go unit** (`in_call_test.go`, in-memory repo): 6 tests of the same rules.

**Flutter.** Real cubits for two users on a fake server with the Go API's
rules (`chat/test/helpers/fake_chat_server.dart`):

| Req. | Test |
|---|---|
| 1, 2 | `in_call_chat_test.dart` "1+2" |
| 3, 4 | "3+4" |
| 5 | "5: history survives…" |
| 6 | "6: lost response retried…", "6: repeated hints and polling…", "realtime down…" |
| 7 | "7: interleaved…", "older pages…" |
| 8 | "8: outside the conversation…" |
| 9 | "9: after a block…" (reporting: unchanged flows, existing tests) |
| 10 | `video_call/test/presentation/call_chat_test.dart` "10: opening and closing…", "Back closes the chat first…", "the call ending closes…" |
| 11 | Client: `verifyNever(bloc.add)` / zero recorded call events. Server: money snapshot (above) |
| E2E UI | `apps/mobile/test/in_call_chat_e2e_test.dart`: typing in the real panel on the real call screen reaches the peer's real Inbox page; an Inbox reply reaches the closed panel (badge, preview, Read) |

**Regression.** All 20 Flutter packages: **1,163 passed, 0 failed** (was 879
before this work and Reels' responsiveness additions). Go: `go vet`, all unit
packages, all integration packages pass.

**Tested vs. needs real credentials**
- **Tested:** all server rules on real Postgres; all client sync, dedupe,
  unread, read receipts, layout and call-continuity logic.
- **Not tested here:** the live Supabase Realtime transport (the hint
  path is unchanged code, already used by Inbox chat on the phones), live
  Stream video under the panel, and real devices. Widget tests are not
  physical-device verification. See the responsiveness audit.

## 9. Flags, rollout, rollback

| Flag | Default | Effect |
|---|---|---|
| `DASHURI_IN_CALL_CHAT_ENABLED` (app `--dart-define`) | off | Off: no chat control on the call screen (call UI otherwise as before, except the 48 px-minimum control bar) |
| `CHAT_MESSAGE_CONTEXT_ENABLED` (backend env) | off | Off: SQL identical to before, and in-call messages are stored as plain messages. **Apply the migration before turning it on.** |

**Rollout order:**
1. Apply the migration.
2. Deploy the backend.
3. Set `CHAT_MESSAGE_CONTEXT_ENABLED=true`.
4. Build the app with the app flag.

An app with the flag on, talking to an older backend, fails only in-call
sends (strict decoder), so deploy the backend first.

**Rollback:** `docs/reels/experiment/restore.sh --apply` restores every
modified file and removes every created one (this work is registered in
`MODIFIED.txt` / `CREATED.txt`). For a database where you applied the
migration, run `drop_chat_message_context.sql`.

## 10. Local demo

```bash
# Backend tests on a throwaway local Postgres (no hosted DB touched)
./scripts/test-backend-integration.sh ./internal/modules/chat/...

# Flutter: sync, call screen, responsiveness, end-to-end UI
(cd packages/features/chat && flutter test)
(cd packages/features/video_call && flutter test)
(cd apps/mobile && flutter test test/in_call_chat_e2e_test.dart)

# Running app against your own local/staging backend (never production):
#   backend env: CHAT_MESSAGE_CONTEXT_ENABLED=true (after the migration)
flutter run -t apps/mobile/lib/main.dart \
  --dart-define=DASHURI_IN_CALL_CHAT_ENABLED=true  # plus your usual defines
```

Manual script for two phones:
1. A calls B.
2. Once connected, A taps **Chat** and sends a message. B sees the badge and
   preview, then opens the panel.
3. B replies from the panel.
4. End the call. Both open Inbox → the same conversation shows every message,
   labelled "During video call".

## 11. Limitations

- **Delivery states.** "Delivered to device" isn't tracked (no device
  acknowledgements): the states are Sent (stored) and Read (read marker).
- **Missed hints.** Realtime hints are best-effort. During calls a 20 s poll
  covers missed hints, while the Inbox relies on hints as before.
- **Self-view.** The self-view tile is hidden while the chat panel is open.
- **Strict decoder.** In-call messages from an app with the flag on fail on a
  backend that predates this change (strict JSON).
- **"Call partner" rule.** A live call counts as a call partner only once
  billing has started (`active`/`paused`). The chat control appears only
  then.
- **Late messages.** `call_id` is accepted for a call in any phase, so a
  message racing the call's end isn't lost.
