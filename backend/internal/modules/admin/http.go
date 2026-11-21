package admin

import (
	"net/http"

	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/httpx"
	"dashuri/backend/internal/platform/idempotency"
	"dashuri/backend/internal/platform/routing"
)

// Routes registers this module's endpoints. Handlers only decode, validate,
// call the service and encode; no business logic lives here.
func Routes(mux *http.ServeMux, s *Service, mw routing.Stack) {
	mux.Handle("GET /v1/admin/ledger/reconciliation", mw.User(auth.Require(s.handleGetReconciliation, auth.RoleFinance, auth.RoleAdmin)))
	mux.Handle("POST /v1/admin/ledger/adjustments", mw.User(idempotency.Require(mw.Idempotency, auth.Require(s.handleProposeAdjustment, auth.RoleFinance, auth.RoleAdmin))))
	mux.Handle("POST /v1/admin/payout-cycles/{cycleId}/approve", mw.User(idempotency.Require(mw.Idempotency, auth.Require(s.handleApprovePayoutCycle, auth.RoleFinance))))
}

func (s *Service) handleGetReconciliation(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.GetReconciliation(r.Context(), p)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (s *Service) handleProposeAdjustment(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in AdjustmentRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if errs := in.validate(); len(errs) > 0 {
		httpx.WriteError(w, r, validationError(errs))
		return
	}
	out, err := s.ProposeAdjustment(r.Context(), p, in)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 201, out)
}

func (s *Service) handleApprovePayoutCycle(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.ApprovePayoutCycle(r.Context(), p, r.PathValue("cycleId"))
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}
