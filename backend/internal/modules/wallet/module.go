package wallet

import (
	"context"
	"errors"
	"net/http"
	"strconv"
	"time"

	"dashuri/backend/internal/platform/apperr"
)

// Deps are the ports this module needs; wired in internal/app/wire_wallet.go.
type Deps struct {
	Repo Repository // nil → 503 database_unavailable
}

// Balances are the user's ledger projection rows (by account kind) plus
// the Diamonds reserved for a live call.
type Balances struct {
	ByKind   map[string]int64
	Reserved int64
}

// EntryRow is one journal entry as seen by one user, per currency.
type EntryRow struct {
	EntryID    string
	EntryType  string
	Reference  string
	OccurredAt time.Time
	Currency   string
	Net        int64 // sum of the user's postings in this currency
	Available  int64 // sum of the user's bean_available postings
}

// ErrBadCursor: the cursor does not decode.
var ErrBadCursor = errors.New("wallet: invalid cursor")

// Repository is the wallet read model (internal/adapters/postgres/wallet_repo.go).
type Repository interface {
	Balances(ctx context.Context, userID string) (Balances, error)
	// Entries pages the user's entries newest first (keyset on occurred_at, entry id).
	Entries(ctx context.Context, userID, cursor string, limit int) (rows []EntryRow, next string, err error)
}

// PageRequest is a parsed cursor page request.
type PageRequest struct {
	Cursor string
	Limit  int
}

// Page is the list envelope {items, next_cursor}.
type Page[T any] struct {
	Items      []T     `json:"items"`
	NextCursor *string `json:"next_cursor,omitempty"`
}

func parsePage(r *http.Request) (PageRequest, error) {
	p := PageRequest{Cursor: r.URL.Query().Get("cursor"), Limit: 20}
	if v := r.URL.Query().Get("limit"); v != "" {
		n, err := strconv.Atoi(v)
		if err != nil || n < 1 || n > 100 {
			return p, apperr.Validation(map[string]string{"limit": "must_be_1_to_100"})
		}
		p.Limit = n
	}
	return p, nil
}
