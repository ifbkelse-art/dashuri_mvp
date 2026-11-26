package gifts

import (
	"strings"
	"testing"
	"time"

	"dashuri/backend/internal/modules/economy"
	"dashuri/backend/internal/platform/apperr"
)

var t0 = time.Date(2026, 11, 26, 12, 0, 0, 0, time.UTC)

const (
	customer = "11111111-1111-4111-8111-111111111111"
	host     = "22222222-2222-4222-8222-222222222222"
	stranger = "33333333-3333-4333-8333-333333333333"
	callID   = "44444444-4444-4444-8444-444444444444"
	key      = "55555555-5555-4555-8555-555555555555"
)

func baseReq() SendRequest {
	return SendRequest{SenderID: customer, CallID: callID, RecipientID: host, GiftID: "rose",
		ClientRequestID: key, RequestHash: RequestHash(callID, "rose", host), Now: t0}
}

func baseState() SendState {
	return SendState{
		CallFound: true,
		Call:      CallInfo{ID: callID, CallerID: customer, ReceiverID: host, Phase: "active"},
		GiftFound: true,
		Gift: Item{ID: "rose", Name: "Rose", Emoji: "🌹", Tier: "common", DiamondPrice: 1500, Active: true,
			AnimationAsset: "celebration/rose", AnimationDurationMs: 5000},
		Sender:      Party{Exists: true, Status: "active", AgeEligible: true, DisplayName: "Asha", AccountAgeDur: 30 * 24 * time.Hour},
		Recipient:   Party{Exists: true, Status: "active", AgeEligible: true, DisplayName: "Meera", HostState: "approved"},
		Promotional: 0, Purchased: 10000,
	}
}

func run(t *testing.T, mutate func(*SendRequest, *SendState)) (SendPlan, error) {
	t.Helper()
	req, st := baseReq(), baseState()
	if mutate != nil {
		mutate(&req, &st)
	}
	return decide(economy.Founder(), DefaultLimits(), req, st, func() string { return "gift-tx-1" })
}

func code(err error) string {
	if e := apperr.As(err); e != nil {
		if e.Code == "validation_failed" || e.Kind == apperr.KindValidation {
			for k, v := range e.Fields {
				return k + ":" + v
			}
		}
		return e.Code
	}
	return ""
}

func TestDecideSuccessUsesAuthoritativePriceAndRuleSet(t *testing.T) {
	plan, err := run(t, nil)
	if err != nil {
		t.Fatal(err)
	}
	r := economy.Founder()
	wantBeans, _ := r.BeansForDiamonds(1500)
	tx := plan.Transaction
	if plan.Replay || tx.DiamondPrice != 1500 || tx.FromPurchased != 1500 || tx.FromPromotional != 0 {
		t.Fatalf("bad split %+v", tx)
	}
	if tx.HostBeans != wantBeans || tx.HostBeans != 899 { // 1500 × 10000 / 16670, rounded down
		t.Fatalf("beans %d, want %d", tx.HostBeans, wantBeans)
	}
	if tx.RuleSetVersion != r.Version || tx.ID != "gift-tx-1" || tx.RecipientID != host || tx.CallID != callID {
		t.Fatalf("bad tx %+v", tx)
	}
	if plan.ChatBody != "🌹 Asha sent Rose to Meera." {
		t.Fatalf("chat body %q", plan.ChatBody)
	}
	if plan.XPDelta != wantBeans*r.XPBeanWeight {
		t.Fatalf("xp %d", plan.XPDelta)
	}
}

func TestDecidePromotionalFirstAndReservationRespected(t *testing.T) {
	plan, err := run(t, func(_ *SendRequest, st *SendState) { st.Promotional, st.Purchased = 1000, 5000 })
	if err != nil {
		t.Fatal(err)
	}
	if plan.Transaction.FromPromotional != 1000 || plan.Transaction.FromPurchased != 500 {
		t.Fatalf("split %+v", plan.Transaction)
	}
	if !contains(plan.Transaction.RiskFlags, FlagPromotionalUse) {
		t.Fatalf("flags %v", plan.Transaction.RiskFlags)
	}
	// Diamonds reserved for the live call cannot be gifted.
	_, err = run(t, func(_ *SendRequest, st *SendState) { st.Purchased, st.Reserved = 2000, 1000 })
	if code(err) != "insufficient_diamonds" {
		t.Fatalf("want insufficient_diamonds, got %v", err)
	}
}

func TestDecideRefusals(t *testing.T) {
	cases := []struct {
		name   string
		mutate func(*SendRequest, *SendState)
		want   string
	}{
		{"call missing", func(_ *SendRequest, st *SendState) { st.CallFound = false }, "not_found"},
		{"host tries to send", func(r *SendRequest, _ *SendState) { r.SenderID = host }, "hosts_cannot_send_gifts"},
		{"not a participant", func(r *SendRequest, _ *SendState) { r.SenderID = stranger }, "not_found"},
		{"wrong recipient", func(r *SendRequest, _ *SendState) { r.RecipientID = stranger }, "recipient_user_id:not_call_host"},
		{"call ringing", func(_ *SendRequest, st *SendState) { st.Call.Phase = "ringing" }, "call_not_giftable"},
		{"call paused", func(_ *SendRequest, st *SendState) { st.Call.Phase = "paused" }, "call_not_giftable"},
		{"call ended", func(_ *SendRequest, st *SendState) { st.Call.Phase = "ended" }, "call_not_giftable"},
		{"sender suspended", func(_ *SendRequest, st *SendState) { st.Sender.Status = "suspended" }, "account_restricted"},
		{"sender restricted", func(_ *SendRequest, st *SendState) { st.Sender.Status = "restricted" }, "account_restricted"},
		{"sender under age", func(_ *SendRequest, st *SendState) { st.Sender.AgeEligible = false }, "not_age_eligible"},
		{"sender is a host account", func(_ *SendRequest, st *SendState) { st.Sender.HostState = "approved" }, "hosts_cannot_send_gifts"},
		{"host suspended", func(_ *SendRequest, st *SendState) { st.Recipient.HostState = "suspended" }, "host_cannot_receive_gifts"},
		{"host account banned", func(_ *SendRequest, st *SendState) { st.Recipient.Status = "banned" }, "host_cannot_receive_gifts"},
		{"blocked", func(_ *SendRequest, st *SendState) { st.Blocked = true }, "blocked"},
		{"gift missing", func(_ *SendRequest, st *SendState) { st.GiftFound = false }, "not_found"},
		{"gift disabled", func(_ *SendRequest, st *SendState) { st.Gift.Active = false }, "gift_unavailable"},
		{"gift retired", func(_ *SendRequest, st *SendState) { r := t0; st.Gift.RetiredAt = &r }, "gift_unavailable"},
		{"gift not yet available", func(_ *SendRequest, st *SendState) { f := t0.Add(time.Hour); st.Gift.AvailableFrom = &f }, "gift_unavailable"},
		{"gift window over", func(_ *SendRequest, st *SendState) { u := t0; st.Gift.AvailableUntil = &u }, "gift_unavailable"},
		{"insufficient", func(_ *SendRequest, st *SendState) { st.Purchased = 1499 }, "insufficient_diamonds"},
		{"rate limited", func(_ *SendRequest, st *SendState) { st.SentInCallLastMinute = 6 }, "gift_rate_limited"},
		{"daily cap", func(_ *SendRequest, st *SendState) { st.SpentLast24h = 999_000 }, "gift_spend_limit"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			_, err := run(t, c.mutate)
			if got := code(err); got != c.want {
				t.Fatalf("want %s, got %s (%v)", c.want, got, err)
			}
		})
	}
}

func TestDecideIdempotentReplayAndKeyReuse(t *testing.T) {
	stored := Transaction{ID: "stored", RequestHash: RequestHash(callID, "rose", host), DiamondPrice: 1500}
	plan, err := run(t, func(_ *SendRequest, st *SendState) {
		// Replay wins even if the call has ended since or the balance is gone.
		st.Existing, st.Call.Phase, st.Purchased = &stored, "ended", 0
	})
	if err != nil || !plan.Replay || plan.Transaction.ID != "stored" {
		t.Fatalf("replay: %+v %v", plan, err)
	}
	_, err = run(t, func(r *SendRequest, st *SendState) {
		st.Existing = &stored
		r.GiftID, r.RequestHash = "teddy", RequestHash(callID, "teddy", host)
	})
	if code(err) != "Idempotency-Key:reused_with_different_request" {
		t.Fatalf("key reuse: %v", err)
	}
}

func TestRiskFlags(t *testing.T) {
	st := baseState()
	st.Sender.AccountAgeDur = time.Hour
	st.PairSpentLast24h = 450_000
	got := RiskFlags(DefaultLimits(), st, 100_000, 0)
	for _, f := range []string{FlagHighValue, FlagNewAccount, FlagPairVolume} {
		if !contains(got, f) {
			t.Fatalf("missing %s in %v", f, got)
		}
	}
	if flags := RiskFlags(DefaultLimits(), baseState(), 1500, 0); len(flags) != 0 {
		t.Fatalf("small gift from an established account must not be flagged: %v", flags)
	}
}

func TestChatLineFallbacks(t *testing.T) {
	if got := ChatLine("💎", "", "Diamond Ring", ""); got != "💎 Someone sent Diamond Ring to the host." {
		t.Fatal(got)
	}
}

func TestRequestHashBindsCallGiftAndRecipient(t *testing.T) {
	a := RequestHash(callID, "rose", host)
	for _, b := range []string{RequestHash(callID, "teddy", host), RequestHash(stranger, "rose", host), RequestHash(callID, "rose", stranger)} {
		if a == b {
			t.Fatal("hash must change with call, gift and recipient")
		}
	}
	if a != RequestHash(strings.ToUpper(callID), "rose", strings.ToUpper(host)) {
		t.Fatal("hash must ignore uuid case")
	}
}

func TestIdempotencyKeyMustBeUUIDv4(t *testing.T) {
	if !isUUIDv4(key) || isUUIDv4("55555555-5555-1555-8555-555555555555") || isUUIDv4("nope") {
		t.Fatal("uuid v4 check")
	}
}

func TestSellableAt(t *testing.T) {
	from, until := t0.Add(-time.Hour), t0.Add(time.Hour)
	it := Item{Active: true, AvailableFrom: &from, AvailableUntil: &until}
	if !it.SellableAt(t0) || it.SellableAt(until) || it.SellableAt(from.Add(-time.Second)) {
		t.Fatal("window")
	}
}

func contains(xs []string, x string) bool {
	for _, v := range xs {
		if v == x {
			return true
		}
	}
	return false
}
