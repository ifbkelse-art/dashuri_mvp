package wallet

import (
	"testing"
	"time"
)

var hold7 = 7 * 24 * time.Hour

func i64(n int64) *int64 { return &n }

func TestToBeanItemWording(t *testing.T) {
	at := time.Date(2026, 11, 28, 9, 0, 0, 0, time.UTC)
	rel := at.Add(48 * time.Hour)
	cases := []struct {
		name         string
		row          BeanRow
		typ, title   string
		sub          string
		beans, moved int64
		status       string
	}{
		{"call", BeanRow{EntryType: "call_settlement", HeldDelta: 319, PeerName: "Bruce", CallSeconds: i64(64), CallRate: i64(500), BalanceAfter: 319},
			"call", "Call with Bruce", "1 min 04 s · 500 Diamonds/min", 319, 0, "on_hold"},
		{"short call", BeanRow{EntryType: "call_settlement", HeldDelta: 5, PeerName: "Bruce", CallSeconds: i64(9)},
			"call", "Call with Bruce", "9 s", 5, 0, "on_hold"},
		{"call no details", BeanRow{EntryType: "call_settlement", HeldDelta: 5},
			"call", "Call with a customer", "", 5, 0, "on_hold"},
		{"released call", BeanRow{EntryType: "call_settlement", HeldDelta: 5, PeerName: "Bruce", ReleasedAt: &rel},
			"call", "Call with Bruce", "", 5, 0, "released"},
		{"gift", BeanRow{EntryType: "gift_send", HeldDelta: 899, PeerName: "Bruce", GiftName: "Rose", GiftEmoji: "🌹"},
			"gift", "🌹 Rose from Bruce", "Gift during a video call", 899, 0, "on_hold"},
		{"free call", BeanRow{EntryType: "free_call_compensation", HeldDelta: 2000},
			"free_call", "Free Call Card call", "Paid by Dashuri for a free minute", 2000, 0, "on_hold"},
		{"release of a gift", BeanRow{EntryType: "bean_release", HeldDelta: -899, AvailableDelta: 899, PeerName: "Bruce", SourceType: "gift_send"},
			"release", "Released from hold", "Gift from Bruce is now withdrawable", 0, 899, ""},
		{"withdrawal", BeanRow{EntryType: "withdrawal_requested", AvailableDelta: -400, PendingDelta: 400},
			"withdrawal", "Withdrawal requested", "Beans moved to your payout", -400, 0, ""},
		{"paid", BeanRow{EntryType: "payout_paid", PendingDelta: -400},
			"payout_paid", "Withdrawal paid", "Sent to your bank account", 0, 400, ""},
		{"failed", BeanRow{EntryType: "payout_failed", AvailableDelta: 50, PendingDelta: -50},
			"payout_failed", "Withdrawal failed", "Beans returned to your balance", 50, 0, ""},
		{"clawback", BeanRow{EntryType: "bean_clawback", HeldDelta: -100},
			"reversal", "Earnings reversed", "Reversed after a refund or safety review", -100, 0, ""},
		{"debit", BeanRow{EntryType: "adjustment", AvailableDelta: -7},
			"adjustment", "Balance correction (debit)", "Approved by two staff members", -7, 0, ""},
		{"unknown", BeanRow{EntryType: "something_new"},
			"other", "Beans activity", "", 0, 0, ""},
	}
	for _, c := range cases {
		c.row.OccurredAt = at
		it := ToBeanItem(c.row, hold7)
		if it.Type != c.typ || it.Title != c.title || it.Beans != c.beans {
			t.Errorf("%s: %+v", c.name, it)
		}
		if got := deref(it.Subtitle); got != c.sub {
			t.Errorf("%s: subtitle %q, want %q", c.name, got, c.sub)
		}
		if got := derefN(it.MovedBeans); got != c.moved {
			t.Errorf("%s: moved %d, want %d", c.name, got, c.moved)
		}
		if got := deref(it.Status); got != c.status {
			t.Errorf("%s: status %q, want %q", c.name, got, c.status)
		}
	}
	// An on-hold earning says when it becomes withdrawable.
	if it := ToBeanItem(BeanRow{EntryType: "call_settlement", OccurredAt: at}, hold7); it.ReleasesAt == nil || !it.ReleasesAt.Equal(at.Add(hold7)) {
		t.Fatalf("releases_at: %+v", it.ReleasesAt)
	}
}

func deref(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

func derefN(n *int64) int64 {
	if n == nil {
		return 0
	}
	return *n
}

func TestBeanFilters(t *testing.T) {
	if ty, err := beanFilterTypes(""); err != nil || ty != nil {
		t.Fatal("empty means all")
	}
	if ty, err := beanFilterTypes("all"); err != nil || ty != nil {
		t.Fatal("all means all")
	}
	if ty, err := beanFilterTypes("calls"); err != nil || len(ty) != 2 {
		t.Fatalf("calls: %v %v", ty, err)
	}
	if _, err := beanFilterTypes("nope"); err == nil {
		t.Fatal("unknown filter must be refused")
	}
}

func TestStartOfDayIST(t *testing.T) {
	// 20:00 UTC on 27 Nov is 01:30 IST on 28 Nov: "today" started 18:30 UTC.
	got := startOfDayIST(time.Date(2026, 11, 27, 20, 0, 0, 0, time.UTC)).UTC()
	if want := time.Date(2026, 11, 27, 18, 30, 0, 0, time.UTC); !got.Equal(want) {
		t.Fatalf("start of day = %v, want %v", got, want)
	}
}

func TestToBeanSummaryAddsUp(t *testing.T) {
	s := ToBeanSummary(Balances{ByKind: map[string]int64{"bean_held": 5798, "bean_available": 159, "bean_payout_pending": 40}},
		BeanTotals{FromCalls: 599, FromGifts: 3898, FromFreeCalls: 2000, Reversed: 100, PaidOut: 400})
	if s.Balance != 5957 || s.LifetimeEarned != 6497 {
		t.Fatalf("%+v", s)
	}
	if s.Balance+s.PendingPayout+s.PaidOut != s.LifetimeEarned-s.Reversed+s.Adjustments {
		t.Fatalf("identity broken: %+v", s)
	}
}
