package postgres

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/modules/calls"
	"dashuri/backend/internal/modules/ledger"
	"dashuri/backend/internal/platform/db"
)

// CallsRepo implements calls.Repository.
type CallsRepo struct {
	Pool *pgxpool.Pool
	Tx   db.TxManager
}

var _ calls.Repository = CallsRepo{}

const callsColumns = `id, caller_id, receiver_id, phase, rate_per_minute, is_free_call, coalesce(provider_call_id, ''),
	rule_set_version, end_reason, billed_seconds, diamonds_charged, created_at, accepted_at, connected_at, ended_at,
	moderation_window_ends_at, last_event_at, low_balance_notified_at, free_call_compensated,
	(select st.beans_earned from calls.settlements st where st.call_id = id)`

func callsScanOne(row pgx.Row) (calls.Call, error) {
	var c calls.Call
	var phase string
	err := row.Scan(&c.ID, &c.CallerID, &c.ReceiverID, &phase, &c.RatePerMinute, &c.IsFreeCall, &c.ProviderCallID,
		&c.RuleSetVersion, &c.EndReason, &c.BilledSeconds, &c.DiamondsCharged, &c.CreatedAt, &c.AcceptedAt, &c.ConnectedAt,
		&c.EndedAt, &c.ModerationWindowEndsAt, &c.LastEventAt, &c.LowBalanceNotifiedAt, &c.FreeCallCompensated, &c.BeansEarned)
	if errors.Is(err, pgx.ErrNoRows) {
		return c, calls.ErrNotFound
	}
	c.Phase = calls.Phase(phase)
	return c, err
}

func callsScanAll(rows pgx.Rows, err error) ([]calls.Call, error) {
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []calls.Call
	for rows.Next() {
		c, err := callsScanOne(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

func (r CallsRepo) InTx(ctx context.Context, fn func(calls.Tx) error) error {
	return r.Tx.WithTx(ctx, pgx.ReadCommitted, func(tx pgx.Tx) error {
		return fn(callsTx{ctx: ctx, tx: tx})
	})
}

func (r CallsRepo) GetCall(ctx context.Context, id string) (calls.Call, error) {
	return callsScanOne(r.Pool.QueryRow(ctx, `select `+callsColumns+` from calls.calls where id = $1`, id))
}

func (r CallsRepo) History(ctx context.Context, userID string, beforeAt *time.Time, beforeID string, limit int) ([]calls.Call, error) {
	if beforeAt == nil {
		return callsScanAll(r.Pool.Query(ctx, `select `+callsColumns+` from calls.calls
			where caller_id = $1 or receiver_id = $1 order by created_at desc, id desc limit $2`, userID, limit))
	}
	return callsScanAll(r.Pool.Query(ctx, `select `+callsColumns+` from calls.calls
		where (caller_id = $1 or receiver_id = $1) and (created_at, id) < ($2, $3::uuid)
		order by created_at desc, id desc limit $4`, userID, *beforeAt, beforeID, limit))
}

func (r CallsRepo) Peers(ctx context.Context, ids []string) (map[string]calls.Peer, error) {
	out := map[string]calls.Peer{}
	if len(ids) == 0 {
		return out, nil
	}
	rows, err := r.Pool.Query(ctx, `
		select a.id, coalesce(p.display_name, '')
		  from identity.accounts a left join identity.profiles p on p.user_id = a.id
		 where a.id = any($1::uuid[])`, ids)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var p calls.Peer
		if err := rows.Scan(&p.UserID, &p.DisplayName); err != nil {
			return nil, err
		}
		out[p.UserID] = p
	}
	return out, rows.Err()
}

func callsMediaEvents(ctx context.Context, q Querier, callID string) ([]calls.MediaEvent, error) {
	rows, err := q.Query(ctx, `select coalesce(user_id::text, ''), kind, occurred_at from calls.media_events
		where call_id = $1 order by occurred_at, received_at`, callID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []calls.MediaEvent
	for rows.Next() {
		var e calls.MediaEvent
		if err := rows.Scan(&e.UserID, &e.Kind, &e.At); err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

func (r CallsRepo) MediaEvents(ctx context.Context, callID string) ([]calls.MediaEvent, error) {
	return callsMediaEvents(ctx, r.Pool, callID)
}

func (r CallsRepo) InsertMediaEvent(ctx context.Context, callID string, e calls.ProviderEvent) (bool, error) {
	var user *string
	if e.UserID != "" {
		user = &e.UserID
	}
	inserted := false
	err := pgx.BeginTxFunc(ctx, r.Pool, pgx.TxOptions{}, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `insert into calls.media_events (provider_event_id, call_id, user_id, kind, occurred_at)
			values ($1, $2, $3, $4, $5) on conflict (provider_event_id) do nothing`, e.EventID, callID, user, e.Kind, e.At)
		if err != nil {
			return err
		}
		inserted = tag.RowsAffected() == 1
		if !inserted {
			return nil
		}
		_, err = tx.Exec(ctx, `update calls.calls set last_event_at = greatest(coalesce(last_event_at, $2), $2) where id = $1`, callID, e.At)
		return err
	})
	return inserted, err
}

func (r CallsRepo) LiveCalls(ctx context.Context, limit int) ([]calls.Call, error) {
	return callsScanAll(r.Pool.Query(ctx, `select `+callsColumns+` from calls.calls
		where phase in ('requested','ringing','accepted','connecting','active','paused','ending')
		order by created_at limit $1`, limit))
}

// callsTx implements calls.Tx on one pgx transaction.
type callsTx struct {
	ctx context.Context
	tx  pgx.Tx
}

func (t callsTx) LockCall(id string) (calls.Call, error) {
	return callsScanOne(t.tx.QueryRow(t.ctx, `select `+callsColumns+` from calls.calls where id = $1 for update`, id))
}

func (t callsTx) LockHost(hostID string) (calls.HostForCall, error) {
	var h calls.HostForCall
	err := t.tx.QueryRow(t.ctx, `
		select h.state, h.is_available, h.rate_per_minute, a.status, a.age_eligible
		  from hosting.hosts h join identity.accounts a on a.id = h.user_id
		 where h.user_id = $1 for update of h`, hostID).
		Scan(&h.State, &h.Available, &h.RatePerMinute, &h.AccountStatus, &h.AgeEligible)
	if errors.Is(err, pgx.ErrNoRows) {
		return h, nil
	}
	h.Exists = err == nil
	return h, err
}

func (t callsTx) Blocked(a, b string) (bool, error) { return callsBlockedEitherWay(t.ctx, t.tx, a, b) }

func callsBlockedEitherWay(ctx context.Context, q Querier, a, b string) (bool, error) {
	var blocked bool
	err := q.QueryRow(ctx, `select exists (select 1 from safety.blocks
		where (blocker_id = $1 and blocked_id = $2) or (blocker_id = $2 and blocked_id = $1))`, a, b).Scan(&blocked)
	return blocked, err
}

func callsUserInLiveCall(ctx context.Context, q Querier, userID string) (bool, error) {
	var busy bool
	err := q.QueryRow(ctx, `select exists (select 1 from calls.calls
		where (caller_id = $1 or receiver_id = $1)
		  and phase in ('requested','ringing','accepted','connecting','active','paused','ending'))`, userID).Scan(&busy)
	return busy, err
}

func (t callsTx) InLiveCall(userID string) (bool, error) {
	return callsUserInLiveCall(t.ctx, t.tx, userID)
}

func (t callsTx) LockDiamonds(userID string) (int64, int64, error) {
	bal, err := LockUserBalances(t.ctx, t.tx, userID, ledger.UserDiamondPromotional, ledger.UserDiamondPurchased)
	if err != nil {
		return 0, 0, err
	}
	return bal[ledger.UserDiamondPromotional], bal[ledger.UserDiamondPurchased], nil
}

func (t callsTx) ActiveReservationsTotal(userID string) (int64, error) {
	return ActiveReservations(t.ctx, t.tx, userID)
}

func (t callsTx) LockReservation(callID string) (calls.Reservation, bool, error) {
	var r calls.Reservation
	err := t.tx.QueryRow(t.ctx, `select id, user_id, call_id, amount, status from ledger.diamond_reservations
		where call_id = $1 for update`, callID).Scan(&r.ID, &r.UserID, &r.CallID, &r.Amount, &r.Status)
	if errors.Is(err, pgx.ErrNoRows) {
		return r, false, nil
	}
	return r, err == nil, err
}

// callsMapLiveViolation translates the one-live-call indexes into domain errors.
func callsMapLiveViolation(err error) error {
	switch {
	case IsUniqueViolation(err, "one_live_call_as_caller"), IsUniqueViolation(err, "one_active_reservation_per_user"):
		return calls.ErrCallerInCall
	case IsUniqueViolation(err, "one_live_call_as_receiver"):
		return calls.ErrHostBusy
	}
	return err
}

func callsInsertCall(ctx context.Context, q Querier, c calls.Call) error {
	_, err := q.Exec(ctx, `insert into calls.calls
		(id, caller_id, receiver_id, phase, rate_per_minute, is_free_call, provider, provider_call_id, rule_set_version, created_at)
		values ($1, $2, $3, $4, $5, $6, 'stream', $7, $8, $9)`,
		c.ID, c.CallerID, c.ReceiverID, string(c.Phase), c.RatePerMinute, c.IsFreeCall, c.ProviderCallID, c.RuleSetVersion, c.CreatedAt)
	return callsMapLiveViolation(err)
}

func (t callsTx) InsertCall(c calls.Call) error { return callsInsertCall(t.ctx, t.tx, c) }

func (t callsTx) InsertReservation(userID, callID string, amount int64) error {
	_, err := t.tx.Exec(t.ctx, `insert into ledger.diamond_reservations (user_id, call_id, amount) values ($1, $2, $3)`,
		userID, callID, amount)
	return callsMapLiveViolation(err)
}

func (t callsTx) SetReservationAmount(callID string, amount int64) error {
	_, err := t.tx.Exec(t.ctx, `update ledger.diamond_reservations set amount = $2, updated_at = now()
		where call_id = $1 and status = 'active'`, callID, amount)
	return err
}

func (t callsTx) CloseReservation(callID, status string) error {
	_, err := t.tx.Exec(t.ctx, `update ledger.diamond_reservations set status = $2, updated_at = now()
		where call_id = $1 and status = 'active'`, callID, status)
	return err
}

func (t callsTx) UpdatePhase(id string, from, to calls.Phase, u calls.PhaseUpdate) (bool, error) {
	tag, err := t.tx.Exec(t.ctx, `update calls.calls set phase = $3,
		accepted_at = coalesce($4, accepted_at), connected_at = coalesce($5, connected_at),
		moderation_window_ends_at = coalesce($6, moderation_window_ends_at), ended_at = coalesce($7, ended_at),
		end_reason = coalesce($8, end_reason), billed_seconds = coalesce($9, billed_seconds),
		diamonds_charged = coalesce($10, diamonds_charged)
		where id = $1 and phase = $2`,
		id, string(from), string(to), u.AcceptedAt, u.ConnectedAt, u.ModerationWindowEndsAt, u.EndedAt, u.EndReason,
		u.BilledSeconds, u.DiamondsCharged)
	return tag.RowsAffected() == 1, err
}

func (t callsTx) MediaEvents(callID string) ([]calls.MediaEvent, error) {
	return callsMediaEvents(t.ctx, t.tx, callID)
}

func (t callsTx) PostEntry(e ledger.Entry) (string, bool, error) {
	id, replayed, err := PostEntry(t.ctx, t.tx, e)
	if errors.Is(err, ErrInsufficientBalance) {
		return "", false, calls.ErrInsufficientBalance
	}
	return id, replayed, err
}

func (t callsTx) InsertSettlement(s calls.Settlement) error {
	_, err := t.tx.Exec(t.ctx, `insert into calls.settlements (call_id, entry_id, billed_seconds, diamonds_charged, beans_earned)
		values ($1, $2, $3, $4, $5) on conflict (call_id) do nothing`,
		s.CallID, s.EntryID, s.BilledSeconds, s.DiamondsCharged, s.BeansEarned)
	return err
}

func (t callsTx) GrantXP(userID, sourceType, sourceID string, delta int64) error {
	return callsGrantXP(t.ctx, t.tx, userID, sourceType, sourceID, delta)
}

func callsGrantXP(ctx context.Context, q Querier, userID, sourceType, sourceID string, delta int64) error {
	if delta == 0 {
		return nil
	}
	_, err := q.Exec(ctx, `insert into ledger.xp_events (user_id, source_type, source_id, xp_delta) values ($1, $2, $3, $4)
		on conflict (source_type, source_id) do nothing`, userID, sourceType, sourceID, delta)
	return err
}

func (t callsTx) SetLowBalanceNotified(callID string, at time.Time) error {
	_, err := t.tx.Exec(t.ctx, `update calls.calls set low_balance_notified_at = $2 where id = $1`, callID, at)
	return err
}

func (t callsTx) MarkFreeCallCompensated(callID string) error {
	_, err := t.tx.Exec(t.ctx, `update calls.calls set free_call_compensated = true where id = $1`, callID)
	return err
}

func (t callsTx) ReleaseFreeCard(callID string) error {
	var userID, hostID string
	var day time.Time
	err := t.tx.QueryRow(t.ctx, `
		update freecall.requests set status = 'cancelled' where call_id = $1 and status = 'matched'
		returning user_id, host_id, (created_at at time zone 'Asia/Kolkata')::date`, callID).Scan(&userID, &hostID, &day)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil
	}
	if err != nil {
		return err
	}
	if _, err := t.tx.Exec(t.ctx, `update freecall.cards set status = 'available', used_at = null
		where user_id = $1 and status = 'used'`, userID); err != nil {
		return err
	}
	_, err = t.tx.Exec(t.ctx, `update freecall.host_daily_counts set count = count - 1
		where host_id = $1 and day = $2 and count > 0`, hostID, day)
	return err
}
