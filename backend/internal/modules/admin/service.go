package admin

import (
	"context"
	"errors"
	"log/slog"
	"strings"

	"dashuri/backend/internal/modules/ledger"
	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/clock"
)

// Service implements finance administration: reconciliation, dual-control
// adjustments and payout-cycle approval. Every staff action is audited.
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

// Report converts a run to the wire type.
func (s *Service) Report(rc Reconciliation) ReconciliationReport {
	drifts := rc.Drifts
	if drifts == nil {
		drifts = []AccountDrift{}
	}
	return ReconciliationReport{
		AsOf: rc.AsOf, CustomerDiamondLiability: rc.PurchasedDiamonds, HostBeanLiability: rc.HostBeans,
		Discrepancies:               len(rc.Drifts) + rc.UnbalancedEntries,
		PromotionalDiamondLiability: rc.PromotionalDiamonds,
		HostBeanLiabilityPaise:      s.deps.Rules.PaiseForBeans(rc.HostBeans),
		UnbalancedEntries:           rc.UnbalancedEntries,
		DriftedAccounts:             drifts,
	}
}

// Reconcile recomputes every balance from postings (used by the job too).
func (s *Service) Reconcile(ctx context.Context) (ReconciliationReport, error) {
	if s.deps.Repo == nil {
		return ReconciliationReport{}, errDB
	}
	rc, err := s.deps.Repo.Reconcile(ctx)
	if err != nil {
		return ReconciliationReport{}, apperr.Internal(err)
	}
	return s.Report(rc), nil
}

// GetReconciliation: GET /v1/admin/ledger/reconciliation.
func (s *Service) GetReconciliation(ctx context.Context, p auth.Principal) (ReconciliationReport, error) {
	rep, err := s.Reconcile(ctx)
	if err != nil {
		return rep, err
	}
	if err := s.deps.Repo.Audit(ctx, p.UserID, "ledger.reconciliation_viewed", "", map[string]any{"discrepancies": rep.Discrepancies}); err != nil {
		return ReconciliationReport{}, apperr.Internal(err)
	}
	return rep, nil
}

var userKinds = map[string]ledger.AccountKind{
	string(ledger.UserDiamondPurchased): ledger.UserDiamondPurchased, string(ledger.UserDiamondPromotional): ledger.UserDiamondPromotional,
	string(ledger.UserBeanHeld): ledger.UserBeanHeld, string(ledger.UserBeanAvailable): ledger.UserBeanAvailable,
	string(ledger.UserBeanPayoutPending): ledger.UserBeanPayoutPending,
}

// ParseAccount accepts "user:<uuid>:<kind>" or "<uuid>:<kind>" for a user wallet bucket.
func ParseAccount(s string) (ledger.AccountRef, bool) {
	s = strings.TrimPrefix(s, "user:")
	id, kind, ok := strings.Cut(s, ":")
	if !ok || !isUUID(id) {
		return ledger.AccountRef{}, false
	}
	k, ok := userKinds[kind]
	if !ok {
		return ledger.AccountRef{}, false
	}
	return ledger.User(strings.ToLower(id), k), true
}

// ProposeAdjustment: POST /v1/admin/ledger/adjustments — a proposal only;
// a second, different finance/admin user posts it via …/{id}/approve.
func (s *Service) ProposeAdjustment(ctx context.Context, p auth.Principal, in AdjustmentRequest) (AdjustmentProposal, error) {
	if s.deps.Repo == nil {
		return AdjustmentProposal{}, errDB
	}
	acct, ok := ParseAccount(in.Account)
	if !ok {
		return AdjustmentProposal{}, apperr.Validation(map[string]string{"account": "invalid_value"})
	}
	if string(ledger.CurrencyOf(acct.Kind)) != in.Currency {
		return AdjustmentProposal{}, apperr.Validation(map[string]string{"currency": "does_not_match_account"})
	}
	id, err := s.deps.Repo.ProposeAdjustment(ctx, acct, in.Amount, in.Reason, p.UserID)
	if errors.Is(err, ErrUnknownAccount) {
		return AdjustmentProposal{}, apperr.NotFound("account owner")
	}
	if errors.Is(err, ErrOwnAccount) {
		return AdjustmentProposal{}, apperr.Forbidden("conflict_of_interest", "you cannot propose an adjustment to your own account")
	}
	if err != nil {
		return AdjustmentProposal{}, apperr.Internal(err)
	}
	return AdjustmentProposal{ProposalId: id, Status: "awaiting_second_approval"}, nil
}

// DecideAdjustment: POST /v1/admin/ledger/adjustments/{id}/approve|reject.
// The decider must differ from the proposer (dual control).
func (s *Service) DecideAdjustment(ctx context.Context, p auth.Principal, proposalID string, approve bool) (AdjustmentProposal, error) {
	if s.deps.Repo == nil {
		return AdjustmentProposal{}, errDB
	}
	if !isUUID(proposalID) {
		return AdjustmentProposal{}, apperr.NotFound("proposal")
	}
	now := s.deps.Clock.Now()
	pr, err := s.deps.Repo.DecideAdjustment(ctx, proposalID, p.UserID, approve, func(pr Proposal) (ledger.Entry, error) {
		return ledger.Adjustment(pr.ID, pr.Account, pr.Amount, pr.Reason, pr.ProposedBy, p.UserID, now)
	})
	switch {
	case errors.Is(err, ErrProposalNotFound):
		return AdjustmentProposal{}, apperr.NotFound("proposal")
	case errors.Is(err, ErrOwnAccount):
		return AdjustmentProposal{}, apperr.Forbidden("conflict_of_interest", "you cannot propose or approve an adjustment to your own account, or to the proposer's")
	case errors.Is(err, ErrSameApprover):
		return AdjustmentProposal{}, apperr.BusinessRule("second_approver_required", "a different staff member must decide this adjustment")
	case errors.Is(err, ErrProposalNotPending):
		return AdjustmentProposal{}, apperr.BusinessRule("adjustment_not_pending", "this adjustment was already decided")
	case errors.Is(err, ErrOverdraw):
		return AdjustmentProposal{}, apperr.BusinessRule("adjustment_would_overdraw", "the adjustment would make the balance negative")
	case err != nil:
		return AdjustmentProposal{}, apperr.Internal(err)
	}
	out := AdjustmentProposal{ProposalId: pr.ID, Status: pr.Status}
	if pr.EntryID != "" {
		out.EntryId = &pr.EntryID
		if s.deps.Events != nil && pr.Account.UserID != "" {
			if err := s.deps.Events.Publish(ctx, "user:"+pr.Account.UserID, "wallet.updated",
				map[string]any{"reason": "adjustment"}); err != nil {
				slog.WarnContext(ctx, "wallet.updated publish failed", "err", err)
			}
		}
	}
	return out, nil
}

// ApprovePayoutCycle: POST /v1/admin/payout-cycles/{cycleId}/approve.
// 503 payouts_not_enabled while PAYOUTS_ENABLED=false (R3-7).
func (s *Service) ApprovePayoutCycle(ctx context.Context, p auth.Principal, cycleID string) (PayoutCycleApproval, error) {
	if !s.deps.PayoutsEnabled {
		return PayoutCycleApproval{}, apperr.Unavailable("payouts_not_enabled", "payouts are not enabled yet")
	}
	if s.deps.Repo == nil {
		return PayoutCycleApproval{}, errDB
	}
	if !isUUID(cycleID) {
		return PayoutCycleApproval{}, apperr.NotFound("payout cycle")
	}
	status, err := s.deps.Repo.ApprovePayoutCycle(ctx, cycleID, p.UserID)
	switch {
	case errors.Is(err, ErrCycleNotFound):
		return PayoutCycleApproval{}, apperr.NotFound("payout cycle")
	case errors.Is(err, ErrCycleNotReady):
		return PayoutCycleApproval{}, apperr.BusinessRule("cycle_not_ready", "the payout cycle is not ready for approval")
	case err != nil:
		return PayoutCycleApproval{}, apperr.Internal(err)
	}
	return PayoutCycleApproval{CycleId: cycleID, Status: status}, nil
}
