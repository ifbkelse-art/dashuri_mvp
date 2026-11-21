// Command api serves the Dashuri REST API on Cloud Run.
package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/app"
	"dashuri/backend/internal/platform/config"
	"dashuri/backend/internal/platform/db"
	"dashuri/backend/internal/platform/logging"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		slog.Error("config", "err", err)
		os.Exit(1)
	}
	slog.SetDefault(logging.New(cfg.Env))

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	var pool *pgxpool.Pool
	if cfg.DatabaseURL != "" {
		if pool, err = db.Open(ctx, cfg.DatabaseURL); err != nil {
			slog.Error("database", "err", err)
			os.Exit(1)
		}
		defer pool.Close()
	} else {
		slog.Warn("DATABASE_URL not set; /readyz will report not ready")
	}

	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           app.New(cfg, pool),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       60 * time.Second,
	}
	go func() {
		slog.Info("listening", "port", cfg.Port, "env", cfg.Env)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			slog.Error("server", "err", err)
			stop()
		}
	}()
	<-ctx.Done()
	shutdown, cancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
	defer cancel()
	_ = srv.Shutdown(shutdown)
}
