package payouts

import (
	"context"
	"time"
)

// PayoutProvider is provider-independent (Cashfree is NOT confirmed; see
// business-model-report B3). Candidate adapters: a payout API, or a bank
// bulk-transfer file export for manual upload. Each adapter lives in
// internal/adapters/payouts/<name> and is selected by configuration.
type PayoutProvider interface {
	Name() string
	// VerifyBeneficiary confirms the bank account / UPI ID belongs to the
	// KYC-verified host (name match). Never store full account numbers in logs.
	VerifyBeneficiary(ctx context.Context, b Beneficiary) (verified bool, err error)
	// SubmitBatch sends one weekly cycle. Must be idempotent on batchID.
	SubmitBatch(ctx context.Context, batchID string, items []PayoutItem) error
	// Status reports per-item outcomes (webhook or polling).
	Status(ctx context.Context, batchID string) ([]PayoutResult, error)
}

type Beneficiary struct {
	HostID     string
	LegalName  string
	VPA        string // UPI ID, or
	AccountRef string // tokenised bank account reference
}

type PayoutItem struct {
	WithdrawalID string
	HostID       string
	AmountPaise  int64 // gross; TDS withheld per CA advice (section unresolved)
	TDSPaise     int64
}

type PayoutResult struct {
	WithdrawalID string
	Paid         bool
	ProviderRef  string
	FailureCode  string
	At           time.Time
}
