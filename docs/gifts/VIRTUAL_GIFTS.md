# Virtual gifts during video calls

Status: **built 2026-11-26, behind flags, not deployed.**
Backend flag `GIFTS_ENABLED` (default off). App flag `DASHURI_GIFTS_ENABLED` (default off).
Decision record: [ADR-015](../architecture/decisions/ADR-015-virtual-gifts-and-arrival-photos.md).

## 1. What it is

During an **active** one-to-one video call, the **customer** (the caller) can send the host a virtual gift.

- The customer pays Diamonds.
- The host earns Beans under the **existing economy rule set**.
- Both participants see a celebration and a line in the call's chat.

Hosts never send gifts. Host accounts also cannot send gifts when they call another host. This blocks host-to-host value transfer.

Gifts never unlock content and never override any safety rule.

## 2. Financial dependency (read first)

Gift earnings use **the same conversion as calls**: `economy.Rules.BeansForDiamonds`. The active rule set is `2026-11-23-verified-pricing`.

- 16,670 Diamonds spent earn 10,000 Beans, rounded down per gift.
- 1 Bean = ₹0.005.
- Example: a 1,500-Diamond Rose earns the host 899 Beans (about ₹4.50).

Rules that apply to gifts:

- **No gift-specific commission exists.** Catalogue rows carry `earning_rule = 'standard_conversion'`. That is the only value the database accepts.
- **The 5:4 model (5 D → 4 Beans, approved 2026-11-24) is for modelling only. It is NOT activated by this feature.** If the founder later approves 5:4 for production, it is introduced as a new versioned rule set. Gifts pick it up automatically from that point.
- Every gift stores the `rule_set_version` it was computed with, the price it was **charged**, the promotional/purchased split, and the Beans. Historical gifts are therefore never re-priced or re-converted.
- Gift Beans go into the same **7-day hold** as call earnings. `release-bean-holds` now also releases `gift_send` credits, and they count toward the host's XP, like call Beans.
- Diamonds are spent **promotional first**, the same spend order as calls (`Rules.SpendOrder`). Whether promotional Diamonds should be giftable is an open founder decision (§9). Today every such gift is risk-flagged `promotional_diamonds`.

## 3. Catalogue

Table `gifts.catalogue`. Seed values are founder-proposed product decisions:

| id | Name | Diamonds | Tier |
|---|---|---:|---|
| rose | Rose 🌹 | 1,500 | common |
| teddy | Teddy Bear 🧸 | 5,000 | common |
| watch | Watch ⌚ | 10,000 | rare |
| gold_ring | Gold Ring 💍 | 15,000 | rare |
| diamond_ring | Diamond Ring 💎 | 25,000 | epic |
| luxury_gift | Sports Car 🏎️ | 50,000 | epic |
| royal_gift | Crown 👑 | 100,000 | legendary |
| premium_gift | Yacht 🛥️ | 150,000 | legendary |
| super_gift | Rocket 🚀 | 200,000 | mythic |
| elite_gift | Castle 🏰 | 300,000 | mythic |

Names were changed on 2026-11-27 (migration `20261127000300_gift_catalogue_names.sql`, founder decision). Ids and prices did not change. Heart, Ice Cream and Bouquet are not in the catalogue yet; adding them needs founder-set prices.

Each gift has these fields:

- a stable id
- name, description and emoji (used in the chat line)
- icon asset and animation asset (references)
- animation duration (default 5,000 ms; allowed range 1–10 s)
- optional sound asset
- tier and sort order
- price (1 to 1,000,000)
- active flag and an optional availability window (`available_from` / `available_until`)
- earning rule and `retired_at`

Gifts are **retired, never deleted** (a delete trigger refuses it). A retired gift cannot be sold or edited again.

`GET /v1/gifts/catalogue` returns only gifts that can be sent now. The app reloads it every time the sheet opens, so disabled gifts and new prices appear at once.

## 4. Sending (server-authoritative)

`POST /v1/calls/{callId}/gifts` with body `{gift_id, recipient_user_id}` and a mandatory **UUIDv4 `Idempotency-Key`**. The body never contains a price.

Everything runs in **one Postgres transaction** (`postgres.GiftsRepo.Send`). The rules themselves live in a pure function (`gifts.decide`) that is unit-tested.

1. Lock the sender's Diamond balance rows (`FOR UPDATE`, ascending id). Every send by this customer serialises here, and so does the call's own billing.
2. Look up `(sender, client_request_id)` in `gifts.transactions`:
   - Found with the same request hash: return it (**replay**; nothing is charged).
   - Found with a different hash: **422** `Idempotency-Key: reused_with_different_request`.
3. Read the call `FOR SHARE`, the gift `FOR SHARE`, both parties, the block status, the call reservations, and velocity/spend over the last minute and 24 hours.
4. Rules, in this order:
   - The sender is the call's caller. If the host tries: `hosts_cannot_send_gifts`.
   - The recipient is the call's receiver: `recipient_user_id: not_call_host`.
   - The call phase is `active` (not ringing, paused or ended): `call_not_giftable`.
   - The sender is an active, 18+ account that is not an approved host: `account_restricted` / `not_age_eligible` / `hosts_cannot_send_gifts`.
   - The host is approved and active: `host_cannot_receive_gifts`.
   - No block either way: `blocked`.
   - The gift exists, is active, not retired and inside its window: `not_found` / `gift_unavailable`.
   - Velocity: at most 6 gifts per call per minute: `429 gift_rate_limited`.
   - Daily cap: 1,000,000 Diamonds per 24 hours: `gift_spend_limit`.
   - Balance: `available = promotional + purchased − active call reservations` must cover the price: `insufficient_diamonds`. **The Diamonds reserved for the live call can never be gifted.**
5. Post **one** balanced ledger entry, `gift_send`, with key `gift_send:<gift transaction id>`:

   | Account | Change |
   |---|---|
   | customer `diamond_promotional` / `diamond_purchased` | −split |
   | `sys_diamond_consumed` | +price |
   | `sys_bean_issued` | −Beans |
   | host `bean_held` | +Beans |

6. Insert the immutable `gifts.transactions` row: price, split, Beans, rule-set version, ledger entry, risk flags.
7. Append the gift's chat line to the pair's conversation, inside the call's session (`kind = 'gift'`, `context = 'call'`, `call_id`, unique `gift_transaction_id`).
8. Grant the host XP for the Beans (`bean_earning`, source `gift:<id>`).

Any failure rolls back everything. An integration test forces a failure at step 7 to prove it.

After the commit, realtime **hints** are published:

- `call.gift` on `call:<id>`
- `chat.message` on both `user:<id>` channels

Realtime is not the source of truth. `GET /v1/calls/{callId}/gifts` returns the canonical history.

Idempotency has two layers:

- the shared HTTP `Idempotency-Key` store (24 hours; also refuses a key reused with a different body), and
- the durable unique constraint `(sender_id, client_request_id)` in the database, which has no expiry.

A timeout followed by a retry with the same key returns the stored gift. Concurrent identical requests are serialised by the balance lock, so only one is ever charged (tested with 8 concurrent requests).

## 5. App experience

- **Gift control.** The camera on/off control in the call bar has been removed for both sides. In its place the **customer** gets *Send a gift*, which is enabled only while the call is active. Hosts get no control there.
- **Camera lifecycle.** The camera stays on for the whole call. The Stream engine still owns it, so moderation frames and the local preview are unaffected.
- **Gift sheet** (`GiftSheetBloc`):
  - shows the catalogue grid, selection, the cost and the customer's server-reported balance;
  - when the balance is too low it shows that state and an *Open wallet* link to the existing wallet route; it never starts a payment;
  - Send makes exactly one request per tap and ignores further taps while it is in flight;
  - if the outcome is unknown (offline, timeout or 5xx), the same Idempotency-Key is reused on retry;
  - a definite refusal, or choosing another gift, starts a new key.
- **Celebration** (`GiftCelebrationCubit` + `GiftCelebrationOverlay`):
  - only server-confirmed gifts are celebrated: the sender's receipt, a `call.gift` event, or a gift found after a reconnect;
  - there is one celebration at a time, in arrival order, de-duplicated by gift transaction id;
  - gifts that already existed when the call screen opened are never replayed;
  - after a reconnect, only gifts younger than 20 s are celebrated;
  - with more than 5 gifts waiting, each celebration is shortened to 1.5 s; nothing is dropped;
  - the overlay is transparent and `IgnorePointer`, and sits between the top bar and the controls, so call, report and chat stay usable;
  - **each gift has its own five-second choreography** (27 Nov 2026, `gift_choreography.dart`), chosen by the server's `animation_asset` (then gift id; unknown gifts get a tier default):

    | Gift | Hero | Effects |
    |---|---|---|
    | Rose | pop and float | falling rose petals, sparkles, soft red glow |
    | Teddy Bear | drops in and bounces | rising hearts, sparkles, pink glow |
    | Watch | pop | sweeping second-hand ring, gold sparkles |
    | Gold Ring | spins in | gold dust burst, sparkles |
    | Diamond Ring | spins in | soft light rays, ice-white sparkles |
    | Sports Car | drives in, parks, drives out | speed lines, confetti |
    | Crown | descends and settles | light rays, gold dust, sparkles |
    | Yacht | bobs | waves, sparkles, sunset glow |
    | Rocket | rumbles, then launches | exhaust trail, firework bursts |
    | Castle | pop | fireworks, confetti, sparkles |

  - every effect is drawn with plain shapes by one painter (no images, no per-particle layers), at most 40 particles per gift for low-end phones; tests check each gift is distinct, within budget, and paints through all 5 s;
  - with *Remove animations* turned on, only a static banner shows;
  - the screen reader announces each gift, and the host feels a haptic.
- **Sound.** Sound assets are optional catalogue data. The app has no audio dependency yet, so no sound is played (see §9).
- **Chat.** The gift line ("🌹 Asha sent Rose to Meera.") appears in the in-call panel as a centred event, not a speech bubble. When the call ends it stays in normal Chat. Duplicate deliveries are merged by message id.

## 6. Histories

| Who | Where | What |
|---|---|---|
| Customer | Wallet → *Gifts sent* (`GET /v1/me/gifts/sent`) | Gift, host, Diamond cost, date, call. The wallet history also shows the spend as "Gift sent". |
| Host | Host Home *Gifts* card and *Gifts received* page (`GET /v1/host/gifts`, `/summary`) | Gift, sender, time, Diamond value, the host's own Beans, and the hold status (`on_hold` / `released`). The wallet shows "Gift received (on hold)". |
| Both | `GET /v1/calls/{callId}/gifts` | The canonical list for one call (participants only). |

The host never sees the customer's balance or the promotional/purchased split.

## 7. Administration

Admin console page **Gifts**, backed by these endpoints:

| Action | Endpoint | Role |
|---|---|---|
| List catalogue | `GET /v1/admin/gifts` | admin, finance, moderator |
| Create | `POST` | admin |
| Edit metadata, enable/disable, sort, schedule, retire | `PATCH /{id}` | admin |
| Change price (reason required) | `POST /{id}/price` | admin |
| Price history | `GET /{id}/price-history` | staff |
| Performance | `GET /performance?days=` | staff |
| Investigate transactions | `GET /transactions?user_id=&call_id=&flagged=` | staff |

Every create, update and price change writes `audit.events`. Price changes also write the append-only `gifts.price_changes`.

A price change applies only to gifts sent afterwards. Completed transactions keep their charged price; a database trigger forbids updates.

## 8. Abuse prevention and safety

- **Authorisation.** Customer only, in their own active call, to that call's host. Blocked pairs, restricted or suspended accounts and under-18 accounts are refused.
- **Self-gifting.** It is structurally impossible inside one call. Host accounts cannot send gifts at all, so one host cannot route value to another through a second account.
- **Shared devices.** There is no reliable signal for "same person, two accounts". Free Call Card device hashes are unique per account, and FCM tokens move between accounts. Linked-account detection is therefore listed as an open item, not claimed.
- **Velocity and spend.** 6 gifts per call per minute; 1,000,000 Diamonds per 24 hours (§9: proposed values). There is also the general per-user API rate limit.
- **Risk flags.** Recorded on the transaction and never blocking:
  - `high_value` (≥ 100,000)
  - `new_sender_account` (account under 72 h old sending ≥ 25,000)
  - `repeat_pair_volume` (≥ 500,000 to one host in 24 h)
  - `promotional_diamonds`

  Staff review them under *Flagged gifts* and through the transactions endpoint.
- **Reporting.** The existing report flow applies to the call and the user. Gift Beans sit in the 7-day hold before they can be withdrawn, which leaves a window to act.
- **Known gap.** `ledger.BeanClawback` has no caller yet (see the monetization audit). Reversing gift Beans after a chargeback therefore has no automated path. This must be closed before production.

## 9. Open founder decisions

1. **Activation.** Gifts are off. Turning them on in production needs explicit approval: the backend flag, the app flag and the migration.
2. **Conversion.** Gifts follow the call conversion. Confirm that gifts should not have their own rule. If 5:4 is approved for production, decide when the new rule set takes effect.
3. **Promotional Diamonds.** May they be gifted (today: yes, promotional first, flagged)?
4. **Limits.** 6 per call per minute and a 1,000,000 D daily cap are engineering proposals. Confirm or replace them, and consider a lower cap for new accounts.
5. **Play policy.** Paid virtual gifts that turn into creator earnings fall under Google Play's policies on digital goods, UGC and "compensated arrangements". This is the P0 listing risk already raised; it needs review before launch.
6. **Sound.** Choose sounds and a respect-device-mute policy, or confirm silent celebrations.
7. **Gift artwork.** Gifts currently use emoji and procedural celebrations; commission art if wanted. `icon_asset` and `animation_asset` already exist for it.
8. **Chargeback clawback** for gift Beans (§8, known gap).

## 10. Files

- **Backend:**
  - `internal/modules/gifts/*` (rules, service, admin, http, tests)
  - `internal/adapters/postgres/gifts_repo.go`
  - `internal/modules/ledger` (`GiftSend` template, `gift_send` type)
  - `internal/app/wire_gifts.go`
  - chat repo (`kind`/`gift` fields)
  - wallet `Describe`
  - bean release
- **Migration:** `supabase/migrations/20261126000200_virtual_gifts.sql`
- **App:**
  - `packages/features/video_call` (gift domain, data, `GiftSheetBloc`, `GiftCelebrationCubit`, sheet, overlay, call page)
  - `feature_chat` (gift line)
  - `feature_wallet` (gifts sent)
  - `feature_host` (gifts received)
- **Admin:** `apps/admin/src/pages/Gifts.tsx`
