package jobs

import (
	"context"
	"log/slog"
	"time"

	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/app"
	"dashuri/backend/internal/wiring"
)

// Calls, hosts and moderation jobs (BE-calls). Each is idempotent and bounded.

// SweepInterval and SweepDuration: settle-stale-calls is scheduled every
// minute and sweeps every 5 s for ~55 s, so ring/connect timeouts, pauses,
// reservation extension and the 30 s low-balance warning stay timely.
const (
	SweepInterval = 5 * time.Second
	SweepDuration = 55 * time.Second
)

func init() {
	Register(Job{
		Name: "settle-stale-calls", Schedule: "every 1 min",
		Doc: "Ringing > 30 s → missed; not active 45 s after accept → failed; nobody live 90 s → end and settle; balance checks.",
		Run: SettleStaleCalls,
	})
	Register(Job{
		Name: "mark-offline-hosts", Schedule: "every 1 min",
		Doc: "Hosts with no heartbeat for 90 s go offline.",
		Run: MarkOfflineHosts,
	})
	Register(Job{
		Name: "moderation-missing-frames", Schedule: "every 1 min",
		Doc: "Queue a review when a participant sent no moderation frame for 60 s in the first 3 minutes.",
		Run: ModerationMissingFrames,
	})
	Register(Job{
		Name: "release-bean-holds", Schedule: "hourly",
		Doc: "BeanRelease for held Beans older than 7 days (key per source entry).",
		Run: ReleaseBeanHolds,
	})
}

// SettleStaleCalls runs Sweep repeatedly for about a minute.
func SettleStaleCalls(ctx context.Context, env wiring.Env) error {
	svc := app.BuildCalls(env)
	deadline := env.Clock.Now().Add(SweepDuration)
	for {
		res, err := svc.Sweep(ctx, env.Clock.Now())
		if err != nil {
			return err
		}
		if res.Missed+res.Failed+res.Ended > 0 {
			slog.Info("calls sweep", "examined", res.Examined, "missed", res.Missed, "failed", res.Failed, "ended", res.Ended)
		}
		if !env.Clock.Now().Add(SweepInterval).Before(deadline) {
			return nil
		}
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(SweepInterval):
		}
	}
}

// MarkOfflineHosts takes hosts without a heartbeat for 90 s offline.
func MarkOfflineHosts(ctx context.Context, env wiring.Env) error {
	n, err := postgres.HostsRepo{Pool: env.Pool, Tx: env.Tx}.MarkOffline(ctx, env.Clock.Now().Add(-90*time.Second))
	if err == nil && n > 0 {
		slog.Info("hosts marked offline", "rows", n)
	}
	return err
}

// ModerationMissingFrames queues reviews for silent participants.
func ModerationMissingFrames(ctx context.Context, env wiring.Env) error {
	n, err := app.BuildModeration(env).CheckMissingFrames(ctx, env.Clock.Now())
	if err == nil && n > 0 {
		slog.Info("moderation reviews queued", "cases", n)
	}
	return err
}

// ReleaseBeanHolds releases Beans whose 7-day hold has ended.
func ReleaseBeanHolds(ctx context.Context, env wiring.Env) error {
	now := env.Clock.Now()
	repo := postgres.HostsRepo{Pool: env.Pool, Tx: env.Tx}
	total := 0
	for i := 0; i < 20; i++ {
		n, hosts, err := repo.ReleaseDueBeanHoldsFor(ctx, now.Add(-env.Rules.BeanHoldPeriod), now, 500)
		total += n
		walletsChanged(ctx, env, "bean_release", hosts)
		if err != nil {
			return err
		}
		if n == 0 {
			break
		}
	}
	if total > 0 {
		slog.Info("bean holds released", "entries", total)
	}
	return nil
}
