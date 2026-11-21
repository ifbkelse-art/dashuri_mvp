package payouts

import "time"

// Wire types for this module. Generated from the API registry; keep in sync
// with api/openapi/dashuri.v1.yaml (the contract).

type WithdrawalRequest struct {
	Beans int64 `json:"beans"`
}

func (r WithdrawalRequest) validate() map[string]string {
	errs := map[string]string{}
	if r.Beans < 100000 {
		errs["beans"] = "below_minimum"
	}
	return errs
}

type Withdrawal struct {
	Id          string     `json:"id"`
	Beans       int64      `json:"beans"`
	AmountPaise int64      `json:"amount_paise"`
	Status      string     `json:"status"`
	RequestedAt time.Time  `json:"requested_at"`
	PaidAt      *time.Time `json:"paid_at,omitempty"`
}
