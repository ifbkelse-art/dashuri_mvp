package admin

import (
	"context"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
)

// Service implements the admin module's use cases. Every method is a
// scaffold that returns 501 until implemented; the documented steps are the
// required behaviour (see docs/architecture).
type Service struct {
	deps Deps
}

func NewService(d Deps) *Service { return &Service{deps: d} }

// GetReconciliation: GET /v1/admin/ledger/reconciliation — Latest reconciliation run.
func (s *Service) GetReconciliation(ctx context.Context, p auth.Principal) (ReconciliationReport, error) {
	return ReconciliationReport{}, apperr.NotImplemented("admin.GetReconciliation")
}

// ProposeAdjustment: POST /v1/admin/ledger/adjustments — Propose a manual ledger adjustment (needs a second approver; never edits history).
func (s *Service) ProposeAdjustment(ctx context.Context, p auth.Principal, in AdjustmentRequest) (AdjustmentProposal, error) {
	return AdjustmentProposal{}, apperr.NotImplemented("admin.ProposeAdjustment")
}

// ApprovePayoutCycle: POST /v1/admin/payout-cycles/{cycleId}/approve — Approve a prepared weekly payout cycle for submission to the payout provider.
func (s *Service) ApprovePayoutCycle(ctx context.Context, p auth.Principal, cycleId string) (PayoutCycleApproval, error) {
	return PayoutCycleApproval{}, apperr.NotImplemented("admin.ApprovePayoutCycle")
}
