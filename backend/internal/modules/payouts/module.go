package payouts

import (
	"context"
	"errors"
	"net/http"
	"strconv"

	"dashuri/backend/internal/modules/economy"
	"dashuri/backend/internal/modules/ledger"
	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/clock"
)

// Deps are the ports this module needs; wired in internal/app/wire_payouts.go.
type Deps struct {
	Rules    economy.Rules
	Repo     Repository     // nil → 503 database_unavailable
	Provider PayoutProvider // nil: no payout provider has been chosen (R3-7)
	Enabled  bool           // PAYOUTS_ENABLED
	Clock    clock.Clock
}

// Eligibility is what a host needs before requesting a withdrawal.
type Eligibility struct {
	HostApproved   bool
	KYCApproved    bool
	PayoutVerified bool // payouts.beneficiaries row with name_verified
}

var (
	ErrInsufficient = errors.New("payouts: insufficient available beans")
	ErrNotHost      = errors.New("payouts: no host record")
)

// Repository is the payouts persistence port (internal/adapters/postgres/payouts_repo.go).
type Repository interface {
	Eligibility(ctx context.Context, hostID string) (Eligibility, error)
	// RequestWithdrawal, in one transaction: locks bean_available, refuses
	// beans > available (ErrInsufficient), posts entry(withdrawalID) and
	// inserts the withdrawal row, plus the audit event.
	RequestWithdrawal(ctx context.Context, hostID string, beans, amountPaise int64, entry func(withdrawalID string) ledger.Entry) (Withdrawal, error)
	ListWithdrawals(ctx context.Context, hostID, cursor string, limit int) ([]Withdrawal, string, error)
}

// ErrBadCursor: the cursor does not decode.
var ErrBadCursor = errors.New("payouts: invalid cursor")

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

func validationError(errs map[string]string) error { return apperr.Validation(errs) }
