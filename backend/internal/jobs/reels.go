package jobs

import (
	"context"
	"log/slog"

	"dashuri/backend/internal/app"
	"dashuri/backend/internal/wiring"
)

// EXPERIMENT — Dashuri Reels jobs. Each is idempotent, bounded and a no-op
// while REELS_ENABLED=false.

func init() {
	Register(Job{
		Name: "reels-moderate", Schedule: "every 1 min",
		Doc: "Automated frame check for ready reels; uncertain/unavailable → human review (fail closed).",
		Run: reelsJob("moderated", func(ctx context.Context, env wiring.Env) (int, error) {
			return app.BuildReels(env).ModeratePending(ctx, 25)
		}),
	})
	Register(Job{
		Name: "reels-reconcile-uploads", Schedule: "every 5 min",
		Doc: "Polls the video provider for uploads/assets whose webhook never arrived.",
		Run: reelsJob("reconciled", func(ctx context.Context, env wiring.Env) (int, error) {
			return app.BuildReels(env).ReconcileUploads(ctx, 100)
		}),
	})
	Register(Job{
		Name: "reels-purge-media", Schedule: "hourly",
		Doc: "Deletes provider media of deleted/rejected/removed reels after any 90-day evidence hold.",
		Run: reelsJob("purged", func(ctx context.Context, env wiring.Env) (int, error) {
			return app.BuildReels(env).PurgeMedia(ctx, 200)
		}),
	})
	Register(Job{
		Name: "reels-account-cleanup", Schedule: "daily 03:30",
		Doc: "Removes Reels content, likes and follows of accounts deleted by execute-account-deletions.",
		Run: reelsJob("accounts", func(ctx context.Context, env wiring.Env) (int, error) {
			return app.BuildReels(env).CleanupDeletedAccounts(ctx, 200)
		}),
	})
}

func reelsJob(what string, run func(context.Context, wiring.Env) (int, error)) func(context.Context, wiring.Env) error {
	return func(ctx context.Context, env wiring.Env) error {
		if !env.Config.ReelsEnabled || env.Pool == nil {
			slog.InfoContext(ctx, "reels disabled; job skipped")
			return nil
		}
		n, err := run(ctx, env)
		slog.InfoContext(ctx, "reels job done", what, n)
		return err
	}
}
