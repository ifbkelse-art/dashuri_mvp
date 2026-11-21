package wallet

import (
	"testing"
	"time"
)

func TestDescribe(t *testing.T) {
	cases := []struct {
		typ, cur string
		amt      int64
		want     string
	}{
		{"purchase_credit", "DIAMOND", 4000, "Diamonds purchased"},
		{"call_settlement", "DIAMOND", -4333, "Video call"},
		{"call_settlement", "BEAN", 2599, "Call earnings (on hold for 7 days)"},
		{"free_call_compensation", "BEAN", 2000, "Free Call Card earnings (on hold for 7 days)"},
		{"bean_release", "BEAN", 2599, "Beans released from hold"},
		{"withdrawal_requested", "BEAN", -100000, "Withdrawal requested"},
		{"payout_paid", "BEAN", -100000, "Withdrawal paid"},
		{"payout_failed", "BEAN", 100000, "Withdrawal failed, Beans returned"},
		{"purchase_reversal", "DIAMOND", -100, "Purchase refunded"},
		{"promo_expiry", "DIAMOND", -5, "Bonus Diamonds expired"},
		{"adjustment", "DIAMOND", -5, "Balance correction (debit)"},
		{"adjustment", "BEAN", 5, "Balance correction (credit)"},
		{"something_new", "BEAN", 1, "Wallet activity"},
	}
	for _, c := range cases {
		if got := Describe(c.typ, c.cur, c.amt); got != c.want {
			t.Errorf("%s/%s: %q, want %q", c.typ, c.cur, got, c.want)
		}
	}
}

func TestToEntryInternalMovesShowAvailableChange(t *testing.T) {
	at := time.Now()
	w := ToEntry(EntryRow{EntryID: "e", EntryType: "withdrawal_requested", Currency: "BEAN", Net: 0, Available: -100000, OccurredAt: at, Reference: "w1"})
	if w.Amount != -100000 || w.Reference == nil || *w.Reference != "w1" || w.Description != "Withdrawal requested" {
		t.Fatalf("%+v", w)
	}
	p := ToEntry(EntryRow{EntryID: "e2", EntryType: "purchase_credit", Currency: "DIAMOND", Net: 4000})
	if p.Amount != 4000 || p.Reference != nil {
		t.Fatalf("%+v", p)
	}
}

func TestSummarize(t *testing.T) {
	s := Summarize(Balances{ByKind: map[string]int64{"diamond_purchased": 1000, "diamond_promotional": 200,
		"bean_held": 5, "bean_available": 6, "bean_payout_pending": 7}, Reserved: 300})
	if s.AvailableDiamonds != 900 || s.BeansOnHold != 5 || s.BeansAvailable != 6 || s.BeansPendingPayout != 7 || s.ReservedDiamonds != 300 {
		t.Fatalf("%+v", s)
	}
	if Summarize(Balances{ByKind: map[string]int64{}, Reserved: 10}).AvailableDiamonds != 0 {
		t.Fatal("available must not go negative")
	}
}
