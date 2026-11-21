package calls

import (
	"testing"
	"time"

	"dashuri/backend/internal/modules/economy"
)

func ev(user, kind string, s int) MediaEvent { return MediaEvent{UserID: user, Kind: kind, At: at(s)} }

func TestTimelineJoinOnlyProvider(t *testing.T) {
	es := []MediaEvent{ev("a", EventJoined, 0), ev("b", EventJoined, 5), ev("b", EventLeft, 30), ev("b", EventJoined, 50)}
	got := Timeline(es, "a", "b")
	want := []LiveChange{{at(5), true}, {at(30), false}, {at(50), true}}
	if len(got) != len(want) {
		t.Fatalf("%v", got)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("%d: %v want %v", i, got[i], want[i])
		}
	}
	if f, ok := FirstLive(got); !ok || !f.Equal(at(5)) {
		t.Fatal("first live")
	}
}

func TestTimelineRequiresVideoWhenTrackEventsExist(t *testing.T) {
	es := []MediaEvent{
		ev("a", EventJoined, 0), ev("b", EventJoined, 1),
		ev("a", EventVideoPublished, 3), ev("b", EventVideoPublished, 7),
		ev("b", EventVideoUnpublished, 20), ev("b", EventVideoPublished, 25),
		{Kind: EventCallEnded, At: at(40)},
	}
	got := Timeline(es, "a", "b")
	want := []LiveChange{{at(7), true}, {at(20), false}, {at(25), true}, {at(40), false}}
	if len(got) != len(want) {
		t.Fatalf("%v", got)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("%d: %v want %v", i, got[i], want[i])
		}
	}
	if live, since := CurrentState(got); live || !since.Equal(at(40)) {
		t.Fatal("current state")
	}
}

func TestTimelineIgnoresStrangers(t *testing.T) {
	es := []MediaEvent{ev("a", EventJoined, 0), ev("x", EventJoined, 1)}
	if got := Timeline(es, "a", "b"); len(got) != 0 {
		t.Fatalf("%v", got)
	}
}

func TestSplitSpend(t *testing.T) {
	cases := []struct {
		total, promo, purch int64
		order               string
		wp, wu              int64
	}{
		{4333, 1000, 10000, "promotional_first", 1000, 3333},
		{500, 1000, 10000, "promotional_first", 500, 0},
		{4333, 1000, 10000, "purchased_first", 0, 4333},
		{4333, 1000, 4000, "purchased_first", 333, 4000},
		{0, 1000, 1000, "promotional_first", 0, 0},
	}
	for _, c := range cases {
		p, u := SplitSpend(c.total, c.promo, c.purch, c.order)
		if p != c.wp || u != c.wu || p+u != c.total {
			t.Errorf("%+v: got %d/%d", c, p, u)
		}
	}
}

func TestComputeChargeExample(t *testing.T) {
	r := economy.Founder()
	ch, err := ComputeCharge(r, 4000, 65, 8000, 0, 10000)
	if err != nil || ch.Diamonds != 4333 || ch.HostBeans != 2599 || ch.FromPurchased != 4333 {
		t.Fatalf("%+v %v", ch, err)
	}
	// Capped by the reservation, then by the balance.
	if ch, _ := ComputeCharge(r, 4000, 600, 8000, 0, 100000); ch.Diamonds != 8000 {
		t.Fatalf("reservation cap: %+v", ch)
	}
	if ch, _ := ComputeCharge(r, 4000, 600, 80000, 100, 900); ch.Diamonds != 1000 || ch.FromPromotional != 100 {
		t.Fatalf("balance cap: %+v", ch)
	}
	_ = time.Second
}

func TestCursorRoundTrip(t *testing.T) {
	ts := at(3).Add(123 * time.Microsecond)
	at2, id, err := decodeCursor(encodeCursor(ts, "3f1c7b1e-0000-4000-8000-000000000001"))
	if err != nil || !at2.Equal(ts) || id != "3f1c7b1e-0000-4000-8000-000000000001" {
		t.Fatal(err)
	}
	if _, _, err := decodeCursor("!!"); err == nil {
		t.Fatal("bad cursor accepted")
	}
}

// Security review finding 1: the customer switching their camera off must
// not pause billing while the host is live.
func TestCustomerCameraOffKeepsBilling(t *testing.T) {
	t0 := time.Date(2026, 11, 21, 12, 0, 0, 0, time.UTC)
	es := []MediaEvent{
		{Kind: EventJoined, UserID: "a", At: t0},
		{Kind: EventJoined, UserID: "b", At: t0},
		{Kind: EventVideoPublished, UserID: "a", At: t0},
		{Kind: EventVideoPublished, UserID: "b", At: t0},
		{Kind: EventVideoUnpublished, UserID: "a", At: t0.Add(10 * time.Second)},
	}
	changes := Timeline(es, "a", "b")
	if got := BillableSeconds(changes, t0.Add(120*time.Second), 10*time.Second); got != 120 {
		t.Fatalf("billable = %d, want 120 (customer camera off must not pause billing)", got)
	}
	// The host switching video off does pause billing.
	es = append(es[:4], MediaEvent{Kind: EventVideoUnpublished, UserID: "b", At: t0.Add(30 * time.Second)})
	if got := BillableSeconds(Timeline(es, "a", "b"), t0.Add(120*time.Second), 10*time.Second); got != 30 {
		t.Fatalf("billable = %d, want 30 when the host stops video", got)
	}
}
