package admin

import "time"

// Wire types for this module. Generated from the API registry; keep in sync
// with api/openapi/dashuri.v1.yaml (the contract).

// ReconciliationReport: Ledger vs balance-projection and vs Google Play settlement checks.
type ReconciliationReport struct {
	AsOf                     time.Time `json:"as_of"`
	CustomerDiamondLiability int64     `json:"customer_diamond_liability"`
	HostBeanLiability        int64     `json:"host_bean_liability"`
	Discrepancies            int       `json:"discrepancies"`
}

type AdjustmentRequest struct {
	Account  string `json:"account"`
	Currency string `json:"currency"`
	Amount   int64  `json:"amount"`
	Reason   string `json:"reason"`
}

func (r AdjustmentRequest) validate() map[string]string {
	errs := map[string]string{}
	if r.Account == "" {
		errs["account"] = "required"
	}
	if r.Currency == "" {
		errs["currency"] = "required"
	}
	if r.Currency != "DIAMOND" && r.Currency != "BEAN" {
		errs["currency"] = "invalid_value"
	}
	if r.Reason == "" {
		errs["reason"] = "required"
	}
	if len(r.Reason) > 2000 {
		errs["reason"] = "too_long"
	}
	return errs
}

type AdjustmentProposal struct {
	ProposalId string `json:"proposal_id"`
	Status     string `json:"status"`
}

type PayoutCycleApproval struct {
	CycleId string `json:"cycle_id"`
	Status  string `json:"status"`
}
