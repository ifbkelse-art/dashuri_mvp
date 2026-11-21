package levels

import (
	"context"

	"dashuri/backend/internal/modules/economy"
)

// Repository reads lifetime XP (ledger.user_xp).
type Repository interface {
	LifetimeXP(ctx context.Context, userID string) (int64, error)
}

// Deps are the ports this module needs. Repo is nil without a database.
type Deps struct {
	Rules economy.Rules
	Repo  Repository
}
