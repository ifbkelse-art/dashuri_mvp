package hosts

import "time"

// Wire types for this module. Generated from the API registry; keep in sync
// with api/openapi/dashuri.v1.yaml (the contract).

type HostStatus struct {
	State            string `json:"state"`
	KycState         string `json:"kyc_state"`
	IsAvailable      bool   `json:"is_available"`
	RatePerMinute    int64  `json:"rate_per_minute"`
	MinRatePerMinute int64  `json:"min_rate_per_minute"`
	MaxRatePerMinute int64  `json:"max_rate_per_minute"`
	FreeCallOptIn    bool   `json:"free_call_opt_in"`
}

type KycSession struct {
	SessionId   string  `json:"session_id"`
	RedirectUrl *string `json:"redirect_url,omitempty"`
}

type SetAvailabilityRequest struct {
	IsAvailable bool `json:"is_available"`
}

func (r SetAvailabilityRequest) validate() map[string]string {
	errs := map[string]string{}
	return errs
}

type SetRateRequest struct {
	RatePerMinute int64 `json:"rate_per_minute"`
}

func (r SetRateRequest) validate() map[string]string {
	errs := map[string]string{}
	if r.RatePerMinute < 500 {
		errs["rate_per_minute"] = "below_minimum"
	}
	if r.RatePerMinute > 10000 {
		errs["rate_per_minute"] = "above_maximum"
	}
	return errs
}

type SetFreeCallOptInRequest struct {
	OptIn bool `json:"opt_in"`
}

func (r SetFreeCallOptInRequest) validate() map[string]string {
	errs := map[string]string{}
	return errs
}

type HostEarnings struct {
	BeansOnHold        int64      `json:"beans_on_hold"`
	BeansAvailable     int64      `json:"beans_available"`
	BeansPendingPayout int64      `json:"beans_pending_payout"`
	AvailableInrPaise  int64      `json:"available_inr_paise"`
	NextPayoutDate     *time.Time `json:"next_payout_date,omitempty"`
}
