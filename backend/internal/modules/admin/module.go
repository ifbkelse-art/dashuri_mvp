package admin

import (
	"context"
	"errors"
	"regexp"
	"time"

	"dashuri/backend/internal/modules/economy"
	"dashuri/backend/internal/modules/ledger"
	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/clock"
)

// Deps are the ports this module needs; wired in internal/app/wire_admin.go.
type Deps struct {
	Repo           Repository // nil → 503 database_unavailable
	Rules          economy.Rules
	Clock          clock.Clock
	PayoutsEnabled bool // PAYOUTS_ENABLED (R3-7)
	// Console is the read model for the admin web console (nil → 503).
	Console ConsoleRepository
	// Events pushes wallet.updated to the adjusted user (optional).
	Events Publisher
}

// Publisher sends realtime hints (satisfied by wiring.Publisher).
type Publisher interface {
	Publish(ctx context.Context, channel, event string, payload any) error
}

// Reconciliation is the raw result of a reconciliation run.
type Reconciliation struct {
	AsOf                time.Time
	PurchasedDiamonds   int64
	PromotionalDiamonds int64
	HostBeans           int64
	UnbalancedEntries   int
	Drifts              []AccountDrift
}

// Proposal is one ledger.adjustment_proposals row with its account.
type Proposal struct {
	ID         string
	Account    ledger.AccountRef
	Amount     int64
	Reason     string
	ProposedBy string
	Status     string
	EntryID    string
}

var (
	ErrProposalNotFound   = errors.New("admin: proposal not found")
	ErrProposalNotPending = errors.New("admin: proposal not awaiting approval")
	ErrSameApprover       = errors.New("admin: approver must differ from proposer")
	ErrOwnAccount         = errors.New("admin: staff cannot adjust an account they own or proposed for")
	ErrUnknownAccount     = errors.New("admin: account owner not found")
	ErrCycleNotFound      = errors.New("admin: payout cycle not found")
	ErrCycleNotReady      = errors.New("admin: payout cycle not ready")
	ErrOverdraw           = errors.New("admin: adjustment would make a balance negative")
)

// Repository is the admin module's persistence port
// (internal/adapters/postgres/admin_repo.go).
type Repository interface {
	Reconcile(ctx context.Context) (Reconciliation, error)
	// ProposeAdjustment stores a proposal (and its audit event) in one transaction.
	ProposeAdjustment(ctx context.Context, account ledger.AccountRef, amount int64, reason, proposedBy string) (string, error)
	// DecideAdjustment locks the proposal; approve → posts build(p) and marks
	// it posted, reject → marks it rejected; audit event in the same transaction.
	DecideAdjustment(ctx context.Context, proposalID, decidedBy string, approve bool, build func(Proposal) (ledger.Entry, error)) (Proposal, error)
	ApprovePayoutCycle(ctx context.Context, cycleID, approvedBy string) (string, error)
	Audit(ctx context.Context, actor, action, target string, details map[string]any) error
}

func validationError(errs map[string]string) error { return apperr.Validation(errs) }

var uuidRE = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)

func isUUID(s string) bool { return uuidRE.MatchString(s) }
