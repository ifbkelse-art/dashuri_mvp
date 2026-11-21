package wallet

import "time"

// Wire types for this module. Keep in sync with api/openapi/dashuri.v1.yaml
// (`description` on WalletEntry is additive; see docs/mvp/api/wallet_payments.md).

type WalletSummary struct {
	PurchasedDiamonds   int64 `json:"purchased_diamonds"`
	PromotionalDiamonds int64 `json:"promotional_diamonds"`
	ReservedDiamonds    int64 `json:"reserved_diamonds"`
	AvailableDiamonds   int64 `json:"available_diamonds"`
	BeansOnHold         int64 `json:"beans_on_hold"`
	BeansAvailable      int64 `json:"beans_available"`
	BeansPendingPayout  int64 `json:"beans_pending_payout"`
}

type WalletEntry struct {
	Id          string    `json:"id"`
	Currency    string    `json:"currency"`
	Kind        string    `json:"kind"`
	Amount      int64     `json:"amount"`
	CreatedAt   time.Time `json:"created_at"`
	Reference   *string   `json:"reference,omitempty"`
	Description string    `json:"description"`
}
