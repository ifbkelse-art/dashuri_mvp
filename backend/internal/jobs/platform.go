package jobs

import (
	"context"
	"log/slog"

	"dashuri/backend/internal/wiring"
)

func init() {
	Register(Job{
		Name: "purge-expired-idempotency", Schedule: "daily 03:00",
		Doc: "Delete idempotency keys past their 24 h expiry.",
		Run: func(ctx context.Context, env wiring.Env) error {
			tag, err := env.Pool.Exec(ctx, `delete from platform.idempotency_keys where expires_at < now()`)
			if err == nil {
				slog.Info("purged idempotency keys", "rows", tag.RowsAffected())
			}
			return err
		},
	})
}
