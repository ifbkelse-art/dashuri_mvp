package purchases

// Wire types for this module. Keep in sync with api/openapi/dashuri.v1.yaml
// and docs/mvp/MVP_DECISIONS_AND_CONTRACT.md §2.4 (additive fields).

type DiamondPackageList struct {
	Items []DiamondPackageItem `json:"items"`
	// Rails enabled on the server: "google_play" (Play configured), "cashfree" (CASHFREE_ENABLED).
	Rails []string `json:"rails"`
	// ApproxPaisePerDiamondMilli is the ₹ estimate basis × 1000 (D-07).
	ApproxPaisePerDiamondMilli int64 `json:"approx_paise_per_diamond_milli"`
}

type DiamondPackageItem struct {
	ProductId   string  `json:"product_id"`
	Diamonds    int64   `json:"diamonds"`
	PricePaise  int64   `json:"price_paise"`
	Label       string  `json:"label"`
	Badge       *string `json:"badge"`
	Provisional bool    `json:"provisional"`
}

type VerifyGooglePlayRequest struct {
	ProductId     string  `json:"product_id"`
	PurchaseToken string  `json:"purchase_token"`
	OrderId       *string `json:"order_id,omitempty"`
}

func (r VerifyGooglePlayRequest) validate() map[string]string {
	errs := map[string]string{}
	if r.ProductId == "" {
		errs["product_id"] = "required"
	}
	if r.PurchaseToken == "" {
		errs["purchase_token"] = "required"
	}
	if len(r.PurchaseToken) > 4096 {
		errs["purchase_token"] = "too_long"
	}
	return errs
}

type PurchaseVerification struct {
	PurchaseId       string `json:"purchase_id"`
	Status           string `json:"status"` // credited | pending | rejected
	DiamondsCredited int64  `json:"diamonds_credited"`
}

type CreateCashfreeOrderRequest struct {
	ProductId string `json:"product_id"`
}

func (r CreateCashfreeOrderRequest) validate() map[string]string {
	errs := map[string]string{}
	if r.ProductId == "" {
		errs["product_id"] = "required"
	}
	if len(r.ProductId) > 100 {
		errs["product_id"] = "too_long"
	}
	return errs
}

type CashfreeOrder struct {
	OrderId          string `json:"order_id"`
	ProductId        string `json:"product_id"`
	AmountPaise      int64  `json:"amount_paise"`
	Diamonds         int64  `json:"diamonds"`
	PaymentSessionId string `json:"payment_session_id"`
	Environment      string `json:"environment"`
	State            string `json:"state"`
	DiamondsCredited int64  `json:"diamonds_credited"`
}
