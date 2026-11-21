package purchases

import (
	"time"

	"dashuri/backend/internal/modules/economy"
	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/clock"
)

// Deps are the ports this module needs; wired in internal/app/wire_purchases.go.
type Deps struct {
	Rules       economy.Rules
	Repo        Repository // nil without a database → 503 database_unavailable
	Clock       clock.Clock
	Events      Publisher // optional
	PackageName string

	// Google Play. Play nil → 503 play_not_configured.
	Play PlayDeveloperAPI
	Push PushAuthenticator // nil → RTDN refused (503)

	// Cashfree PG. CashfreeEnabled false → 503 rail_disabled;
	// Cashfree nil (no credentials) → 503 cashfree_not_configured.
	CashfreeEnabled   bool
	Cashfree          CashfreeAPI
	CashfreeReturnURL string
	// CashfreeOrderTTL is the order expiry (default 30 minutes).
	CashfreeOrderTTL time.Duration
}

func validationError(errs map[string]string) error { return apperr.Validation(errs) }
