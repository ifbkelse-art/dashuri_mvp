package payouts

import (
	"context"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
)

// Service implements the payouts module's use cases. Every method is a
// scaffold that returns 501 until implemented; the documented steps are the
// required behaviour (see docs/architecture).
type Service struct {
	deps Deps
}

func NewService(d Deps) *Service { return &Service{deps: d} }

// RequestWithdrawal: POST /v1/host/withdrawals — Request a withdrawal into the next weekly payout cycle.
//  1. Return 503 payouts_not_enabled until PAYOUTS_ENABLED (R3-7: incorporation + provider onboarding).
//  2. Check host approved, KYC passed, payout method verified, no restriction or open fraud case.
//  3. In one transaction: lock the host's bean_available balance row; check beans ≥ MinWithdrawalBeans (₹500 = 100,000 Beans) and ≤ available.
//  4. Insert withdrawal (status requested) and post ledger.WithdrawalRequested (available → payout_pending).
//  5. The weekly payout-cycle job picks it up.
func (s *Service) RequestWithdrawal(ctx context.Context, p auth.Principal, in WithdrawalRequest) (Withdrawal, error) {
	return Withdrawal{}, apperr.NotImplemented("payouts.RequestWithdrawal")
}

// ListWithdrawals: GET /v1/host/withdrawals — Withdrawal history.
func (s *Service) ListWithdrawals(ctx context.Context, p auth.Principal, page PageRequest) (Page[Withdrawal], error) {
	return Page[Withdrawal]{}, apperr.NotImplemented("payouts.ListWithdrawals")
}
