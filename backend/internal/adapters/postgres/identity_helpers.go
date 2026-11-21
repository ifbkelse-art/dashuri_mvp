package postgres

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/platform/db"
	"dashuri/backend/internal/platform/httpx"
)

// Shared SQL fragments for the identity/social repositories (accounts,
// discovery, chat, safety, notifications).

// idBlockedEither is a SQL predicate that is true when either user blocked the
// other. a and b are SQL expressions (placeholders or columns).
func idBlockedEither(a, b string) string {
	return fmt.Sprintf(`exists (select 1 from safety.blocks bl
		where (bl.blocker_id = %[1]s and bl.blocked_id = %[2]s)
		   or (bl.blocker_id = %[2]s and bl.blocked_id = %[1]s))`, a, b)
}

// idLifetimeXP is a SQL expression for a user's lifetime XP from ledger.user_xp.
func idLifetimeXP(userCol string) string {
	return fmt.Sprintf(`coalesce((select ux.lifetime_xp from ledger.user_xp ux where ux.user_id = %s), 0)`, userCol)
}

// idLiveCallPhases are the calls.calls phases that count as a live call
// (they match the one-live-call partial unique indexes).
const idLiveCallPhases = `('requested','ringing','accepted','connecting','active','paused','ending')`

// idInLiveCall is a SQL predicate: the user is in a live call.
func idInLiveCall(userCol string) string {
	return fmt.Sprintf(`exists (select 1 from calls.calls lc
		where (lc.caller_id = %[1]s or lc.receiver_id = %[1]s) and lc.phase in %[2]s)`, userCol, idLiveCallPhases)
}

func idTx(ctx context.Context, pool *pgxpool.Pool, fn func(pgx.Tx) error) error {
	return db.TxManager{Pool: pool}.WithTx(ctx, pgx.ReadCommitted, fn)
}

// idAudit appends an audit.events row. details must not contain personal data.
func idAudit(ctx context.Context, q Querier, actor, action, target string, details map[string]any) error {
	if details == nil {
		details = map[string]any{}
	}
	b, err := json.Marshal(details)
	if err != nil {
		return err
	}
	var rid *string
	if id := httpx.RequestID(ctx); id != "" {
		rid = &id
	}
	_, err = q.Exec(ctx, `insert into audit.events (actor, action, target, request_id, details) values ($1, $2, nullif($3, ''), $4, $5)`,
		actor, action, target, rid, b)
	return err
}
