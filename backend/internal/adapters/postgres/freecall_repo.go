package postgres

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/modules/calls"
	"dashuri/backend/internal/modules/freecall"
	"dashuri/backend/internal/platform/db"
)

// FreecallRepo implements freecall.Repository.
type FreecallRepo struct {
	Pool *pgxpool.Pool
	Tx   db.TxManager
}

var _ freecall.Repository = FreecallRepo{}

// PhoneHash returns sha256(auth.users.phone) via a definer function, so the
// number itself never reaches the API.
func (r FreecallRepo) PhoneHash(ctx context.Context, userID string) (string, error) {
	var h *string
	if err := r.Pool.QueryRow(ctx, `select freecall.phone_hash($1)`, userID).Scan(&h); err != nil {
		return "", err
	}
	if h == nil {
		return "", nil
	}
	return *h, nil
}

func (r FreecallRepo) Card(ctx context.Context, userID string) (freecall.CardRow, error) {
	var c freecall.CardRow
	err := r.Pool.QueryRow(ctx, `select status, used_at from freecall.cards where user_id = $1`, userID).Scan(&c.Status, &c.UsedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return c, nil
	}
	c.Exists = err == nil
	return c, err
}

func (r FreecallRepo) PhoneUsedByOther(ctx context.Context, userID, phoneHash string) (bool, error) {
	var used bool
	err := r.Pool.QueryRow(ctx, `select exists (select 1 from freecall.cards where phone_hash = $2 and user_id <> $1)`,
		userID, phoneHash).Scan(&used)
	return used, err
}

func freecallMapCardViolation(err error) error {
	switch {
	case IsUniqueViolation(err, "cards_phone_hash"):
		return freecall.ErrCardUsed
	case IsUniqueViolation(err, "cards_device_binding_hash"):
		return freecall.ErrDeviceUsed
	case IsUniqueViolation(err, "one_live_call_as_caller"):
		return freecall.ErrCallerInCall
	}
	return err
}

func (r FreecallRepo) Match(ctx context.Context, m freecall.MatchParams) (freecall.RequestRow, error) {
	var out freecall.RequestRow
	err := r.Tx.WithTx(ctx, pgx.ReadCommitted, func(tx pgx.Tx) error {
		out = freecall.RequestRow{}
		if _, err := tx.Exec(ctx, `insert into freecall.cards (user_id, phone_hash, device_binding_hash) values ($1, $2, $3)
			on conflict (user_id) do nothing`, m.UserID, m.PhoneHash, m.DeviceHash); err != nil {
			return freecallMapCardViolation(err)
		}
		var status string
		var device *string
		if err := tx.QueryRow(ctx, `select status, device_binding_hash from freecall.cards where user_id = $1 for update`,
			m.UserID).Scan(&status, &device); err != nil {
			return err
		}
		if status != "available" {
			return freecall.ErrCardUsed
		}
		if device == nil || *device != m.DeviceHash {
			if _, err := tx.Exec(ctx, `update freecall.cards set device_binding_hash = $2 where user_id = $1`, m.UserID, m.DeviceHash); err != nil {
				return freecallMapCardViolation(err)
			}
		}
		if busy, err := callsUserInLiveCall(ctx, tx, m.UserID); err != nil {
			return err
		} else if busy {
			return freecall.ErrCallerInCall
		}
		hostID := ""
		excluded := []string{}
		for attempt := 0; attempt < 10 && hostID == ""; attempt++ {
			var cand string
			err := tx.QueryRow(ctx, `
				select h.user_id from hosting.hosts h join identity.accounts a on a.id = h.user_id
				 where h.state = 'approved' and h.is_available and h.free_call_opt_in and a.status = 'active'
				   and h.user_id <> $1 and not (h.user_id::text = any($2::text[]))
				   and not exists (select 1 from safety.blocks b
				                    where (b.blocker_id = $1 and b.blocked_id = h.user_id) or (b.blocker_id = h.user_id and b.blocked_id = $1))
				   and not exists (select 1 from calls.calls c
				                    where (c.caller_id = h.user_id or c.receiver_id = h.user_id)
				                      and c.phase in ('requested','ringing','accepted','connecting','active','paused','ending'))
				   and coalesce((select d.count from freecall.host_daily_counts d
				                  where d.host_id = h.user_id and d.day = ($3::timestamptz at time zone 'Asia/Kolkata')::date), 0) < $4
				 order by random() limit 1
				 for update of h skip locked`, m.UserID, excluded, m.Now, m.MaxPerHostPerDay).Scan(&cand)
			if errors.Is(err, pgx.ErrNoRows) {
				break
			}
			if err != nil {
				return err
			}
			// The daily counter row, locked: the cap holds under concurrency.
			if _, err := tx.Exec(ctx, `insert into freecall.host_daily_counts (host_id, day, count)
				values ($1, ($2::timestamptz at time zone 'Asia/Kolkata')::date, 0) on conflict (host_id, day) do nothing`, cand, m.Now); err != nil {
				return err
			}
			var count int
			if err := tx.QueryRow(ctx, `select count from freecall.host_daily_counts
				where host_id = $1 and day = ($2::timestamptz at time zone 'Asia/Kolkata')::date for update`, cand, m.Now).Scan(&count); err != nil {
				return err
			}
			if count >= m.MaxPerHostPerDay {
				excluded = append(excluded, cand)
				continue
			}
			if _, err := tx.Exec(ctx, `update freecall.host_daily_counts set count = count + 1
				where host_id = $1 and day = ($2::timestamptz at time zone 'Asia/Kolkata')::date`, cand, m.Now); err != nil {
				return err
			}
			hostID = cand
		}
		if hostID == "" {
			return tx.QueryRow(ctx, `insert into freecall.requests (user_id, status, created_at) values ($1, 'no_host_available', $2)
				returning id, user_id, status, call_id`, m.UserID, m.Now).Scan(&out.ID, &out.UserID, &out.Status, &out.CallID)
		}
		if err := callsInsertCall(ctx, tx, calls.Call{
			ID: m.CallID, CallerID: m.UserID, ReceiverID: hostID, Phase: calls.Ringing, RatePerMinute: 0, IsFreeCall: true,
			ProviderCallID: m.CallID, RuleSetVersion: m.RuleSetVersion, CreatedAt: m.Now,
		}); err != nil {
			if errors.Is(err, calls.ErrCallerInCall) {
				return freecall.ErrCallerInCall
			}
			return err
		}
		if _, err := tx.Exec(ctx, `update freecall.cards set status = 'used', used_at = $2 where user_id = $1`, m.UserID, m.Now); err != nil {
			return err
		}
		return tx.QueryRow(ctx, `insert into freecall.requests (user_id, status, call_id, host_id, created_at)
			values ($1, 'matched', $2, $3, $4) returning id, user_id, status, call_id`, m.UserID, m.CallID, hostID, m.Now).
			Scan(&out.ID, &out.UserID, &out.Status, &out.CallID)
	})
	return out, err
}

func (r FreecallRepo) Request(ctx context.Context, id string) (freecall.RequestRow, error) {
	var out freecall.RequestRow
	err := r.Pool.QueryRow(ctx, `select id, user_id, status, call_id from freecall.requests where id = $1`, id).
		Scan(&out.ID, &out.UserID, &out.Status, &out.CallID)
	if errors.Is(err, pgx.ErrNoRows) {
		return out, freecall.ErrNotFound
	}
	return out, err
}
