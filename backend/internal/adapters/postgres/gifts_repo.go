package postgres

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/modules/gifts"
	"dashuri/backend/internal/modules/ledger"
)

// GiftsRepo implements gifts.Repository on gifts.* plus the ledger, calls,
// identity, hosting and chat tables the send transaction touches.
type GiftsRepo struct {
	Pool *pgxpool.Pool
}

var _ gifts.Repository = GiftsRepo{}

const giftItemColumns = `id, name, description, emoji, icon_asset, animation_asset, animation_duration_ms, sound_asset,
	tier, sort_order, diamond_price, active, available_from, available_until, earning_rule, retired_at, created_at, updated_at`

func scanGiftItem(row pgx.Row) (gifts.Item, error) {
	var i gifts.Item
	err := row.Scan(&i.ID, &i.Name, &i.Description, &i.Emoji, &i.IconAsset, &i.AnimationAsset, &i.AnimationDurationMs,
		&i.SoundAsset, &i.Tier, &i.SortOrder, &i.DiamondPrice, &i.Active, &i.AvailableFrom, &i.AvailableUntil,
		&i.EarningRule, &i.RetiredAt, &i.CreatedAt, &i.UpdatedAt)
	return i, err
}

func (r GiftsRepo) Catalogue(ctx context.Context, includeInactive bool) ([]gifts.Item, error) {
	rows, err := r.Pool.Query(ctx, `select `+giftItemColumns+` from gifts.catalogue
		where $1 or (active and retired_at is null) order by sort_order, diamond_price, id`, includeInactive)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []gifts.Item{}
	for rows.Next() {
		i, err := scanGiftItem(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, i)
	}
	return out, rows.Err()
}

func (r GiftsRepo) Item(ctx context.Context, id string) (gifts.Item, error) {
	i, err := scanGiftItem(r.Pool.QueryRow(ctx, `select `+giftItemColumns+` from gifts.catalogue where id = $1`, id))
	if errors.Is(err, pgx.ErrNoRows) {
		return i, gifts.ErrNotFound
	}
	return i, err
}

// giftTxSelect reads transactions with names, the gift's message and the
// catalogue's current animation duration. $-parameters follow the caller.
const giftTxSelect = `
	select t.id, t.sender_id, t.recipient_id, t.call_id, t.gift_id, t.gift_name, t.tier, t.emoji, t.animation_asset,
	       t.diamond_price, t.from_promotional, t.from_purchased, t.host_beans, t.rule_set_version,
	       t.ledger_entry_id, t.client_request_id, t.request_hash, t.risk_flags, t.created_at,
	       coalesce(sp.display_name, ''), coalesce(rp.display_name, ''), m.id, m.conversation_id,
	       coalesce(c.animation_duration_ms, 5000)
	  from gifts.transactions t
	  left join identity.profiles sp on sp.user_id = t.sender_id
	  left join identity.profiles rp on rp.user_id = t.recipient_id
	  left join chat.messages m on m.gift_transaction_id = t.id
	  left join gifts.catalogue c on c.id = t.gift_id`

func scanGiftTx(row pgx.Row) (gifts.Transaction, error) {
	var t gifts.Transaction
	err := row.Scan(&t.ID, &t.SenderID, &t.RecipientID, &t.CallID, &t.GiftID, &t.GiftName, &t.Tier, &t.Emoji, &t.AnimationAsset,
		&t.DiamondPrice, &t.FromPromotional, &t.FromPurchased, &t.HostBeans, &t.RuleSetVersion,
		&t.LedgerEntryID, &t.ClientRequestID, &t.RequestHash, &t.RiskFlags, &t.CreatedAt,
		&t.SenderName, &t.RecipientName, &t.ChatMessageID, &t.ConversationID, &t.AnimationDurMs)
	return t, err
}

func collectGiftTx(rows pgx.Rows, err error) ([]gifts.Transaction, error) {
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []gifts.Transaction{}
	for rows.Next() {
		t, err := scanGiftTx(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

func giftParty(ctx context.Context, tx pgx.Tx, userID string, now time.Time) (gifts.Party, error) {
	var p gifts.Party
	var created time.Time
	err := tx.QueryRow(ctx, `
		select a.status, a.age_eligible, coalesce(pr.display_name, ''), coalesce(h.state, ''), a.created_at
		  from identity.accounts a
		  left join identity.profiles pr on pr.user_id = a.id
		  left join hosting.hosts h on h.user_id = a.id
		 where a.id = $1`, userID).Scan(&p.Status, &p.AgeEligible, &p.DisplayName, &p.HostState, &created)
	if errors.Is(err, pgx.ErrNoRows) {
		return p, nil
	}
	if err != nil {
		return p, err
	}
	p.Exists, p.AccountAgeDur = true, now.Sub(created)
	return p, nil
}

// Send: see gifts.Repository. Lock order: the sender's Diamond balance rows
// first (serialises every send and call settlement of this customer), then
// the call row FOR SHARE (a concurrent settlement waits for the gift, and
// the gift cannot commit against a call that ended meanwhile).
func (r GiftsRepo) Send(ctx context.Context, req gifts.SendRequest, decide func(gifts.SendState) (gifts.SendPlan, error)) (gifts.Transaction, bool, error) {
	var out gifts.Transaction
	var replayed bool
	err := idTx(ctx, r.Pool, func(tx pgx.Tx) error {
		replayed = false
		bal, err := LockUserBalances(ctx, tx, req.SenderID, ledger.UserDiamondPromotional, ledger.UserDiamondPurchased)
		if err != nil {
			return err
		}
		st := gifts.SendState{Promotional: bal[ledger.UserDiamondPromotional], Purchased: bal[ledger.UserDiamondPurchased]}
		if st.Reserved, err = ActiveReservations(ctx, tx, req.SenderID); err != nil {
			return err
		}

		existing, err := scanGiftTx(tx.QueryRow(ctx, giftTxSelect+` where t.sender_id = $1 and t.client_request_id = $2`,
			req.SenderID, req.ClientRequestID))
		switch {
		case err == nil:
			st.Existing = &existing
		case !errors.Is(err, pgx.ErrNoRows):
			return err
		}
		if st.Existing == nil {
			if err := r.readSendState(ctx, tx, req, &st); err != nil {
				return err
			}
		}
		plan, err := decide(st)
		if err != nil {
			return err
		}
		if plan.Replay {
			out, replayed = plan.Transaction, true
			return nil
		}
		t := plan.Transaction
		entry, err := ledger.GiftSend(ledger.GiftCharge{
			GiftTransactionID: t.ID, CallID: t.CallID, CustomerID: t.SenderID, HostID: t.RecipientID, GiftID: t.GiftID,
			FromPromotional: t.FromPromotional, FromPurchased: t.FromPurchased, HostBeans: t.HostBeans,
			RuleSetVersion: t.RuleSetVersion, At: t.CreatedAt,
		})
		if err != nil {
			return err
		}
		entryID, dup, err := PostEntry(ctx, tx, entry)
		if errors.Is(err, ErrInsufficientBalance) {
			return gifts.ErrInsufficient
		}
		if err != nil {
			return err
		}
		if dup {
			return errors.New("gifts: ledger entry already exists for a new gift transaction")
		}
		t.LedgerEntryID = entryID
		if _, err := tx.Exec(ctx, `
			insert into gifts.transactions (id, sender_id, recipient_id, call_id, gift_id, gift_name, tier, emoji, animation_asset,
			  diamond_price, from_promotional, from_purchased, host_beans, rule_set_version, ledger_entry_id,
			  client_request_id, request_hash, risk_flags, created_at)
			values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19)`,
			t.ID, t.SenderID, t.RecipientID, t.CallID, t.GiftID, t.GiftName, t.Tier, t.Emoji, t.AnimationAsset,
			t.DiamondPrice, t.FromPromotional, t.FromPurchased, t.HostBeans, t.RuleSetVersion, t.LedgerEntryID,
			t.ClientRequestID, t.RequestHash, t.RiskFlags, t.CreatedAt); err != nil {
			return err
		}
		// The gift's chat line: an ordinary message of the pair's one
		// conversation, in this call's session (joins normal Chat when the
		// call ends). Unique gift_transaction_id: never a second line.
		var convID, msgID string
		if err := tx.QueryRow(ctx, `
			with ins as (
			  insert into chat.conversations (user_a, user_b)
			  values (least($1::uuid, $2::uuid), greatest($1::uuid, $2::uuid))
			  on conflict (user_a, user_b) do nothing
			  returning id
			)
			select id from ins
			union all
			select id from chat.conversations where user_a = least($1::uuid, $2::uuid) and user_b = greatest($1::uuid, $2::uuid)
			limit 1`, t.SenderID, t.RecipientID).Scan(&convID); errors.Is(err, pgx.ErrNoRows) {
			// Created concurrently (e.g. the host started the chat): re-read.
			if err := tx.QueryRow(ctx, `select id from chat.conversations
				where user_a = least($1::uuid, $2::uuid) and user_b = greatest($1::uuid, $2::uuid)`, t.SenderID, t.RecipientID).Scan(&convID); err != nil {
				return err
			}
		} else if err != nil {
			return err
		}
		if err := tx.QueryRow(ctx, `
			insert into chat.messages (conversation_id, sender_id, body, sent_at, context, call_id, kind, gift_transaction_id)
			values ($1, $2, $3, $4, 'call', $5, 'gift', $6) returning id`,
			convID, t.SenderID, plan.ChatBody, t.CreatedAt, t.CallID, t.ID).Scan(&msgID); err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `update chat.conversations set updated_at = greatest(updated_at, $2) where id = $1`, convID, t.CreatedAt); err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `
			insert into chat.read_markers (conversation_id, user_id, last_read_at) values ($1, $2, $3)
			on conflict (conversation_id, user_id) do update set last_read_at = greatest(chat.read_markers.last_read_at, excluded.last_read_at)`,
			convID, t.SenderID, t.CreatedAt); err != nil {
			return err
		}
		if err := callsGrantXP(ctx, tx, t.RecipientID, "bean_earning", "gift:"+t.ID, plan.XPDelta); err != nil {
			return err
		}
		t.ChatMessageID, t.ConversationID = &msgID, &convID
		out = t
		return nil
	})
	return out, replayed, err
}

func (r GiftsRepo) readSendState(ctx context.Context, tx pgx.Tx, req gifts.SendRequest, st *gifts.SendState) error {
	err := tx.QueryRow(ctx, `select id, caller_id, receiver_id, phase, is_free_call from calls.calls where id = $1 for share`, req.CallID).
		Scan(&st.Call.ID, &st.Call.CallerID, &st.Call.ReceiverID, &st.Call.Phase, &st.Call.IsFreeCall)
	switch {
	case err == nil:
		st.CallFound = true
	case !errors.Is(err, pgx.ErrNoRows):
		return err
	}
	g, err := scanGiftItem(tx.QueryRow(ctx, `select `+giftItemColumns+` from gifts.catalogue where id = $1 for share`, req.GiftID))
	switch {
	case err == nil:
		st.Gift, st.GiftFound = g, true
	case !errors.Is(err, pgx.ErrNoRows):
		return err
	}
	if st.Sender, err = giftParty(ctx, tx, req.SenderID, req.Now); err != nil {
		return err
	}
	if st.Recipient, err = giftParty(ctx, tx, req.RecipientID, req.Now); err != nil {
		return err
	}
	if err := tx.QueryRow(ctx, `select `+idBlockedEither("$1::uuid", "$2::uuid"), req.SenderID, req.RecipientID).Scan(&st.Blocked); err != nil {
		return err
	}
	return tx.QueryRow(ctx, `
		select count(*) filter (where call_id = $2 and created_at > $4::timestamptz - interval '1 minute'),
		       coalesce(sum(diamond_price), 0)::bigint,
		       coalesce(sum(diamond_price) filter (where recipient_id = $3), 0)::bigint
		  from gifts.transactions
		 where sender_id = $1 and created_at > $4::timestamptz - interval '24 hours'`,
		req.SenderID, req.CallID, req.RecipientID, req.Now).Scan(&st.SentInCallLastMinute, &st.SpentLast24h, &st.PairSpentLast24h)
}

func (r GiftsRepo) CallGifts(ctx context.Context, callID string) ([]gifts.Transaction, error) {
	return collectGiftTx(r.Pool.Query(ctx, giftTxSelect+` where t.call_id = $1 order by t.created_at, t.id`, callID))
}

func (r GiftsRepo) Call(ctx context.Context, callID string) (gifts.CallInfo, error) {
	var c gifts.CallInfo
	err := r.Pool.QueryRow(ctx, `select id, caller_id, receiver_id, phase, is_free_call from calls.calls where id = $1`, callID).
		Scan(&c.ID, &c.CallerID, &c.ReceiverID, &c.Phase, &c.IsFreeCall)
	if errors.Is(err, pgx.ErrNoRows) {
		return c, gifts.ErrNotFound
	}
	return c, err
}

func (r GiftsRepo) History(ctx context.Context, q gifts.HistoryQuery) ([]gifts.Transaction, error) {
	who := `true`
	switch q.As {
	case "sender":
		who = `t.sender_id = $1::uuid`
	case "recipient":
		who = `t.recipient_id = $1::uuid`
	case "any":
		who = `($1::text = '' or t.sender_id = nullif($1::text, '')::uuid or t.recipient_id = nullif($1::text, '')::uuid)`
	}
	return collectGiftTx(r.Pool.Query(ctx, giftTxSelect+`
		 where `+who+`
		   and ($2::text = '' or t.call_id = nullif($2::text, '')::uuid)
		   and (not $3 or t.risk_flags <> '{}')
		   and ($4::timestamptz is null or (t.created_at, t.id) < ($4::timestamptz, $5::uuid))
		 order by t.created_at desc, t.id desc
		 limit $6`, q.UserID, q.CallID, q.Flagged, q.BeforeAt, nullUUID(q.BeforeID), q.Limit))
}

func nullUUID(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func (r GiftsRepo) HostSummary(ctx context.Context, hostID string, since *time.Time) (gifts.HostSummary, error) {
	var s gifts.HostSummary
	err := r.Pool.QueryRow(ctx, `
		select count(*), coalesce(sum(diamond_price), 0)::bigint, coalesce(sum(host_beans), 0)::bigint
		  from gifts.transactions where recipient_id = $1 and ($2::timestamptz is null or created_at >= $2)`,
		hostID, since).Scan(&s.Count, &s.Diamonds, &s.Beans)
	return s, err
}

// ---------------------------------------------------------------- admin

func (r GiftsRepo) CreateItem(ctx context.Context, it gifts.Item, actorID, reason string) error {
	return idTx(ctx, r.Pool, func(tx pgx.Tx) error {
		_, err := tx.Exec(ctx, `
			insert into gifts.catalogue (id, name, description, emoji, icon_asset, animation_asset, animation_duration_ms,
			  sound_asset, tier, sort_order, diamond_price, active, available_from, available_until, earning_rule)
			values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15)`,
			it.ID, it.Name, it.Description, it.Emoji, it.IconAsset, it.AnimationAsset, it.AnimationDurationMs,
			it.SoundAsset, it.Tier, it.SortOrder, it.DiamondPrice, it.Active, it.AvailableFrom, it.AvailableUntil, it.EarningRule)
		if IsUniqueViolation(err) {
			return gifts.ErrExists
		}
		if err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `insert into gifts.price_changes (gift_id, old_price, new_price, changed_by, reason)
			values ($1, null, $2, $3, $4)`, it.ID, it.DiamondPrice, actorID, reason); err != nil {
			return err
		}
		return idAudit(ctx, tx, actorID, "gift.created", it.ID, map[string]any{"diamond_price": it.DiamondPrice, "active": it.Active, "tier": it.Tier})
	})
}

func (r GiftsRepo) UpdateItem(ctx context.Context, it gifts.Item, actorID string) error {
	return idTx(ctx, r.Pool, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `
			update gifts.catalogue set name = $2, description = $3, emoji = $4, icon_asset = $5, animation_asset = $6,
			  animation_duration_ms = $7, sound_asset = $8, tier = $9, sort_order = $10, active = $11,
			  available_from = $12, available_until = $13, retired_at = $14
			 where id = $1 and retired_at is null`,
			it.ID, it.Name, it.Description, it.Emoji, it.IconAsset, it.AnimationAsset, it.AnimationDurationMs, it.SoundAsset,
			it.Tier, it.SortOrder, it.Active, it.AvailableFrom, it.AvailableUntil, it.RetiredAt)
		if err != nil {
			return err
		}
		if tag.RowsAffected() == 0 {
			return gifts.ErrNotFound
		}
		return idAudit(ctx, tx, actorID, "gift.updated", it.ID, map[string]any{
			"active": it.Active, "sort_order": it.SortOrder, "tier": it.Tier, "retired": it.RetiredAt != nil,
			"available_from": it.AvailableFrom, "available_until": it.AvailableUntil, "animation_asset": it.AnimationAsset})
	})
}

func (r GiftsRepo) ChangePrice(ctx context.Context, p gifts.PricePatch) (int64, error) {
	var old int64
	err := idTx(ctx, r.Pool, func(tx pgx.Tx) error {
		err := tx.QueryRow(ctx, `select diamond_price from gifts.catalogue where id = $1 and retired_at is null for update`, p.GiftID).Scan(&old)
		if errors.Is(err, pgx.ErrNoRows) {
			return gifts.ErrNotFound
		}
		if err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `update gifts.catalogue set diamond_price = $2 where id = $1`, p.GiftID, p.NewPrice); err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `insert into gifts.price_changes (gift_id, old_price, new_price, changed_by, reason) values ($1,$2,$3,$4,$5)`,
			p.GiftID, old, p.NewPrice, p.ActorID, p.Reason); err != nil {
			return err
		}
		return idAudit(ctx, tx, p.ActorID, "gift.price_changed", p.GiftID, map[string]any{"from": old, "to": p.NewPrice, "reason": p.Reason})
	})
	return old, err
}

func (r GiftsRepo) PriceHistory(ctx context.Context, giftID string, limit int) ([]gifts.PriceChange, error) {
	rows, err := r.Pool.Query(ctx, `select old_price, new_price, changed_by, reason, changed_at from gifts.price_changes
		where gift_id = $1 order by changed_at desc, id desc limit $2`, giftID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []gifts.PriceChange{}
	for rows.Next() {
		var c gifts.PriceChange
		if err := rows.Scan(&c.OldPrice, &c.NewPrice, &c.ChangedBy, &c.Reason, &c.ChangedAt); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

func (r GiftsRepo) Performance(ctx context.Context, since time.Time) ([]gifts.Performance, error) {
	rows, err := r.Pool.Query(ctx, `
		select c.id, c.name, count(t.id), coalesce(sum(t.diamond_price), 0)::bigint, coalesce(sum(t.host_beans), 0)::bigint,
		       count(distinct t.sender_id), count(distinct t.recipient_id)
		  from gifts.catalogue c
		  left join gifts.transactions t on t.gift_id = c.id and t.created_at >= $1
		 group by c.id, c.name, c.sort_order
		 order by c.sort_order, c.id`, since)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []gifts.Performance{}
	for rows.Next() {
		var p gifts.Performance
		if err := rows.Scan(&p.GiftID, &p.GiftName, &p.Count, &p.Diamonds, &p.HostBeans, &p.UniqueSenders, &p.UniqueHosts); err != nil {
			return nil, err
		}
		out = append(out, p)
	}
	return out, rows.Err()
}
