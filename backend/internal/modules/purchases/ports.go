package purchases

import (
	"context"
	"errors"
	"time"

	"dashuri/backend/internal/modules/ledger"
)

// PlayDeveloperAPI is the boundary to the Google Play Developer API
// (androidpublisher v3), authenticated with a service account held in
// Secret Manager. Adapter: internal/adapters/googleplay.
type PlayDeveloperAPI interface {
	// GetProductPurchase returns Google's record for a one-time product
	// purchase (purchases.products.get). ErrPlayTokenInvalid when Google
	// does not know the token for this package and product.
	GetProductPurchase(ctx context.Context, packageName, productID, token string) (PlayPurchase, error)
	// Acknowledge acknowledges a purchase server-side (purchases.products.acknowledge).
	// The app still consumes the consumable with Play Billing after the credit.
	Consume(ctx context.Context, packageName, productID, token string) error
	// VoidedPurchases lists refunded/charged-back purchases since a time.
	VoidedPurchases(ctx context.Context, packageName string, since time.Time) ([]VoidedPurchase, error)
}

// ErrPlayTokenInvalid: Google returned 400/404/410 for the token.
var ErrPlayTokenInvalid = errors.New("googleplay: purchase token invalid")

// Play purchase states (ProductPurchase.purchaseState).
const (
	PlayStatePurchased = 0
	PlayStateCanceled  = 1
	PlayStatePending   = 2
)

type PlayPurchase struct {
	OrderID              string
	PurchaseState        int // 0 purchased, 1 canceled, 2 pending
	Acknowledged         bool
	Consumed             bool
	PurchaseTime         time.Time
	ObfuscatedAccountID  string // set by the app to sha256(user id); must match when present
	PurchaseType         *int   // 0 test (license tester), 1 promo, 2 rewarded; nil = real purchase
	Quantity             int
	RegionCode           string
	ProductID            string
	AcknowledgementState int
}

type VoidedPurchase struct {
	PurchaseToken string
	OrderID       string
	VoidedAt      time.Time
	Reason        int
	Source        int
}

// PushAuthenticator verifies the OIDC bearer token Pub/Sub attaches to
// push deliveries (audience, service-account email, email_verified).
type PushAuthenticator interface {
	VerifyPush(ctx context.Context, authorizationHeader string) error
}

// CashfreeAPI is the boundary to Cashfree PG (adapter internal/adapters/cashfree).
type CashfreeAPI interface {
	CreateOrder(ctx context.Context, in CashfreeCreateOrder) (CashfreeRemoteOrder, error)
	GetOrder(ctx context.Context, orderID string) (CashfreeRemoteOrder, error)
	// VerifyWebhook checks x-webhook-signature over timestamp + raw body.
	VerifyWebhook(raw []byte, signature, timestamp string, now time.Time) error
	Environment() string
}

type CashfreeCreateOrder struct {
	OrderID       string
	AmountPaise   int64
	Currency      string
	CustomerID    string
	CustomerPhone string
	ReturnURL     string
	ExpiresAt     time.Time
	Note          string
}

type CashfreeRemoteOrder struct {
	OrderID          string
	CFOrderID        string
	Status           string // ACTIVE | PAID | EXPIRED | TERMINATED | TERMINATION_REQUESTED
	AmountPaise      int64
	Currency         string
	PaymentSessionID string
}

// Publisher pushes wallet.updated to the user's Realtime channel.
type Publisher interface {
	Publish(ctx context.Context, channel, event string, payload any) error
}

// Package is one row of economy.diamond_packages.
type Package struct {
	ProductID   string
	Diamonds    int64
	PricePaise  int64
	Label       string
	Badge       *string
	Provisional bool
}

// PurchaseRecord is one commerce.purchases row.
type PurchaseRecord struct {
	ID        string
	UserID    string
	ProductID string
	TokenHash string
	OrderID   string
	State     string // pending | credited | rejected | reversed
	Diamonds  int64
	Rail      string
}

// Credit is everything posted when a verified purchase is credited. The
// repository runs it in ONE transaction: insert or lock the purchase row by
// token hash (refusing another account's row), post Entry(purchaseID),
// mark the row credited and award XP. A credited row is returned unchanged.
type Credit struct {
	UserID    string
	ProductID string
	TokenHash string
	OrderID   string
	Diamonds  int64
	Rail      string
	XP        int64
	Entry     func(purchaseID string) ledger.Entry
	// CashfreeOrderID, when set, locks that order first and moves it to
	// credited in the same transaction; an order already final in another
	// state aborts with ErrNotCreditable.
	CashfreeOrderID string
}

// ErrOtherAccount: the purchase token is already bound to another user.
var ErrOtherAccount = errors.New("purchases: token used by another account")

// ErrNotCreditable aborts a Cashfree credit when the order is already final
// in a non-credited state.
var ErrNotCreditable = errors.New("purchases: order is not creditable")

// ReversalPlan decides how many Diamonds to take back, given the locked
// balances of the purchase owner.
type ReversalPlan func(p PurchaseRecord, purchased, promotional, reserved int64) (remove int64)

type ReversalResult struct {
	PurchaseID  string
	UserID      string
	Removed     int64
	Unrecovered int64
	Replayed    bool
	Found       bool
}

// CashfreeOrderRecord is one commerce.cashfree_orders row.
type CashfreeOrderRecord struct {
	OrderID          string
	UserID           string
	ProductID        string
	AmountPaise      int64
	Diamonds         int64
	PaymentSessionID string
	CFOrderID        string
	Environment      string
	State            string // created | pending | credited | failed | expired
	PurchaseID       string
	FailureReason    string
	CreatedAt        time.Time
	ExpiresAt        time.Time
}

// Repository is the purchases module's persistence port
// (internal/adapters/postgres/purchases_repo.go).
type Repository interface {
	Packages(ctx context.Context) ([]Package, error)
	Package(ctx context.Context, productID string) (Package, bool, error)

	PurchaseByTokenHash(ctx context.Context, tokenHash string) (PurchaseRecord, bool, error)
	// SavePlayPurchaseState records a non-credited (pending or rejected) Play
	// purchase for the user, never downgrading a credited or reversed row.
	SavePlayPurchaseState(ctx context.Context, rec PurchaseRecord) (PurchaseRecord, error)
	CreditPurchase(ctx context.Context, c Credit) (rec PurchaseRecord, replayed bool, err error)
	// ReversePurchase, in one transaction: locks the purchase by token hash
	// and the owner's balances, asks plan for the amount, posts
	// ledger.PurchaseReversal, records the reversal and a negative XP event.
	ReversePurchase(ctx context.Context, tokenHash, reason string, voidedAt time.Time, plan ReversalPlan, xpWeight int64) (ReversalResult, error)

	NotificationSeen(ctx context.Context, messageID string) (bool, error)
	RecordNotification(ctx context.Context, messageID, kind string, payload []byte) error

	CustomerPhone(ctx context.Context, userID string) (string, error)
	InsertCashfreeOrder(ctx context.Context, o CashfreeOrderRecord) error
	CashfreeOrder(ctx context.Context, orderID string) (CashfreeOrderRecord, bool, error)
	SetCashfreeSession(ctx context.Context, orderID, paymentSessionID, cfOrderID string) error
	// SetCashfreeOrderState moves an order that is not final (created or
	// pending) to state; final orders are left unchanged.
	SetCashfreeOrderState(ctx context.Context, orderID, state, reason string) error
	// OpenCashfreeOrders lists created/pending orders, oldest first.
	OpenCashfreeOrders(ctx context.Context, limit int) ([]CashfreeOrderRecord, error)
	WebhookSeen(ctx context.Context, deliveryHash string) (bool, error)
	RecordWebhook(ctx context.Context, deliveryHash, orderID, eventType string, payload []byte) error

	Audit(ctx context.Context, actor, action, target string, details map[string]any) error
}
