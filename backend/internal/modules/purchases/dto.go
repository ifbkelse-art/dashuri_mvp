package purchases

// Wire types for this module. Generated from the API registry; keep in sync
// with api/openapi/dashuri.v1.yaml (the contract).

type DiamondPackageList struct {
	Items []DiamondPackageItem `json:"items"`
}

type DiamondPackageItem struct {
	ProductId string `json:"product_id"`
	Diamonds  int64  `json:"diamonds"`
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
	Status           string `json:"status"`
	DiamondsCredited int64  `json:"diamonds_credited"`
}
