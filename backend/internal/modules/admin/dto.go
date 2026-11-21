package admin

import "time"

// Wire types for this module. Keep in sync with api/openapi/dashuri.v1.yaml
// (fields beyond the contract are additive; see docs/mvp/api/wallet_payments.md).

// ReconciliationReport: ledger postings vs the balance projection, entry
// balance checks and liability totals, recomputed on every request.
type ReconciliationReport struct {
	AsOf                     time.Time `json:"as_of"`
	CustomerDiamondLiability int64     `json:"customer_diamond_liability"` // Σ diamond_purchased
	HostBeanLiability        int64     `json:"host_bean_liability"`        // Σ bean_* (Beans)
	Discrepancies            int       `json:"discrepancies"`              // drifted accounts + unbalanced entries

	PromotionalDiamondLiability int64          `json:"promotional_diamond_liability"`
	HostBeanLiabilityPaise      int64          `json:"host_bean_liability_paise"`
	UnbalancedEntries           int            `json:"unbalanced_entries"`
	DriftedAccounts             []AccountDrift `json:"drifted_accounts"`
}

type AccountDrift struct {
	AccountID      int64  `json:"account_id"`
	Owner          string `json:"owner,omitempty"`
	Kind           string `json:"kind"`
	ProjectedValue int64  `json:"projected_balance"`
	PostedValue    int64  `json:"posted_balance"`
}

type AdjustmentRequest struct {
	Account  string `json:"account"` // "user:<uuid>:<kind>" or "<uuid>:<kind>"
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
	} else if r.Currency != "DIAMOND" && r.Currency != "BEAN" {
		errs["currency"] = "invalid_value"
	}
	if r.Amount == 0 {
		errs["amount"] = "must_not_be_zero"
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
	ProposalId string  `json:"proposal_id"`
	Status     string  `json:"status"` // awaiting_second_approval | posted | rejected
	EntryId    *string `json:"entry_id,omitempty"`
}

type PayoutCycleApproval struct {
	CycleId string `json:"cycle_id"`
	Status  string `json:"status"`
}
