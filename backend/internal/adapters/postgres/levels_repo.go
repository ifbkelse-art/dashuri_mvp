package postgres

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/modules/levels"
)

// LevelsRepo implements levels.Repository on ledger.user_xp.
type LevelsRepo struct{ Pool *pgxpool.Pool }

var _ levels.Repository = LevelsRepo{}

func (r LevelsRepo) LifetimeXP(ctx context.Context, userID string) (int64, error) {
	var xp int64
	err := r.Pool.QueryRow(ctx, `select `+idLifetimeXP("$1::uuid"), userID).Scan(&xp)
	return xp, err
}
