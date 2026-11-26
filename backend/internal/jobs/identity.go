package jobs

import (
	"context"
	"errors"
	"log/slog"

	"github.com/jackc/pgx/v5"

	"dashuri/backend/internal/wiring"
)

func init() {
	Register(Job{
		Name: "execute-account-deletions", Schedule: "hourly",
		Doc: "Anonymise accounts whose 7-day deletion grace period has ended (DPDP). Re-checks that no Beans or live call remain.",
		Run: ExecuteAccountDeletions,
	})
}

// ExecuteAccountDeletions processes due deletion requests in bounded batches.
// Per account, in one transaction: re-check no Beans (held, available or
// pending) and no live call; otherwise reject the request. Then strip
// personal data (profile text, gender, city, photos, devices, consents),
// mark the account deleted and make a host unavailable. Ledger history,
// calls, reports and audit rows are retained (financial and legal records);
// unspent Diamonds stay on the ledger as a liability for the CA to treat
// (business report B4). The Supabase Auth user (phone number) must then be
// deleted through the Supabase Admin API by ops (see PROJECT_STATUS.md).
func ExecuteAccountDeletions(ctx context.Context, env wiring.Env) error {
	if env.Pool == nil {
		return errors.New("database not configured")
	}
	rows, err := env.Pool.Query(ctx, `
		select id, user_id from identity.data_requests
		 where kind = 'deletion' and status = 'received' and scheduled_for <= now()
		 order by scheduled_for limit 200`)
	if err != nil {
		return err
	}
	type req struct{ id, user string }
	var due []req
	for rows.Next() {
		var r req
		if err := rows.Scan(&r.id, &r.user); err != nil {
			rows.Close()
			return err
		}
		due = append(due, r)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return err
	}
	done, rejected := 0, 0
	for _, r := range due {
		outcome, err := deleteOne(ctx, env, r.id, r.user)
		if err != nil {
			slog.Error("account deletion failed", "request_id", r.id, "err", err)
			continue
		}
		if outcome == "completed" {
			done++
		} else {
			rejected++
		}
	}
	slog.Info("account deletions processed", "completed", done, "rejected", rejected)
	return nil
}

func deleteOne(ctx context.Context, env wiring.Env, requestID, userID string) (string, error) {
	outcome := ""
	err := env.Tx.WithTx(ctx, pgx.ReadCommitted, func(tx pgx.Tx) error {
		var status string
		if err := tx.QueryRow(ctx, `select status from identity.data_requests where id = $1 for update`, requestID).Scan(&status); err != nil {
			return err
		}
		if status != "received" {
			outcome = "skipped"
			return nil
		}
		var beans int64
		if err := tx.QueryRow(ctx, `
			select coalesce(sum(b.balance), 0) from ledger.accounts a join ledger.balances b on b.account_id = a.id
			 where a.owner_user_id = $1 and a.kind in ('bean_held','bean_available','bean_payout_pending')`, userID).Scan(&beans); err != nil {
			return err
		}
		var live bool
		if err := tx.QueryRow(ctx, `
			select exists (select 1 from calls.calls where (caller_id = $1 or receiver_id = $1)
			   and phase in ('requested','ringing','accepted','connecting','active','paused','ending'))`, userID).Scan(&live); err != nil {
			return err
		}
		if beans > 0 || live {
			outcome = "rejected"
			_, err := tx.Exec(ctx, `update identity.data_requests set status = 'rejected', completed_at = now() where id = $1`, requestID)
			return err
		}
		stmts := []string{
			`update identity.profiles set display_name = 'Deleted user', bio = null, languages = '{}', gender = null, city_id = null where user_id = $1`,
			`delete from identity.profile_photos where user_id = $1`,
			`delete from notify.devices where user_id = $1`,
			`update identity.consents set analytics = false, marketing = false, updated_at = now() where user_id = $1`,
			`select set_config('dashuri.offline_reason', 'host_ineligible', true), $1::uuid`,
			`update hosting.hosts set is_available = false, free_call_opt_in = false where user_id = $1`,
			`update identity.accounts set status = 'deleted', deleted_at = now(), date_of_birth = null where id = $1`,
		}
		for _, s := range stmts {
			if _, err := tx.Exec(ctx, s, userID); err != nil {
				return err
			}
		}
		if _, err := tx.Exec(ctx, `update identity.data_requests set status = 'completed', completed_at = now() where id = $1`, requestID); err != nil {
			return err
		}
		_, err := tx.Exec(ctx, `insert into audit.events (actor, action, target, details) values ('system:execute-account-deletions', 'account.deleted', $1, jsonb_build_object('request_id', $2::text))`, userID, requestID)
		outcome = "completed"
		return err
	})
	return outcome, err
}
