package postgres

import (
	"context"
	"encoding/base64"
	"errors"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

// Querier is satisfied by *pgxpool.Pool, *pgx.Conn and pgx.Tx.
type Querier interface {
	Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
	Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

func pgCode(err error) (string, string) {
	var pg *pgconn.PgError
	if errors.As(err, &pg) {
		return pg.Code, pg.ConstraintName
	}
	return "", ""
}

// IsUniqueViolation reports a 23505 error, optionally on a named constraint.
func IsUniqueViolation(err error, constraint ...string) bool {
	code, name := pgCode(err)
	if code != "23505" {
		return false
	}
	if len(constraint) == 0 {
		return true
	}
	for _, c := range constraint {
		if name == c || strings.HasPrefix(name, c) {
			return true
		}
	}
	return false
}

// IsCheckViolation reports a 23514 error.
func IsCheckViolation(err error) bool { c, _ := pgCode(err); return c == "23514" }

// IsForeignKeyViolation reports a 23503 error.
func IsForeignKeyViolation(err error) bool { c, _ := pgCode(err); return c == "23503" }

// Cursor is an opaque keyset cursor: (timestamp, id) encoded as base64.
type Cursor struct {
	At time.Time
	ID string
}

// EncodeCursor returns the opaque token for the last row of a page.
func EncodeCursor(at time.Time, id string) string {
	return base64.RawURLEncoding.EncodeToString([]byte(at.UTC().Format(time.RFC3339Nano) + "|" + id))
}

// DecodeCursor parses a token; an empty token means "first page".
func DecodeCursor(s string) (*Cursor, error) {
	if s == "" {
		return nil, nil
	}
	b, err := base64.RawURLEncoding.DecodeString(s)
	if err != nil {
		return nil, errors.New("invalid cursor")
	}
	at, id, ok := strings.Cut(string(b), "|")
	if !ok {
		return nil, errors.New("invalid cursor")
	}
	t, err := time.Parse(time.RFC3339Nano, at)
	if err != nil {
		return nil, errors.New("invalid cursor")
	}
	return &Cursor{At: t, ID: id}, nil
}
