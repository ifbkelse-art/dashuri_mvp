package jobs

import (
	"context"
	"log/slog"

	"dashuri/backend/internal/app"
	"dashuri/backend/internal/wiring"
)

// Arrival photo jobs (2026-11-26).

func init() {
	Register(Job{
		Name: "purge-arrival-photos", Schedule: "every 15 min",
		Doc: "Expire arrival-photo upload tickets older than 10 minutes, then delete objects of ended arrival photos (expired/removed 24 h after ending, rejected after 7 days; kept while a report about them is open). Metadata rows stay.",
		Run: PurgeArrivalPhotos,
	})
}

// PurgeArrivalPhotos applies the arrival-photo retention policy.
func PurgeArrivalPhotos(ctx context.Context, env wiring.Env) error {
	expired, purged, err := app.WireHostsForJobs(env).PurgeArrivalPhotos(ctx, env.Clock.Now())
	if err == nil && (expired > 0 || purged > 0) {
		slog.Info("arrival photos", "tickets_expired", expired, "objects_purged", purged)
	}
	return err
}
