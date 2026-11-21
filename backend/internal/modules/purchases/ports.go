package purchases

import (
	"context"
	"time"
)

// PlayDeveloperAPI is the boundary to the Google Play Developer API
// (androidpublisher v3), authenticated with a service account held in
// Secret Manager. Adapter: internal/adapters/googleplay (TODO).
type PlayDeveloperAPI interface {
	// GetProductPurchase returns Google's record for a one-time product purchase.
	GetProductPurchase(ctx context.Context, packageName, productID, token string) (PlayPurchase, error)
	// Acknowledge/consume per current Play Billing rules. Confirm the exact
	// server-side consume capability before relying on it.
	Acknowledge(ctx context.Context, packageName, productID, token string) error
	// VoidedPurchases lists refunded/charged-back purchases since a time.
	VoidedPurchases(ctx context.Context, packageName string, since time.Time) ([]VoidedPurchase, error)
}

type PlayPurchase struct {
	OrderID             string
	PurchaseState       int // 0 purchased, 1 cancelled, 2 pending (per Play docs; verify)
	Acknowledged        bool
	Consumed            bool
	PurchaseTime        time.Time
	ObfuscatedAccountID string // set by the app to the Dashuri user id hash; must match
}

type VoidedPurchase struct {
	PurchaseToken string
	OrderID       string
	VoidedAt      time.Time
	Reason        int
}
