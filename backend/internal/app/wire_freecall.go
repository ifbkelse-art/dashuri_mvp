package app

import (
	"log/slog"

	"dashuri/backend/internal/adapters/playintegrity"
	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/freecall"
	"dashuri/backend/internal/wiring"
)

// wireFreecall builds the freecall module from shared infrastructure. The
// Play Integrity verifier needs GOOGLE_APPLICATION_CREDENTIALS and
// PLAY_PACKAGE_NAME; without them requests get 503 integrity_not_configured.
func wireFreecall(env wiring.Env) *freecall.Service {
	d := freecall.Deps{Rules: env.Rules, Enabled: env.Config.FreeCallEnabled, Clock: env.Clock, Calls: BuildCalls(env)}
	v, err := playintegrity.New(env.Config.GoogleCredentialsFile, env.Config.PlayPackageName, env.HTTP)
	if err != nil {
		slog.Error("play integrity verifier disabled", "err", err)
	} else if v != nil {
		d.Integrity = v
	}
	if env.Pool != nil {
		d.Repo = postgres.FreecallRepo{Pool: env.Pool, Tx: env.Tx}
	}
	return freecall.NewService(d)
}
