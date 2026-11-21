// Command worker runs scheduled jobs as Cloud Run Jobs, triggered by Cloud
// Scheduler: `worker <job>`. Every job is idempotent (safe to re-run) and
// processes work in bounded batches. Jobs register themselves in
// internal/jobs.
package main

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"time"

	"dashuri/backend/internal/adapters/supabase"
	"dashuri/backend/internal/jobs"
	"dashuri/backend/internal/modules/economy"
	"dashuri/backend/internal/platform/clock"
	"dashuri/backend/internal/platform/config"
	"dashuri/backend/internal/platform/db"
	"dashuri/backend/internal/platform/logging"
	"dashuri/backend/internal/wiring"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		slog.Error("config", "err", err)
		os.Exit(1)
	}
	slog.SetDefault(logging.New(cfg.Env))
	if len(os.Args) < 2 {
		fmt.Println("usage: worker <job>")
		for _, j := range jobs.All() {
			fmt.Printf("  %-27s %-16s %s\n", j.Name, j.Schedule, j.Doc)
		}
		os.Exit(2)
	}
	job, ok := jobs.Get(os.Args[1])
	if !ok {
		slog.Error("unknown job", "job", os.Args[1])
		os.Exit(2)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Minute)
	defer cancel()
	pool, err := db.Open(ctx, cfg.DatabaseURL)
	if err != nil {
		slog.Error("database", "err", err)
		os.Exit(1)
	}
	defer pool.Close()
	env := wiring.Env{
		Config: cfg, Pool: pool, Tx: db.TxManager{Pool: pool}, Rules: economy.Founder(), Clock: clock.System{},
		Realtime: supabase.Publisher{BaseURL: cfg.SupabaseURL, APIKey: cfg.RealtimeAPIKey},
		HTTP:     &http.Client{Timeout: 15 * time.Second},
	}
	start := time.Now()
	if err := job.Run(ctx, env); err != nil {
		slog.Error("job failed", "job", job.Name, "err", err)
		os.Exit(1)
	}
	slog.Info("job done", "job", job.Name, "duration_ms", time.Since(start).Milliseconds())
}
