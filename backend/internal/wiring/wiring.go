// Package wiring carries the shared infrastructure every module is built
// from. internal/app builds one Env and passes it to each module's wire
// function (internal/app/wire_<module>.go).
package wiring

import (
	"context"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/modules/economy"
	"dashuri/backend/internal/platform/clock"
	"dashuri/backend/internal/platform/config"
	"dashuri/backend/internal/platform/db"
)

// Publisher pushes server events to Realtime private channels.
type Publisher interface {
	Publish(ctx context.Context, channel, event string, payload any) error
}

// Env is the composition context. Pool may be nil in development without a
// database; services must then return 503 database_unavailable.
type Env struct {
	Config   config.Config
	Pool     *pgxpool.Pool
	Tx       db.TxManager
	Rules    economy.Rules
	Clock    clock.Clock
	Realtime Publisher
	HTTP     *http.Client
}
