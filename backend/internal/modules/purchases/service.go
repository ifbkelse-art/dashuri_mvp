package purchases

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"log/slog"
	"strings"
	"time"

	"dashuri/backend/internal/modules/ledger"
	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/clock"
)

// Service implements Diamond purchases on two rails (Google Play, Cashfree
// PG). Every credit is ledger.PurchaseCredit + commerce.purchases + XP in
// one transaction, exactly once per purchase token / order.
type Service struct {
	deps Deps
}

func NewService(d Deps) *Service {
	if d.Clock == nil {
		d.Clock = clock.System{}
	}
	if d.CashfreeOrderTTL <= 0 {
		d.CashfreeOrderTTL = 30 * time.Minute
	}
	return &Service{deps: d}
}

// Errors returned to jobs when a rail is not configured.
var (
	ErrPlayNotConfigured     = apperr.Unavailable("play_not_configured", "Google Play verification is not configured on the server")
	ErrRailDisabled          = apperr.Unavailable("rail_disabled", "this payment method is not enabled")
	ErrCashfreeNotConfigured = apperr.Unavailable("cashfree_not_configured", "Cashfree credentials are not configured on the server")
	errDB                    = apperr.Unavailable("database_unavailable", "database not configured")
)

const (
	railPlay     = "google_play"
	railCashfree = "cashfree"
)

// SHA256Hex is the hash used for purchase tokens and obfuscated account ids.
func SHA256Hex(s string) string {
	h := sha256.Sum256([]byte(s))
	return hex.EncodeToString(h[:])
}

// CashfreeTokenHash is commerce.purchases.purchase_token_hash for an order.
func CashfreeTokenHash(orderID string) string { return SHA256Hex("cashfree:" + orderID) }

// ---------------------------------------------------------------- packages

// ListDiamondPackages: GET /v1/purchases/packages.
func (s *Service) ListDiamondPackages(ctx context.Context, _ auth.Principal) (DiamondPackageList, error) {
	if s.deps.Repo == nil {
		return DiamondPackageList{}, errDB
	}
	pkgs, err := s.deps.Repo.Packages(ctx)
	if err != nil {
		return DiamondPackageList{}, apperr.Internal(err)
	}
	out := DiamondPackageList{Items: make([]DiamondPackageItem, 0, len(pkgs)), Rails: s.Rails()}
	out.ApproxPaisePerDiamondMilli = ApproxPaisePerDiamondMilli(pkgs)
	for _, p := range pkgs {
		out.Items = append(out.Items, DiamondPackageItem{ProductId: p.ProductID, Diamonds: p.Diamonds, PricePaise: p.PricePaise,
			Label: p.Label, Badge: p.Badge, Provisional: p.Provisional})
	}
	return out, nil
}

// Rails lists the rails enabled on this server.
func (s *Service) Rails() []string {
	r := []string{}
	if s.deps.Play != nil && s.deps.PackageName != "" {
		r = append(r, railPlay)
	}
	if s.deps.CashfreeEnabled {
		r = append(r, railCashfree)
	}
	return r
}

// ApproxPaisePerDiamondMilli uses the cheapest (lowest-price) active package
// (design D-07): ⌊price_paise × 1000 ÷ diamonds⌋.
func ApproxPaisePerDiamondMilli(pkgs []Package) int64 {
	var best *Package
	for i := range pkgs {
		p := &pkgs[i]
		if p.PricePaise <= 0 || p.Diamonds <= 0 {
			continue
		}
		if best == nil || p.PricePaise < best.PricePaise {
			best = p
		}
	}
	if best == nil {
		return 0
	}
	return best.PricePaise * 1000 / best.Diamonds
}

func (s *Service) pkg(ctx context.Context, productID string) (Package, error) {
	p, ok, err := s.deps.Repo.Package(ctx, productID)
	if err != nil {
		return Package{}, apperr.Internal(err)
	}
	if !ok {
		return Package{}, apperr.BusinessRule("product_unknown", "unknown or inactive product")
	}
	return p, nil
}

func (s *Service) walletUpdated(ctx context.Context, userID string) {
	if s.deps.Events == nil {
		return
	}
	if err := s.deps.Events.Publish(ctx, "user:"+userID, "wallet.updated", map[string]any{}); err != nil {
		slog.WarnContext(ctx, "wallet.updated publish failed", "err", err)
	}
}

func (s *Service) audit(ctx context.Context, actor, action, target string, details map[string]any) {
	if err := s.deps.Repo.Audit(ctx, actor, action, target, details); err != nil {
		slog.ErrorContext(ctx, "audit write failed", "action", action, "err", err)
	}
}

// ---------------------------------------------------------------- Google Play

func (s *Service) playReady() error {
	if s.deps.Repo == nil {
		return errDB
	}
	if s.deps.Play == nil || s.deps.PackageName == "" {
		return ErrPlayNotConfigured
	}
	return nil
}

// VerifyGooglePlayPurchase: POST /v1/purchases/google-play.
//  1. Hash the token; a row bound to another account is refused, a credited
//     row of this account is returned as is (replay).
//  2. purchases.products.get with the service account; check product,
//     obfuscatedExternalAccountId = sha256(user id) when present.
//  3. purchaseState 0 → credit once; 2 → pending (no credit); else rejected.
//  4. Acknowledge server-side after the credit.
//
// purchaseAllowed refuses minors and restricted accounts (security review finding 2).
func purchaseAllowed(p auth.Principal) error {
	if !p.AgeEligible {
		return apperr.BusinessRule("not_age_eligible", "confirm you are 18 or older first")
	}
	if p.Restricted() {
		return apperr.BusinessRule("account_restricted", "purchases are restricted on this account")
	}
	return nil
}

func (s *Service) VerifyGooglePlayPurchase(ctx context.Context, p auth.Principal, in VerifyGooglePlayRequest) (PurchaseVerification, error) {
	if err := purchaseAllowed(p); err != nil {
		return PurchaseVerification{}, err
	}
	if err := s.playReady(); err != nil {
		return PurchaseVerification{}, err
	}
	pkg, err := s.pkg(ctx, in.ProductId)
	if err != nil {
		return PurchaseVerification{}, err
	}
	return s.verifyPlay(ctx, p.UserID, pkg, in.PurchaseToken)
}

func (s *Service) verifyPlay(ctx context.Context, userID string, pkg Package, token string) (PurchaseVerification, error) {
	hash := SHA256Hex(token)
	existing, found, err := s.deps.Repo.PurchaseByTokenHash(ctx, hash)
	if err != nil {
		return PurchaseVerification{}, apperr.Internal(err)
	}
	if found {
		if existing.UserID != userID {
			return PurchaseVerification{}, apperr.BusinessRule("purchase_already_used_by_other_account", "this purchase belongs to another account")
		}
		if existing.ProductID != pkg.ProductID {
			return PurchaseVerification{}, apperr.BusinessRule("purchase_token_invalid", "token does not match the product")
		}
		switch existing.State {
		case "credited":
			return PurchaseVerification{PurchaseId: existing.ID, Status: "credited", DiamondsCredited: existing.Diamonds}, nil
		case "reversed":
			return PurchaseVerification{}, apperr.BusinessRule("purchase_token_invalid", "this purchase was refunded")
		}
	}
	gp, err := s.deps.Play.GetProductPurchase(ctx, s.deps.PackageName, pkg.ProductID, token)
	if errors.Is(err, ErrPlayTokenInvalid) {
		return PurchaseVerification{}, apperr.BusinessRule("purchase_token_invalid", "Google Play does not recognise this purchase")
	}
	if err != nil {
		slog.ErrorContext(ctx, "play verification failed", "err", err)
		return PurchaseVerification{}, apperr.Unavailable("play_unavailable", "Google Play could not be reached; retry")
	}
	if gp.ProductID != "" && gp.ProductID != pkg.ProductID {
		return PurchaseVerification{}, apperr.BusinessRule("purchase_token_invalid", "token does not match the product")
	}
	// The app always sets obfuscatedAccountId = sha256(user id); a token
	// without it (or with another account's) is refused (security review 10).
	if !strings.EqualFold(gp.ObfuscatedAccountID, SHA256Hex(userID)) {
		return PurchaseVerification{}, apperr.BusinessRule("purchase_already_used_by_other_account", "this purchase was made for another account")
	}
	rec := PurchaseRecord{UserID: userID, ProductID: pkg.ProductID, TokenHash: hash, OrderID: gp.OrderID, Diamonds: pkg.Diamonds, Rail: railPlay}
	switch gp.PurchaseState {
	case PlayStatePurchased:
		diamonds := pkg.Diamonds * int64(max(gp.Quantity, 1))
		now := s.deps.Clock.Now()
		got, replayed, err := s.deps.Repo.CreditPurchase(ctx, Credit{
			UserID: userID, ProductID: pkg.ProductID, TokenHash: hash, OrderID: gp.OrderID, Diamonds: diamonds,
			Rail: railPlay, XP: s.deps.Rules.XP(diamonds, 0),
			Entry: func(purchaseID string) ledger.Entry {
				return ledger.PurchaseCredit(userID, purchaseID, hash, diamonds, s.deps.Rules.Version, now)
			},
		})
		if errors.Is(err, ErrOtherAccount) {
			return PurchaseVerification{}, apperr.BusinessRule("purchase_already_used_by_other_account", "this purchase belongs to another account")
		}
		if err != nil {
			return PurchaseVerification{}, apperr.Internal(err)
		}
		if !gp.Consumed {
			if err := s.deps.Play.Consume(ctx, s.deps.PackageName, pkg.ProductID, token); err != nil {
				// Credited already (exactly once). A retry of this request or
				// the RTDN path consumes again; consume is idempotent at Google.
				slog.WarnContext(ctx, "play consume failed", "purchase_id", got.ID, "err", err)
			}
		}
		if !replayed {
			s.walletUpdated(ctx, userID)
		}
		return PurchaseVerification{PurchaseId: got.ID, Status: "credited", DiamondsCredited: got.Diamonds}, nil
	case PlayStatePending:
		rec.State = "pending"
	default:
		rec.State = "rejected"
	}
	saved, err := s.deps.Repo.SavePlayPurchaseState(ctx, rec)
	if errors.Is(err, ErrOtherAccount) {
		return PurchaseVerification{}, apperr.BusinessRule("purchase_already_used_by_other_account", "this purchase belongs to another account")
	}
	if err != nil {
		return PurchaseVerification{}, apperr.Internal(err)
	}
	if saved.State == "credited" {
		return PurchaseVerification{PurchaseId: saved.ID, Status: "credited", DiamondsCredited: saved.Diamonds}, nil
	}
	return PurchaseVerification{PurchaseId: saved.ID, Status: saved.State, DiamondsCredited: 0}, nil
}

// pushEnvelope is a Pub/Sub push delivery.
type pushEnvelope struct {
	Message struct {
		Data       string            `json:"data"`
		MessageID  string            `json:"messageId"`
		MessageID2 string            `json:"message_id"`
		Attributes map[string]string `json:"attributes"`
	} `json:"message"`
	Subscription string `json:"subscription"`
}

// DeveloperNotification is the RTDN payload (base64 in message.data).
type DeveloperNotification struct {
	Version                    string `json:"version"`
	PackageName                string `json:"packageName"`
	EventTimeMillis            string `json:"eventTimeMillis"`
	OneTimeProductNotification *struct {
		NotificationType int    `json:"notificationType"` // 1 purchased, 2 canceled
		PurchaseToken    string `json:"purchaseToken"`
		SKU              string `json:"sku"`
	} `json:"oneTimeProductNotification"`
	VoidedPurchaseNotification *struct {
		PurchaseToken string `json:"purchaseToken"`
		OrderID       string `json:"orderId"`
		ProductType   int    `json:"productType"`
		RefundType    int    `json:"refundType"`
	} `json:"voidedPurchaseNotification"`
	TestNotification *struct {
		Version string `json:"version"`
	} `json:"testNotification"`
}

// GooglePlayNotification: POST /v1/webhooks/google-play/rtdn.
//  1. Verify the Pub/Sub push OIDC token.
//  2. Deduplicate by message id (commerce.play_notifications).
//  3. Voided purchase → reversal of the unspent amount; one-time product
//     purchased → late credit of a pending purchase; canceled → rejected.
func (s *Service) GooglePlayNotification(ctx context.Context, raw []byte, headers map[string]string) error {
	if s.deps.Push == nil {
		return apperr.Unavailable("play_not_configured", "RTDN verification is not configured")
	}
	if err := s.deps.Push.VerifyPush(ctx, headers["Authorization"]); err != nil {
		return apperr.Unauthenticated("invalid push token")
	}
	if s.deps.Repo == nil {
		return errDB
	}
	var env pushEnvelope
	if err := json.Unmarshal(raw, &env); err != nil {
		return apperr.Validation(map[string]string{"body": "invalid_json"})
	}
	msgID := env.Message.MessageID
	if msgID == "" {
		msgID = env.Message.MessageID2
	}
	if msgID == "" {
		return apperr.Validation(map[string]string{"message.messageId": "required"})
	}
	seen, err := s.deps.Repo.NotificationSeen(ctx, msgID)
	if err != nil {
		return apperr.Internal(err)
	}
	if seen {
		return nil
	}
	data, err := base64.StdEncoding.DecodeString(env.Message.Data)
	if err != nil {
		return apperr.Validation(map[string]string{"message.data": "invalid_base64"})
	}
	var n DeveloperNotification
	if err := json.Unmarshal(data, &n); err != nil {
		return apperr.Validation(map[string]string{"message.data": "invalid_json"})
	}
	kind := "unknown"
	switch {
	case n.PackageName != "" && s.deps.PackageName != "" && n.PackageName != s.deps.PackageName:
		kind = "foreign_package"
	case n.TestNotification != nil:
		kind = "test"
	case n.VoidedPurchaseNotification != nil:
		kind = "voided"
		if _, err := s.reversePlay(ctx, n.VoidedPurchaseNotification.PurchaseToken, n.VoidedPurchaseNotification.OrderID, "rtdn_voided", s.deps.Clock.Now(), "provider:google_play_rtdn"); err != nil {
			return err
		}
	case n.OneTimeProductNotification != nil:
		o := n.OneTimeProductNotification
		kind = "one_time_product"
		if err := s.lateOneTime(ctx, o.NotificationType, o.PurchaseToken); err != nil {
			return err
		}
	}
	if err := s.deps.Repo.RecordNotification(ctx, msgID, kind, data); err != nil {
		return apperr.Internal(err)
	}
	return nil
}

// lateOneTime handles ONE_TIME_PRODUCT_PURCHASED (1) for a purchase the
// app reported while pending, and ONE_TIME_PRODUCT_CANCELED (2).
func (s *Service) lateOneTime(ctx context.Context, typ int, token string) error {
	rec, found, err := s.deps.Repo.PurchaseByTokenHash(ctx, SHA256Hex(token))
	if err != nil {
		return apperr.Internal(err)
	}
	if !found || rec.State != "pending" {
		return nil // unknown tokens are verified when the app reports them
	}
	switch typ {
	case 1:
		if err := s.playReady(); err != nil {
			return err
		}
		pkg, err := s.pkg(ctx, rec.ProductID)
		if err != nil {
			return nil
		}
		if _, err := s.verifyPlay(ctx, rec.UserID, pkg, token); err != nil {
			if e := apperr.As(err); e != nil && e.Kind == apperr.KindBusinessRule {
				slog.WarnContext(ctx, "rtdn late credit refused", "purchase_id", rec.ID, "rule", e.Code)
				return nil
			}
			return err
		}
	case 2:
		rec.State = "rejected"
		if _, err := s.deps.Repo.SavePlayPurchaseState(ctx, rec); err != nil && !errors.Is(err, ErrOtherAccount) {
			return apperr.Internal(err)
		}
	}
	return nil
}

// ReversalAmount is the policy for a voided purchase: only Diamonds still
// unspent can be taken back, capped at the purchased balance not already
// committed to a live call (reservations draw on promotional first).
func ReversalAmount(p PurchaseRecord, purchased, promotional, reserved int64) int64 {
	committed := max(reserved-promotional, 0)
	return max(min(p.Diamonds, purchased-committed), 0)
}

// reversePlay reverses a refunded or charged-back Play purchase. Google sends
// both the purchase token and the order id. The token is tried first; if it
// matches no purchase (for example a token in another format), the order id
// stored at credit time is used. A refund that matches nothing is logged,
// never silently dropped.
func (s *Service) reversePlay(ctx context.Context, token, orderID, reason string, at time.Time, actor string) (ReversalResult, error) {
	if token == "" && orderID == "" {
		return ReversalResult{}, nil
	}
	hash := ""
	if token != "" {
		hash = SHA256Hex(token)
		if _, found, err := s.deps.Repo.PurchaseByTokenHash(ctx, hash); err != nil {
			return ReversalResult{}, apperr.Internal(err)
		} else if !found {
			hash = ""
		}
	}
	if hash == "" && orderID != "" {
		rec, found, err := s.deps.Repo.PurchaseByOrderID(ctx, orderID)
		if err != nil {
			return ReversalResult{}, apperr.Internal(err)
		}
		if found {
			hash = rec.TokenHash
			slog.InfoContext(ctx, "play reversal matched by order id", "order_id", orderID, "purchase_id", rec.ID)
		}
	}
	if hash == "" {
		slog.WarnContext(ctx, "play reversal matched no purchase", "order_id", orderID, "reason", reason)
		return ReversalResult{}, nil
	}
	res, err := s.deps.Repo.ReversePurchase(ctx, hash, reason, at, ReversalAmount, s.deps.Rules.XPDiamondWeight)
	if err != nil {
		return res, apperr.Internal(err)
	}
	if !res.Found || res.Replayed {
		return res, nil
	}
	s.audit(ctx, actor, "purchase.reversed", res.PurchaseID, map[string]any{
		"reason": reason, "removed_diamonds": res.Removed, "unrecovered_diamonds": res.Unrecovered})
	if res.Unrecovered > 0 {
		// Spent Diamonds cannot be recovered; finance/fraud review follows up.
		s.audit(ctx, actor, "purchase.reversal_shortfall", res.PurchaseID, map[string]any{
			"user_id": res.UserID, "unrecovered_diamonds": res.Unrecovered})
	}
	if res.Removed > 0 {
		s.walletUpdated(ctx, res.UserID)
	}
	return res, nil
}

// PollVoidedPurchases is the `poll-voided-purchases` job: the Voided
// Purchases API (last 30 days) through the same reversal path as RTDN.
// VoidedLookback is how far back the voided-purchases poll asks Google to look.
// Google rejects (400) a startTime older than 30 days, and a request that is
// built at exactly now-30d arrives a few milliseconds past that limit, so the
// window stays a day inside it.
const VoidedLookback = 29 * 24 * time.Hour

func (s *Service) PollVoidedPurchases(ctx context.Context) (processed int, err error) {
	if err := s.playReady(); err != nil {
		return 0, err
	}
	since := s.deps.Clock.Now().Add(-VoidedLookback)
	voided, err := s.deps.Play.VoidedPurchases(ctx, s.deps.PackageName, since)
	if err != nil {
		return 0, err
	}
	for _, v := range voided {
		at := v.VoidedAt
		if at.IsZero() {
			at = s.deps.Clock.Now()
		}
		res, err := s.reversePlay(ctx, v.PurchaseToken, v.OrderID, "voided_purchases_api", at, "system:poll-voided-purchases")
		if err != nil {
			return processed, err
		}
		if res.Found && !res.Replayed {
			processed++
		}
	}
	return processed, nil
}

// ---------------------------------------------------------------- Cashfree PG

func (s *Service) cashfreeReady() error {
	if !s.deps.CashfreeEnabled {
		return ErrRailDisabled
	}
	if s.deps.Cashfree == nil {
		return ErrCashfreeNotConfigured
	}
	if s.deps.Repo == nil {
		return errDB
	}
	return nil
}

func newOrderID() string {
	b := make([]byte, 12)
	_, _ = rand.Read(b)
	return "dsh_" + hex.EncodeToString(b)
}

// CashfreePhone normalises a Supabase phone (E.164 without "+", e.g.
// 919876543210) to the 10-digit Indian mobile number Cashfree expects.
func CashfreePhone(phone string) string {
	var d strings.Builder
	for _, r := range phone {
		if r >= '0' && r <= '9' {
			d.WriteRune(r)
		}
	}
	s := d.String()
	if len(s) == 12 && strings.HasPrefix(s, "91") {
		return s[2:]
	}
	if len(s) == 11 && strings.HasPrefix(s, "0") {
		return s[1:]
	}
	return s
}

func toWire(o CashfreeOrderRecord, credited int64) CashfreeOrder {
	return CashfreeOrder{OrderId: o.OrderID, ProductId: o.ProductID, AmountPaise: o.AmountPaise, Diamonds: o.Diamonds,
		PaymentSessionId: o.PaymentSessionID, Environment: o.Environment, State: o.State, DiamondsCredited: credited}
}

func wireOrder(o CashfreeOrderRecord) CashfreeOrder {
	var credited int64
	if o.State == "credited" {
		credited = o.Diamonds
	}
	return toWire(o, credited)
}

// CreateCashfreeOrder: POST /v1/purchases/cashfree/orders. The amount comes
// from the package table; the app receives only payment_session_id.
func (s *Service) CreateCashfreeOrder(ctx context.Context, p auth.Principal, in CreateCashfreeOrderRequest) (CashfreeOrder, error) {
	if err := purchaseAllowed(p); err != nil {
		return CashfreeOrder{}, err
	}
	if err := s.cashfreeReady(); err != nil {
		return CashfreeOrder{}, err
	}
	pkg, err := s.pkg(ctx, in.ProductId)
	if err != nil {
		return CashfreeOrder{}, err
	}
	if pkg.PricePaise <= 0 {
		return CashfreeOrder{}, apperr.BusinessRule("product_unknown", "product has no price")
	}
	phone, err := s.deps.Repo.CustomerPhone(ctx, p.UserID)
	if err != nil {
		return CashfreeOrder{}, apperr.Internal(err)
	}
	phone = CashfreePhone(phone)
	if len(phone) < 10 {
		return CashfreeOrder{}, apperr.BusinessRule("phone_required", "a verified phone number is required for this payment method")
	}
	now := s.deps.Clock.Now()
	rec := CashfreeOrderRecord{
		OrderID: newOrderID(), UserID: p.UserID, ProductID: pkg.ProductID, AmountPaise: pkg.PricePaise, Diamonds: pkg.Diamonds,
		Environment: s.deps.Cashfree.Environment(), State: "created", CreatedAt: now, ExpiresAt: now.Add(s.deps.CashfreeOrderTTL),
	}
	if err := s.deps.Repo.InsertCashfreeOrder(ctx, rec); err != nil {
		return CashfreeOrder{}, apperr.Internal(err)
	}
	remote, err := s.deps.Cashfree.CreateOrder(ctx, CashfreeCreateOrder{
		OrderID: rec.OrderID, AmountPaise: rec.AmountPaise, Currency: "INR",
		CustomerID: strings.ReplaceAll(p.UserID, "-", ""), CustomerPhone: phone,
		ReturnURL: s.deps.CashfreeReturnURL, ExpiresAt: rec.ExpiresAt, Note: pkg.Label + " Diamonds",
	})
	if err != nil {
		slog.ErrorContext(ctx, "cashfree create order failed", "order_id", rec.OrderID, "err", err)
		_ = s.deps.Repo.SetCashfreeOrderState(ctx, rec.OrderID, "failed", "create_failed")
		return CashfreeOrder{}, apperr.Unavailable("cashfree_unavailable", "the payment provider could not create the order; retry")
	}
	if remote.PaymentSessionID == "" || remote.AmountPaise != rec.AmountPaise {
		_ = s.deps.Repo.SetCashfreeOrderState(ctx, rec.OrderID, "failed", "create_mismatch")
		return CashfreeOrder{}, apperr.Unavailable("cashfree_unavailable", "the payment provider returned an unexpected order")
	}
	if err := s.deps.Repo.SetCashfreeSession(ctx, rec.OrderID, remote.PaymentSessionID, remote.CFOrderID); err != nil {
		return CashfreeOrder{}, apperr.Internal(err)
	}
	rec.PaymentSessionID = remote.PaymentSessionID
	return toWire(rec, 0), nil
}

// GetCashfreeOrder: GET /v1/purchases/cashfree/orders/{orderId} (owner only).
// A non-final order is re-checked with Cashfree server-to-server, so a lost
// webhook still credits.
func (s *Service) GetCashfreeOrder(ctx context.Context, p auth.Principal, orderID string) (CashfreeOrder, error) {
	if err := s.cashfreeReady(); err != nil {
		return CashfreeOrder{}, err
	}
	rec, ok, err := s.deps.Repo.CashfreeOrder(ctx, orderID)
	if err != nil {
		return CashfreeOrder{}, apperr.Internal(err)
	}
	if !ok || rec.UserID != p.UserID {
		return CashfreeOrder{}, apperr.NotFound("order")
	}
	if rec.State == "created" || rec.State == "pending" {
		if err := s.syncCashfree(ctx, rec); err != nil {
			slog.WarnContext(ctx, "cashfree re-check failed", "order_id", orderID, "err", err)
		}
		if rec, _, err = s.deps.Repo.CashfreeOrder(ctx, orderID); err != nil {
			return CashfreeOrder{}, apperr.Internal(err)
		}
	}
	return wireOrder(rec), nil
}

// syncCashfree fetches the order from Cashfree and applies its status:
// PAID with matching amount and currency → credit; EXPIRED → expired;
// TERMINATED → failed. The webhook amount is never trusted.
func (s *Service) syncCashfree(ctx context.Context, rec CashfreeOrderRecord) error {
	remote, err := s.deps.Cashfree.GetOrder(ctx, rec.OrderID)
	if err != nil {
		return err
	}
	switch remote.Status {
	case "PAID":
		if remote.OrderID != rec.OrderID || remote.AmountPaise != rec.AmountPaise || remote.Currency != "INR" {
			if err := s.deps.Repo.SetCashfreeOrderState(ctx, rec.OrderID, "failed", "amount_mismatch"); err != nil {
				return err
			}
			s.audit(ctx, "provider:cashfree", "cashfree.amount_mismatch", rec.OrderID, map[string]any{
				"expected_paise": rec.AmountPaise, "reported_paise": remote.AmountPaise, "currency": remote.Currency})
			return nil
		}
		return s.creditCashfree(ctx, rec)
	case "EXPIRED":
		return s.deps.Repo.SetCashfreeOrderState(ctx, rec.OrderID, "expired", "")
	case "TERMINATED":
		return s.deps.Repo.SetCashfreeOrderState(ctx, rec.OrderID, "failed", "terminated")
	}
	return nil
}

func (s *Service) creditCashfree(ctx context.Context, rec CashfreeOrderRecord) error {
	now := s.deps.Clock.Now()
	_, replayed, err := s.deps.Repo.CreditPurchase(ctx, Credit{
		UserID: rec.UserID, ProductID: rec.ProductID, TokenHash: CashfreeTokenHash(rec.OrderID), OrderID: rec.OrderID,
		Diamonds: rec.Diamonds, Rail: railCashfree, XP: s.deps.Rules.XP(rec.Diamonds, 0), CashfreeOrderID: rec.OrderID,
		Entry: func(purchaseID string) ledger.Entry {
			// Ledger key purchase_credit:cashfree:<order_id> (MVP contract §2.4).
			return ledger.PurchaseCredit(rec.UserID, purchaseID, "cashfree:"+rec.OrderID, rec.Diamonds, s.deps.Rules.Version, now)
		},
	})
	if errors.Is(err, ErrNotCreditable) {
		s.audit(ctx, "provider:cashfree", "cashfree.paid_after_final", rec.OrderID, map[string]any{"state": rec.State})
		return nil
	}
	if err != nil {
		return err
	}
	if !replayed {
		s.walletUpdated(ctx, rec.UserID)
	}
	return nil
}

type cashfreeWebhook struct {
	Type string `json:"type"`
	Data struct {
		Order struct {
			OrderID string `json:"order_id"`
		} `json:"order"`
	} `json:"data"`
}

// CashfreeWebhook: POST /v1/webhooks/cashfree. Signature over timestamp +
// raw body (constant time, ≤ 5 minutes old), dedupe on sha256(body); on
// PAYMENT_SUCCESS_WEBHOOK the order is re-fetched before crediting.
func (s *Service) CashfreeWebhook(ctx context.Context, raw []byte, headers map[string]string) error {
	if err := s.cashfreeReady(); err != nil {
		return err
	}
	if err := s.deps.Cashfree.VerifyWebhook(raw, headers["X-Webhook-Signature"], headers["X-Webhook-Timestamp"], s.deps.Clock.Now()); err != nil {
		return apperr.Unauthenticated("invalid webhook signature")
	}
	hash := SHA256Hex(string(raw))
	seen, err := s.deps.Repo.WebhookSeen(ctx, hash)
	if err != nil {
		return apperr.Internal(err)
	}
	if seen {
		return nil
	}
	var wh cashfreeWebhook
	if err := json.Unmarshal(raw, &wh); err != nil {
		return apperr.Validation(map[string]string{"body": "invalid_json"})
	}
	orderID := wh.Data.Order.OrderID
	rec, ok, err := s.deps.Repo.CashfreeOrder(ctx, orderID)
	if err != nil {
		return apperr.Internal(err)
	}
	if ok {
		switch wh.Type {
		case "PAYMENT_SUCCESS_WEBHOOK":
			if err := s.syncCashfree(ctx, rec); err != nil {
				slog.ErrorContext(ctx, "cashfree webhook re-check failed", "order_id", orderID, "err", err)
				return apperr.Unavailable("cashfree_unavailable", "order re-check failed; retry")
			}
		case "PAYMENT_FAILED_WEBHOOK", "PAYMENT_USER_DROPPED_WEBHOOK":
			// The customer may retry within the session; the order stays open.
			if err := s.deps.Repo.SetCashfreeOrderState(ctx, orderID, "pending", strings.ToLower(wh.Type)); err != nil {
				return apperr.Internal(err)
			}
		}
	}
	if err := s.deps.Repo.RecordWebhook(ctx, hash, orderID, wh.Type, raw); err != nil {
		return apperr.Internal(err)
	}
	return nil
}

// PollCashfreeOrders is the `poll-cashfree-orders` job: re-check open orders
// younger than 24 h; older ones get a final check and are then expired.
func (s *Service) PollCashfreeOrders(ctx context.Context) (checked, expired int, err error) {
	if err := s.cashfreeReady(); err != nil {
		return 0, 0, err
	}
	orders, err := s.deps.Repo.OpenCashfreeOrders(ctx, 500)
	if err != nil {
		return 0, 0, err
	}
	cutoff := s.deps.Clock.Now().Add(-24 * time.Hour)
	for _, o := range orders {
		checked++
		if err := s.syncCashfree(ctx, o); err != nil {
			slog.WarnContext(ctx, "cashfree poll re-check failed", "order_id", o.OrderID, "err", err)
		}
		if o.CreatedAt.Before(cutoff) {
			if err := s.deps.Repo.SetCashfreeOrderState(ctx, o.OrderID, "expired", "poll_timeout"); err != nil {
				return checked, expired, err
			}
			expired++
		}
	}
	return checked, expired, nil
}
