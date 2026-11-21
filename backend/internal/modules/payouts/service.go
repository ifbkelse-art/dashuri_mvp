package payouts

import (
	"context"
	"errors"

	"dashuri/backend/internal/modules/ledger"
	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/clock"
)

// Service implements host withdrawals. No payout provider is chosen yet
// (R3-7), so PAYOUTS_ENABLED stays false and requests are refused with 503
// payouts_not_enabled before any Beans move. The weekly cycle builder and
// provider submission plug in behind PayoutProvider once one is accepted.
type Service struct {
	deps Deps
}

func NewService(d Deps) *Service {
	if d.Clock == nil {
		d.Clock = clock.System{}
	}
	return &Service{deps: d}
}

var errDB = apperr.Unavailable("database_unavailable", "database not configured")

// RequestWithdrawal: POST /v1/host/withdrawals.
//  1. 503 payouts_not_enabled until PAYOUTS_ENABLED (checked first: no Beans move).
//  2. Account not restricted; host approved with KYC; payout method verified.
//  3. One transaction: lock bean_available; MinWithdrawalBeans ≤ beans ≤ available;
//     post ledger.WithdrawalRequested and insert the withdrawal (status requested).
func (s *Service) RequestWithdrawal(ctx context.Context, p auth.Principal, in WithdrawalRequest) (Withdrawal, error) {
	if !s.deps.Enabled {
		return Withdrawal{}, apperr.Unavailable("payouts_not_enabled", "withdrawals are not available yet")
	}
	if s.deps.Repo == nil {
		return Withdrawal{}, errDB
	}
	if in.Beans < s.deps.Rules.MinWithdrawalBeans() {
		return Withdrawal{}, apperr.BusinessRule("below_minimum_withdrawal", "the minimum withdrawal is ₹500 (100,000 Beans)")
	}
	if p.Restricted() {
		return Withdrawal{}, apperr.BusinessRule("account_restricted", "this account is restricted")
	}
	el, err := s.deps.Repo.Eligibility(ctx, p.UserID)
	if err != nil {
		return Withdrawal{}, apperr.Internal(err)
	}
	if !el.HostApproved || !el.KYCApproved {
		return Withdrawal{}, apperr.BusinessRule("kyc_required", "host verification must be approved first")
	}
	if !el.PayoutVerified {
		return Withdrawal{}, apperr.BusinessRule("payout_method_missing", "add and verify a payout method first")
	}
	now := s.deps.Clock.Now()
	w, err := s.deps.Repo.RequestWithdrawal(ctx, p.UserID, in.Beans, s.deps.Rules.PaiseForBeans(in.Beans), func(id string) ledger.Entry {
		return ledger.WithdrawalRequested(p.UserID, id, in.Beans, now)
	})
	if errors.Is(err, ErrInsufficient) {
		return Withdrawal{}, apperr.BusinessRule("insufficient_available_beans", "not enough withdrawable Beans")
	}
	if err != nil {
		return Withdrawal{}, apperr.Internal(err)
	}
	return w, nil
}

// ListWithdrawals: GET /v1/host/withdrawals (own withdrawals, newest first).
// Reading history works even while payouts are disabled.
func (s *Service) ListWithdrawals(ctx context.Context, p auth.Principal, page PageRequest) (Page[Withdrawal], error) {
	if s.deps.Repo == nil {
		return Page[Withdrawal]{}, errDB
	}
	items, next, err := s.deps.Repo.ListWithdrawals(ctx, p.UserID, page.Cursor, page.Limit)
	if errors.Is(err, ErrBadCursor) {
		return Page[Withdrawal]{}, apperr.Validation(map[string]string{"cursor": "invalid"})
	}
	if err != nil {
		return Page[Withdrawal]{}, apperr.Internal(err)
	}
	if items == nil {
		items = []Withdrawal{}
	}
	out := Page[Withdrawal]{Items: items}
	if next != "" {
		out.NextCursor = &next
	}
	return out, nil
}
