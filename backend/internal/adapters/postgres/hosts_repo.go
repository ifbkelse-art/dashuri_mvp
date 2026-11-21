package postgres

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/modules/hosts"
	"dashuri/backend/internal/modules/ledger"
	"dashuri/backend/internal/platform/db"
)

// HostsRepo implements hosts.Repository.
type HostsRepo struct {
	Pool *pgxpool.Pool
	Tx   db.TxManager
}

var _ hosts.Repository = HostsRepo{}

// callsAudit appends an audit.events row (BE-calls areas: hosts, moderation).
func callsAudit(ctx context.Context, q Querier, actor, action, target string, details map[string]any) error {
	if details == nil {
		details = map[string]any{}
	}
	b, err := json.Marshal(details)
	if err != nil {
		return err
	}
	_, err = q.Exec(ctx, `insert into audit.events (actor, action, target, details) values ($1, $2, $3, $4)`, actor, action, target, b)
	return err
}

func (r HostsRepo) Host(ctx context.Context, userID string) (hosts.HostRow, error) {
	var h hosts.HostRow
	err := r.Pool.QueryRow(ctx, `select h.state, h.kyc_state, h.is_available, h.free_call_opt_in, h.rate_per_minute,
		  case when h.kyc_state = 'rejected' then
		    (select k.reason from hosting.kyc_sessions k where k.host_id = h.user_id and k.status = 'rejected'
		      order by coalesce(k.completed_at, k.created_at) desc limit 1) end
		from hosting.hosts h where h.user_id = $1`, userID).Scan(&h.State, &h.KycState, &h.IsAvailable, &h.FreeCallOptIn, &h.RatePerMinute, &h.KycRejectionReason)
	if errors.Is(err, pgx.ErrNoRows) {
		return h, nil
	}
	h.Exists = err == nil
	return h, err
}

func (r HostsRepo) LifetimeXP(ctx context.Context, userID string) (int64, error) {
	var xp int64
	err := r.Pool.QueryRow(ctx, `select coalesce(sum(xp_delta), 0)::bigint from ledger.xp_events where user_id = $1`, userID).Scan(&xp)
	return xp, err
}

func (r HostsRepo) Today(ctx context.Context, userID string, dayStart time.Time) (hosts.Today, error) {
	var t hosts.Today
	err := r.Pool.QueryRow(ctx, `
		select
		  (select coalesce(sum(p.amount), 0)::bigint
		     from ledger.postings p
		     join ledger.accounts a on a.id = p.account_id
		     join ledger.journal_entries e on e.id = p.entry_id
		    where a.owner_user_id = $1 and a.kind = 'bean_held' and p.amount > 0
		      and e.entry_type in ('call_settlement','free_call_compensation') and e.occurred_at >= $2),
		  (select count(*) from calls.calls
		    where receiver_id = $1 and connected_at is not null and ended_at >= $2)`, userID, dayStart).
		Scan(&t.EarnedBeans, &t.Calls)
	return t, err
}

func (r HostsRepo) Balances(ctx context.Context, userID string) (hosts.Balances, error) {
	var b hosts.Balances
	err := r.Pool.QueryRow(ctx, `
		select coalesce(sum(bl.balance) filter (where a.kind = 'bean_held'), 0)::bigint,
		       coalesce(sum(bl.balance) filter (where a.kind = 'bean_available'), 0)::bigint,
		       coalesce(sum(bl.balance) filter (where a.kind = 'bean_payout_pending'), 0)::bigint
		  from ledger.accounts a join ledger.balances bl on bl.account_id = a.id
		 where a.owner_user_id = $1`, userID).Scan(&b.Held, &b.Available, &b.PayoutPending)
	return b, err
}

func (r HostsRepo) Apply(ctx context.Context, userID string) error {
	return r.Tx.WithTx(ctx, pgx.ReadCommitted, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `insert into hosting.hosts (user_id, state) values ($1, 'applied') on conflict (user_id) do nothing`, userID)
		if err != nil {
			return err
		}
		if tag.RowsAffected() == 0 {
			return hosts.ErrAlreadyApplied
		}
		return callsAudit(ctx, tx, userID, "host.applied", userID, nil)
	})
}

func (r HostsRepo) StartKyc(ctx context.Context, userID, sessionID, provider string) (string, error) {
	var out string
	err := r.Tx.WithTx(ctx, pgx.ReadCommitted, func(tx pgx.Tx) error {
		if _, err := tx.Exec(ctx, `select 1 from hosting.hosts where user_id = $1 for update`, userID); err != nil {
			return err
		}
		err := tx.QueryRow(ctx, `select id from hosting.kyc_sessions where host_id = $1 and status = 'started'
			order by created_at desc limit 1`, userID).Scan(&out)
		if err == nil {
			return nil
		}
		if !errors.Is(err, pgx.ErrNoRows) {
			return err
		}
		out = sessionID
		if _, err := tx.Exec(ctx, `insert into hosting.kyc_sessions (id, host_id, status, provider) values ($1, $2, 'started', $3)`,
			sessionID, userID, provider); err != nil {
			return err
		}
		_, err = tx.Exec(ctx, `update hosting.hosts set state = 'kyc_pending', kyc_state = 'in_progress'
			where user_id = $1 and state in ('applied','kyc_pending')`, userID)
		return err
	})
	return out, err
}

func (r HostsRepo) SetAvailability(ctx context.Context, userID string, available bool, at time.Time) error {
	return r.Tx.WithTx(ctx, pgx.ReadCommitted, func(tx pgx.Tx) error {
		if _, err := tx.Exec(ctx, `select 1 from hosting.hosts where user_id = $1 for update`, userID); err != nil {
			return err
		}
		busy, err := callsUserInLiveCall(ctx, tx, userID)
		if err != nil {
			return err
		}
		if busy {
			return hosts.ErrInCall
		}
		_, err = tx.Exec(ctx, `update hosting.hosts set is_available = $2,
			last_heartbeat_at = case when $2 then $3 else last_heartbeat_at end
			where user_id = $1 and state = 'approved'`, userID, available, at)
		return err
	})
}

func (r HostsRepo) Heartbeat(ctx context.Context, userID string, at time.Time) error {
	_, err := r.Pool.Exec(ctx, `update hosting.hosts set last_heartbeat_at = $2 where user_id = $1`, userID, at)
	return err
}

func (r HostsRepo) SetRate(ctx context.Context, userID string, rate int64) error {
	_, err := r.Pool.Exec(ctx, `update hosting.hosts set rate_per_minute = $2 where user_id = $1`, userID, rate)
	return err
}

func (r HostsRepo) SetFreeCallOptIn(ctx context.Context, userID string, optIn bool) error {
	_, err := r.Pool.Exec(ctx, `update hosting.hosts set free_call_opt_in = $2 where user_id = $1`, userID, optIn)
	return err
}

func (r HostsRepo) DecideKyc(ctx context.Context, d hosts.KycDecision) error {
	return r.Tx.WithTx(ctx, pgx.ReadCommitted, func(tx pgx.Tx) error {
		var state string
		err := tx.QueryRow(ctx, `select state from hosting.hosts where user_id = $1 for update`, d.HostID).Scan(&state)
		if errors.Is(err, pgx.ErrNoRows) {
			return hosts.ErrNotFound
		}
		if err != nil {
			return err
		}
		var sessionID string
		err = tx.QueryRow(ctx, `select id from hosting.kyc_sessions where host_id = $1 and status = 'started'
			order by created_at desc limit 1 for update`, d.HostID).Scan(&sessionID)
		if errors.Is(err, pgx.ErrNoRows) {
			return hosts.ErrNoKycSession
		}
		if err != nil {
			return err
		}
		status := "rejected"
		if d.Approve {
			status = "approved"
		}
		if _, err := tx.Exec(ctx, `update hosting.kyc_sessions set status = $2, decided_by = $3, reason = nullif($4, ''),
			completed_at = $5 where id = $1`, sessionID, status, d.ModeratorID, d.Reason, d.At); err != nil {
			return err
		}
		if d.Approve {
			if _, err := tx.Exec(ctx, `update identity.accounts set date_of_birth = $2, age_method = 'kyc_verified',
				age_eligible = true,
				roles = case when 'host' = any(roles) then roles else array_append(roles, 'host') end
				where id = $1`, d.HostID, d.DateOfBirth); err != nil {
				return err
			}
			if _, err := tx.Exec(ctx, `update hosting.hosts set state = 'approved', kyc_state = 'approved', approved_at = $2
				where user_id = $1`, d.HostID, d.At); err != nil {
				return err
			}
		} else if _, err := tx.Exec(ctx, `update hosting.hosts set state = case when state = 'suspended' then state else 'applied' end,
			kyc_state = 'rejected', is_available = false where user_id = $1`, d.HostID); err != nil {
			return err
		}
		return callsAudit(ctx, tx, d.ModeratorID, "host.kyc_"+status, d.HostID, map[string]any{"session_id": sessionID, "reason": d.Reason})
	})
}

// MarkOffline takes hosts offline whose last heartbeat is older than cutoff
// (hosts in a live call are left alone).
func (r HostsRepo) MarkOffline(ctx context.Context, cutoff time.Time) (int64, error) {
	tag, err := r.Pool.Exec(ctx, `update hosting.hosts h set is_available = false
		where h.is_available and (h.last_heartbeat_at is null or h.last_heartbeat_at < $1)
		  and not exists (select 1 from calls.calls c where (c.caller_id = h.user_id or c.receiver_id = h.user_id)
		                    and c.phase in ('requested','ringing','accepted','connecting','active','paused','ending'))`, cutoff)
	return tag.RowsAffected(), err
}

// ReleaseDueBeanHolds posts BeanRelease (key bean_release:<source entry>) for
// every Bean credit to bean_held older than the hold period, capped by the
// current held balance (clawbacks may have reduced it). Bounded batch;
// replays are no-ops through the ledger idempotency key.
func (r HostsRepo) ReleaseDueBeanHolds(ctx context.Context, olderThan, at time.Time, limit int) (int, error) {
	rows, err := r.Pool.Query(ctx, `
		select p.entry_id, a.owner_user_id, p.amount
		  from ledger.postings p
		  join ledger.accounts a on a.id = p.account_id and a.kind = 'bean_held'
		  join ledger.journal_entries e on e.id = p.entry_id
		 where p.amount > 0 and e.entry_type in ('call_settlement','free_call_compensation') and e.occurred_at < $1
		   and not exists (select 1 from ledger.journal_entries r where r.idempotency_key = 'bean_release:' || p.entry_id::text)
		 order by e.occurred_at limit $2`, olderThan, limit)
	if err != nil {
		return 0, err
	}
	type due struct {
		entry, host string
		beans       int64
	}
	var items []due
	for rows.Next() {
		var d due
		if err := rows.Scan(&d.entry, &d.host, &d.beans); err != nil {
			rows.Close()
			return 0, err
		}
		items = append(items, d)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return 0, err
	}
	released := 0
	for _, d := range items {
		err := r.Tx.WithTx(ctx, pgx.ReadCommitted, func(tx pgx.Tx) error {
			bal, err := LockUserBalances(ctx, tx, d.host, ledger.UserBeanHeld, ledger.UserBeanAvailable)
			if err != nil {
				return err
			}
			beans := min(d.beans, bal[ledger.UserBeanHeld])
			if beans <= 0 {
				return nil
			}
			_, replayed, err := PostEntry(ctx, tx, ledger.BeanRelease(d.host, d.entry, beans, at))
			if err == nil && !replayed {
				released++
			}
			return err
		})
		if err != nil {
			return released, err
		}
	}
	return released, nil
}
