// Package db owns the Postgres connection pool and transactions.
//
// Financial writes run in a transaction with row locks (SELECT … FOR UPDATE)
// on the affected balance rows, in a fixed lock order (ascending account id)
// to prevent deadlocks. Serialization or deadlock failures are retried a
// bounded number of times; every retried operation is idempotent by design.
package db

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Open connects to Postgres. The URL uses the dedicated `api_service` role.
func Open(ctx context.Context, url string) (*pgxpool.Pool, error) {
	cfg, err := pgxpool.ParseConfig(url)
	if err != nil {
		return nil, fmt.Errorf("db: parse url: %w", err)
	}
	cfg.MaxConns = 10 // per Cloud Run instance; size against the pooler limit
	return pgxpool.NewWithConfig(ctx, cfg)
}

// TxManager runs functions inside transactions.
type TxManager struct{ Pool *pgxpool.Pool }

const maxRetries = 3

// WithTx runs fn in a transaction at the given isolation level, retrying on
// serialization failure (40001) or deadlock (40P01).
func (m TxManager) WithTx(ctx context.Context, iso pgx.TxIsoLevel, fn func(pgx.Tx) error) error {
	var err error
	for attempt := 0; attempt < maxRetries; attempt++ {
		err = pgx.BeginTxFunc(ctx, m.Pool, pgx.TxOptions{IsoLevel: iso}, fn)
		if !retryable(err) {
			return err
		}
	}
	return err
}

func retryable(err error) bool {
	var pg *pgconn.PgError
	return errors.As(err, &pg) && (pg.Code == "40001" || pg.Code == "40P01")
}
