package purchases

import (
	"context"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
)

// Service implements the purchases module's use cases. Every method is a
// scaffold that returns 501 until implemented; the documented steps are the
// required behaviour (see docs/architecture).
type Service struct {
	deps Deps
}

func NewService(d Deps) *Service { return &Service{deps: d} }

// ListDiamondPackages: GET /v1/purchases/packages — Active Diamond package catalogue (product id → Diamonds). Prices come from Google Play.
func (s *Service) ListDiamondPackages(ctx context.Context, p auth.Principal) (DiamondPackageList, error) {
	return DiamondPackageList{}, apperr.NotImplemented("purchases.ListDiamondPackages")
}

// VerifyGooglePlayPurchase: POST /v1/purchases/google-play — Verify a Play purchase token and credit Diamonds exactly once.
//  1. Hash the purchase token; the purchases table is UNIQUE on token hash, so replays return the original result.
//  2. Call the Google Play Developer API (purchases.products) with the service account; check package name, product id, purchase state, and that the order is not already consumed elsewhere.
//  3. Pending payment → status pending, no credit (credited later from RTDN).
//  4. Purchased → in one transaction insert the purchase and post ledger.PurchaseCredit (key purchase_credit:<token_hash>); award XP = 8 × Diamonds.
//  5. Acknowledge/consume with Play per current Billing requirements; the client completes only after credited.
func (s *Service) VerifyGooglePlayPurchase(ctx context.Context, p auth.Principal, in VerifyGooglePlayRequest) (PurchaseVerification, error) {
	return PurchaseVerification{}, apperr.NotImplemented("purchases.VerifyGooglePlayPurchase")
}

// GooglePlayNotification: POST /v1/webhooks/google-play/rtdn — Real-Time Developer Notifications via Pub/Sub push (OIDC-authenticated). Drives late credits, refunds and voided purchases.
//  1. Verify the Pub/Sub push OIDC token (audience = this endpoint, service account allow-list).
//  2. Deduplicate by message id.
//  3. On voided/refunded purchases (also poll the Voided Purchases API daily): post ledger.PurchaseReversal for the unspent part; open a fraud case for any spent part; claw back host Beans still on hold; reverse XP.
func (s *Service) GooglePlayNotification(ctx context.Context, raw []byte, headers map[string]string) error {
	return apperr.NotImplemented("purchases.GooglePlayNotification")
}
